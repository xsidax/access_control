require 'access_control/orm'
require 'access_control/restricter'

module AccessControl
  module Restriction

    class << self
      def included(base)
        base.extend(ClassMethods)
      end

      def listing_condition_for(target)
        restricter  = Restricter.new(ORM.adapt_class(target))
        permissions = target.permissions_required_to_list
        subquery    = restricter.sql_query_for(permissions)
        "#{target.quoted_table_name}.#{target.primary_key} IN (#{subquery})"
      end
    end

    def valid?
      AccessControl.manager.without_query_restriction { super }
    end

    module ClassMethods

      def find(*args)
        return super unless AccessControl.manager.restrict_queries?
        case args.first
        when :all, :last, :first
          with_listing_filtering { super }
        else
          permissions = permissions_required_to_show
          manager = AccessControl.manager
          results = super(*args)
          test_results = Array(results)
          test_results.each { |result| manager.can!(permissions, result) }
          results
        end
      end

      def calculate(*args)
        return super unless AccessControl.manager.restrict_queries?
        with_listing_filtering { super }
      end

      def listable
        return scoped({}) unless AccessControl.manager.restrict_queries?
        scoped(:conditions => Restriction.listing_condition_for(self))
      end

      def unrestricted_find(*args)
        AccessControl.manager.without_query_restriction { find(*args) }
      end

    private

      def with_listing_filtering
        condition = Restriction.listing_condition_for(self)
        with_scope(:find => { :conditions => condition }) { yield }
      end
    end
  end
end
