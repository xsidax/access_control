module AccessControl

  module Util

    def make_set_from_args *args
      if args.size == 1 && args.first.is_a?(Enumerable)
        return Set.new(args.first)
      end
      Set.new(args)
    end

    def log_missing_permissions context, requirements
      AccessControl::Logger.log_missing_permissions(
        context, make_set_from_args(requirements)
      )
    end

  end

  module Logger

    def self.format_trace trace
      trace = clean_trace(trace)
      if ActiveRecord::Base.colorize_logging
        trace.map!{|t| "\e[31;2m#{t}\e[0m"}
      end
      trace.map{|t| "    #{t}"}.join("\n")
    end

    def self.clean_trace trace
      Rails.respond_to?(:backtrace_cleaner) ?
        Rails.backtrace_cleaner.clean(trace) :
        trace
    end

    def self.format_permissions permissions
      permissions.to_a.map(&:inspect).to_sentence(:locale => 'en')
    end

    def self.format_unauthorized_message missing_permissions
      principals = AccessControl.get_security_manager.principal_ids
      msg = "Access denied for principal(s) #{
        principals.to_sentence(:locale => 'en')
      }: missing #{missing_permissions}"
      if ActiveRecord::Base.colorize_logging
        return "  \e[31;1m#{msg}\e[0m\n"
      end
      "  #{msg}\n"
    end

    def self.log_missing_permissions context, requirements
      missing_permissions = format_permissions(
        requirements -
        AccessControl.get_security_manager.permissions_in_context(context)
      )
      Rails.logger.info(
        format_unauthorized_message(missing_permissions) +
        format_trace(caller[3..-1])
      )
    end

  end
end
