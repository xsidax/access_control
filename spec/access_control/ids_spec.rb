require 'spec_helper'

module AccessControl
  describe Ids do
    let(:connection) { mock('connection') }
    let(:scoped)     { mock('scoped') }
    let(:model)      { mock('model', :connection => connection) }

    before(:all) do
      Ids.use_subqueries = true
    end

    after(:all) do
      Ids.use_subqueries = nil
    end

    before do
      model.stub(:quoted_table_name).and_return('the_table_name')
      model.stub(:scoped).
        with(:select => "DISTINCT #{model.quoted_table_name}.column").
        and_return(scoped)
      scoped.stub(:sql).and_return('the resulting sql')
      model.extend(Ids)
    end

    describe ".select_values_of_column" do
      before do
        connection.stub(:select_values).
          with('the resulting sql').
          and_return(['some value'])
        scoped.stub(:sql).and_return('the resulting sql')
      end

      def call_method
        model.select_values_of_column(:column)
      end

      it "returns the array returned by the driver" do
        call_method.should == ['some value']
      end
    end

    describe ".ids" do
      def call_method
        model.ids
      end

      it "forwards the call to select_values_of_column using :id" do
        model.stub(:select_values_of_column).
          with(:id).and_return('whatever is returned')
        call_method.should == 'whatever is returned'
      end
    end

    describe ".with_ids" do
      it "issues an anonymous scope querying by ids" do
        model.stub(:scoped).
          with(:conditions => { :id => 'the ids' }).
          and_return('the records with the ids')
        model.with_ids('the ids').should == 'the records with the ids'
      end
    end

    describe ".scoped_column" do
      it "returns an anonymous scope around the column passed as parameter" do
        model.scoped_column('column').should == scoped
      end
    end

    describe ".column_sql" do
      before do
        scoped.stub(:sql => "SQL string")
      end

      it "returns the SQL string generated by the return of scoped_column" do
        model.column_sql('column').should == "SQL string"
      end
    end

  end
end
