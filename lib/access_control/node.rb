require 'access_control/exceptions'
require 'access_control/ids'
require 'access_control/inheritance'
require 'access_control/configuration'
require 'access_control/persistable'

module AccessControl

  def AccessControl.Node(object)
    if object.kind_of?(AccessControl::Node)
      object
    elsif object.respond_to?(:ac_node)
      object.ac_node
    else
      raise(UnrecognizedSecurable)
    end
  end

  class Node
    require 'access_control/node/class_methods'
    include AccessControl::Persistable
    extend Node::ClassMethods

    delegate_subset :with_type

    def initialize(properties={})
      properties.delete(:securable_type) if properties[:securable_class]
      super(properties)
    end

    def block= value
      AccessControl.manager.can!('change_inheritance_blocking', self)
      persistent.block = value
    end

    def global?
      id == AccessControl.global_node_id
    end

    def destroy
      AccessControl.manager.without_assignment_restriction do
        Role.unassign_all_at(self)
      end
      super
    end

    def securable
      @securable ||= securable_class.unrestricted_find(securable_id)
    end

    def securable_class=(klass)
      self.securable_type = klass.name
      @securable_class    = klass
    end

    def securable_class
      @securable_class ||= securable_type.constantize
    end

    attr_writer :inheritance_manager
    def inheritance_manager
      @inheritance_manager ||= InheritanceManager.new(self)
    end

    def ancestors
      strict_ancestors.add(self)
    end

    def strict_ancestors
      guard_against_block(:by_returning => :global_node) do
        inheritance_manager.ancestors
      end
    end

    def unblocked_ancestors
      strict_unblocked_ancestors.add(self)
    end

    def strict_unblocked_ancestors
      guard_against_block(:by_returning => :global_node) do
        filter = proc { |node| not node.block }
        inheritance_manager.filtered_ancestors(filter)
      end
    end

    def parents
      guard_against_block(:by_returning => Set.new) do
        inheritance_manager.parents
      end
    end

    def unblocked_parents
      guard_against_block(:by_returning => Set.new) do
        Set.new parents.reject(&:block)
      end
    end

    def inspect
      id = "id: #{self.id.inspect}"
      securable_desc = ""
      if securable_id
        securable_desc = "securable: #{securable_type}(#{securable_id})"
      else
        securable_desc = "securable_type: #{securable_type.inspect}"
      end

      blocked = block ? "blocked": nil

      body = [id, securable_desc, blocked].compact.join(", ")

      "#<AccessControl::Node #{body}>"
    end

  private

    def guard_against_block(arguments = {})
      default_value = arguments.fetch(:by_returning)

      if block
        if default_value == :global_node
          Set[Node.global]
        else
          default_value
        end
      else
        yield
      end
    end
  end
end
