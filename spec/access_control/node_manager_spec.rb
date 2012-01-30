require 'spec_helper'

module AccessControl
  describe NodeManager do

    def add_nodes(hash)
      hash.each do |id, instance|
        current_nodes[id] = instance
      end
    end
    let(:current_nodes)   { {} }

    let(:securable_class) { FakeSecurableClass.new }
    let(:securable)       { securable_class.new }

    let(:node) do
      stub('main node', :securable       => securable,
                        :securable_class => securable_class)
    end

    before do
      Node.stub(:fetch) do |id|
        current_nodes[id] or raise "not found node #{id}"
      end
      Node.stub(:fetch_all) do |ids|
        ids.map do |id|
          Node.fetch(id)
        end
      end
      AccessControl.stub(:Node).with(node).and_return(node)
    end

    subject { NodeManager.new(node) }

    describe "initialization" do
      it "accepts a node" do
        NodeManager.new(node).node.should == node
      end

      it "accepts a securable" do
        securable = stub
        AccessControl.stub(:Node).with(securable).and_return(node)
        NodeManager.new(securable).node.should == node
      end
    end

    describe "#can_update!" do
      let(:update_permissions) { stub('permissions enumerable') }
      let(:manager)            { mock('manager') }

      subject do
        NodeManager.new(node).tap do |node_manager|
          node_manager.manager = manager
        end
      end

      before do
        securable_class.stub(:permissions_required_to_update).
          and_return(update_permissions)
      end

      it "checks if the principals are granted with update permissions" do
        manager.should_receive(:can!).with(update_permissions, node)
        subject.can_update!
      end
    end

    describe "#refresh_parents" do
      let(:create_permissions)  { stub('permissions enumerable (create)') }
      let(:destroy_permissions) { stub('permissions enumerable (destroy)') }

      let(:inheritance_manager) { mock("Inheritance Manager") }
      let(:manager)             { mock('Manager') }

      let(:parent_id) { 'parent id' }
      let(:parent)    { stub("Parent node") }

      let(:real_parent_ids) { [parent_id] }
      let(:cached_parents)  { [parent] }

      before do
        add_nodes(parent_id => parent)

        inheritance_manager.stub(:parents => cached_parents)

        Inheritance.stub(:parent_node_ids_of).with(securable).
          and_return(real_parent_ids)

        securable_class.stub(
          :permissions_required_to_create  => create_permissions,
          :permissions_required_to_destroy => destroy_permissions
        )
      end

      subject do
        NodeManager.new(node).tap do |node_manager|
          node_manager.inheritance_manager = inheritance_manager
          node_manager.manager             = manager
        end
      end

      context "when parents were added" do
        let(:new_parent_id) { 'new parent id' }
        let(:new_parent)    { stub("New parent") }

        before do
          add_nodes(new_parent_id => new_parent)

          inheritance_manager.stub(:add_parent)
          RolePropagation.stub(:propagate!)
          manager.stub(:can!)

          real_parent_ids << new_parent_id
        end

        it "checks permission for adding the new parent" do
          manager.should_receive(:can!).with(create_permissions, new_parent)
          subject.refresh_parents
        end

        it "adds the new parents using the inheritance manager" do
          inheritance_manager.should_receive(:add_parent).with(new_parent)
          subject.refresh_parents
        end

        it "propagates roles from the added parents" do
          RolePropagation.should_receive(:propagate!).with(node, [new_parent])
          subject.refresh_parents
        end
      end

      context "when parents were removed" do
        before do
          inheritance_manager.stub(:del_parent)
          RolePropagation.stub(:depropagate!)
          manager.stub(:can!)

          real_parent_ids.delete(parent_id)
        end

        it "checks permissions for removing the parents" do
          manager.should_receive(:can!).with(destroy_permissions, parent)
          subject.refresh_parents
        end

        it "deletes the old parents using the inheritance manager" do
          inheritance_manager.should_receive(:del_parent).with(parent)
          subject.refresh_parents
        end

        it "depropagates roles from the removed parents" do
          RolePropagation.should_receive(:depropagate!)
          subject.refresh_parents
        end
      end
    end

    describe "#disconnect" do
      let(:parent1) { stub }
      let(:parent2) { stub }
      let(:manager) { stub }

      let(:inheritance_manager) { mock("Inheritance Manager") }

      let(:destroy_permissions) { stub('permissions enumerable (destroy)') }

      subject do
        NodeManager.new(node).tap do |node_manager|
          node_manager.inheritance_manager = inheritance_manager
          node_manager.manager             = manager
        end
      end

      before do
        securable_class.stub(:permissions_required_to_destroy).
          and_return(destroy_permissions)

        RolePropagation.stub(:depropagate!)
        inheritance_manager.stub(:del_all_parents)
        inheritance_manager.stub(:del_all_children)
        inheritance_manager.stub(:parents => [parent1, parent2])

        manager.stub(:can!)
      end

      it "checks permissions for every parent" do
        manager.should_receive(:can!).with(destroy_permissions, parent1)
        manager.should_receive(:can!).with(destroy_permissions, parent2)

        subject.disconnect
      end

      it "depropagates roles from all of the parents" do
        RolePropagation.should_receive(:depropagate!) do |first_arg, second_arg|
          first_arg.should == node
          second_arg.should include_only(parent1, parent2)
        end

        subject.disconnect
      end

      it "disconnects from all of the parents" do
        inheritance_manager.should_receive(:del_all_parents)
        subject.disconnect
      end

      it "disconnects from parents after checking permissions" do
        checked_parents = []

        manager.stub(:can!) do |permissions, parent_node|
          checked_parents << parent_node
        end

        inheritance_manager.stub(:del_all_parents) do
          checked_parents.should include_only(*inheritance_manager.parents)
        end

        subject.disconnect
      end

      it "disconnects from parents after depropagation" do
        depropagated = false

        RolePropagation.stub(:depropagate!) do
          depropagated = true
        end

        inheritance_manager.stub(:del_all_parents) do
          depropagated.should be_true
        end

        subject.disconnect
      end

      it "disconnects from all of the children" do
        inheritance_manager.should_receive(:del_all_children)
        subject.disconnect
      end

      it "disconnects after checking permissions" do
        checked_parents = []

        manager.stub(:can!) do |permissions, parent_node|
          checked_parents << parent_node
        end

        inheritance_manager.stub(:del_all_children) do
          checked_parents.should include_only(*inheritance_manager.parents)
        end

        subject.disconnect
      end
    end

    describe "#block" do
      let(:parent)              { stub }
      let(:inheritance_manager) { stub }

      subject do
        NodeManager.new(node).tap do |node_manager|
          node_manager.inheritance_manager = inheritance_manager
        end
      end

      before do
        RolePropagation.stub(:depropagate!)
        inheritance_manager.stub(:parents => [parent])
        inheritance_manager.stub(:del_all_parents)
      end

      it "depropagates roles from the blocked parents" do
        RolePropagation.should_receive(:depropagate!).with(node, [parent])
        subject.block
      end

      it "disconnects from all of the parents" do
        inheritance_manager.should_receive(:del_all_parents)
        subject.block
      end

      it "disconnects after depropagation" do
        depropagated = false

        RolePropagation.stub(:depropagate!) do
          depropagated = true
        end

        inheritance_manager.stub(:del_all_parents) do
          depropagated.should be_true
        end

        subject.block
      end
    end

    describe "#unblock" do

      let(:parent_id) { 'parent id' }
      let(:parent)    { stub("Parent node", :id => parent_id) }
      let(:inheritance_manager) { stub }

      before do
        add_nodes(parent_id => parent)

        Inheritance.stub(:parent_node_ids_of).with(securable).
          and_return([parent_id])

        RolePropagation.stub(:propagate!)

        inheritance_manager.stub(:add_parent)
        inheritance_manager.stub(:del_parent)
      end

      subject do
        NodeManager.new(node).tap do |node_manager|
          node_manager.inheritance_manager = inheritance_manager
        end
      end

      it "adds all the securable's parents to inheritance manager" do
        inheritance_manager.should_receive(:add_parent).with(parent)
        subject.unblock
      end

      it "propagates roles from the re-added parents" do
        RolePropagation.should_receive(:propagate!) do |first_arg, second_arg|
          first_arg.should == node
          second_arg.should include_only(parent)
        end

        subject.unblock
      end
    end

    describe ".refresh_parents_of" do
      it "does the same as NodeManager.new(node).refresh_parents" do
        instance = stub
        node = stub
        instance.should_receive(:refresh_parents)
        NodeManager.stub(:new).with(node).and_return(instance)

        NodeManager.refresh_parents_of(node)
      end
    end

    describe ".disconnect" do
      it "does the same as NodeManager.new(node).disconnect" do
        instance = stub
        node = stub
        instance.should_receive(:disconnect)
        NodeManager.stub(:new).with(node).and_return(instance)

        NodeManager.disconnect(node)
      end
    end

    describe ".can_update!" do
      it "does the same as NodeManager.new(node).can_update!" do
        instance = stub
        node = stub
        instance.should_receive(:can_update!)
        NodeManager.stub(:new).with(node).and_return(instance)

        NodeManager.can_update!(node)
      end
    end

    describe ".block" do
      it "does the same as NodeManager.new(node).block" do
        instance = stub
        node = stub
        instance.should_receive(:block)
        NodeManager.stub(:new).with(node).and_return(instance)

        NodeManager.block(node)
      end
    end

    describe ".unblock" do
      it "does the same as NodeManager.new(node).unblock" do
        instance = stub
        node = stub
        instance.should_receive(:unblock)
        NodeManager.stub(:new).with(node).and_return(instance)

        NodeManager.unblock(node)
      end
    end
  end
end
