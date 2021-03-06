require File.join(File.dirname(File.expand_path(__FILE__)), 'spec_helper.rb')

describe "Simple Dataset operations" do
  before do
    @db = INTEGRATION_DB
    @db.create_table!(:items) do
      primary_key :id
      Integer :number
    end
    @ds = @db[:items]
    @ds.insert(:number=>10)
  end
  after do
    @db.drop_table(:items)
  end

  specify "should support sequential primary keys" do
    @ds << {:number=>20}
    @ds << {:number=>30}
    @ds.order(:number).all.should == [
      {:id => 1, :number=>10},
      {:id => 2, :number=>20},
      {:id => 3, :number=>30} ]   
  end 

  cspecify "should insert with a primary key specified", :db2, :mssql do
    @ds.insert(:id=>100, :number=>20)
    @ds.count.should == 2
    @ds.order(:id).all.should == [{:id=>1, :number=>10}, {:id=>100, :number=>20}]
  end

  specify "should have insert return primary key value" do
    @ds.insert(:number=>20).should == 2
    @ds.filter(:id=>2).first[:number].should == 20
  end

  specify "should join correctly" do
    @ds.join(:items___b, :id=>:id).select_all(:items).all.should == [{:id=>1, :number=>10}]
  end

  specify "should correctly deal with qualified columns and subselects" do
    @ds.from_self(:alias=>:a).select(:a__id, :number.qualify(:a)).all.should == [{:id=>1, :number=>10}]
    @ds.join(@ds.as(:a), :id=>:id).select(:a__id, :number.qualify(:a)).all.should == [{:id=>1, :number=>10}]
  end

  specify "should graph correctly" do
    @ds.graph(:items, {:id=>:id}, :table_alias=>:b).all.should == [{:items=>{:id=>1, :number=>10}, :b=>{:id=>1, :number=>10}}]
  end

  specify "should graph correctly with a subselect" do
    @ds.from_self(:alias=>:items).graph(@ds.from_self, {:id=>:id}, :table_alias=>:b).all.should == [{:items=>{:id=>1, :number=>10}, :b=>{:id=>1, :number=>10}}]
  end

  cspecify "should have insert work correctly when inserting a row with all NULL values", :hsqldb do
    @db.create_table!(:items) do
      String :name
      Integer :number
    end
    proc{@ds.insert}.should_not raise_error
    @ds.all.should == [{:name=>nil, :number=>nil}]
  end

  specify "should delete correctly" do
    @ds.filter(1=>1).delete.should == 1
    @ds.count.should == 0
  end
  
  specify "should update correctly" do
    @ds.update(:number=>:number+1).should == 1
    @ds.all.should == [{:id=>1, :number=>11}]
  end
  
  cspecify "should have update return the number of matched rows", [:mysql, :mysql], [:do, :mysql], [:mysql2], [:ado] do
    @ds.update(:number=>:number).should == 1
    @ds.filter(:id=>1).update(:number=>:number).should == 1
    @ds.filter(:id=>2).update(:number=>:number).should == 0
    @ds.all.should == [{:id=>1, :number=>10}]
  end

  specify "should fetch all results correctly" do
    @ds.all.should == [{:id=>1, :number=>10}]
  end

  specify "should fetch a single row correctly" do
    @ds.first.should == {:id=>1, :number=>10}
  end
  
  specify "should have distinct work with limit" do
    @ds.limit(1).distinct.all.should == [{:id=>1, :number=>10}]
  end
  
  specify "should fetch correctly with a limit" do
    @ds.order(:id).limit(2).all.should == [{:id=>1, :number=>10}]
    @ds.insert(:number=>20)
    @ds.order(:id).limit(1).all.should == [{:id=>1, :number=>10}]
    @ds.order(:id).limit(2).all.should == [{:id=>1, :number=>10}, {:id=>2, :number=>20}]
  end
  
  specify "should fetch correctly with a limit and offset" do
    @ds.order(:id).limit(2, 0).all.should == [{:id=>1, :number=>10}]
    @ds.order(:id).limit(2, 1).all.should == []
    @ds.insert(:number=>20)
    @ds.order(:id).limit(1, 1).all.should == [{:id=>2, :number=>20}]
    @ds.order(:id).limit(2, 0).all.should == [{:id=>1, :number=>10}, {:id=>2, :number=>20}]
    @ds.order(:id).limit(2, 1).all.should == [{:id=>2, :number=>20}]
  end
  
  specify "should provide correct columns when using a limit and offset" do
    ds = @ds.order(:id).limit(1, 1)
    ds.all
    ds.columns.should == [:id, :number]
    @ds.order(:id).limit(1, 1).columns.should == [:id, :number]
  end

  specify "should fetch correctly with a limit and offset for different combinations of from and join tables" do
    @db.create_table!(:items2){primary_key :id2; Integer :number2}
    @db[:items2].insert(:number2=>10)
    @ds.from(:items, :items2).order(:id).limit(2, 0).all.should == [{:id=>1, :number=>10, :id2=>1, :number2=>10}]
    @ds.from(:items___i, :items2___i2).order(:id).limit(2, 0).all.should == [{:id=>1, :number=>10, :id2=>1, :number2=>10}]
    @ds.cross_join(:items2).order(:id).limit(2, 0).all.should ==[{:id=>1, :number=>10, :id2=>1, :number2=>10}]
    @ds.from(:items___i).cross_join(:items2___i2).order(:id).limit(2, 0).all.should == [{:id=>1, :number=>10, :id2=>1, :number2=>10}]
    @ds.cross_join(:items2___i).cross_join(@db[:items2].select(:id2___id3, :number2___number3)).order(:id).limit(2, 0).all.should == [{:id=>1, :number=>10, :id2=>1, :number2=>10, :id3=>1, :number3=>10}]

    @ds.from(:items, :items2).order(:id).limit(2, 1).all.should == []
    @ds.from(:items___i, :items2___i2).order(:id).limit(2, 1).all.should == []
    @ds.cross_join(:items2).order(:id).limit(2, 1).all.should == []
    @ds.from(:items___i).cross_join(:items2___i2).order(:id).limit(2, 1).all.should == []
    @ds.cross_join(:items2___i).cross_join(@db[:items2].select(:id2___id3, :number2___number3)).order(:id).limit(2, 1).all.should == []
    @db.drop_table(:items2)
  end
  
  cspecify "should fetch correctly with a limit and offset without an order", :db2, :mssql, :oracle do
    @ds.limit(2, 1).all.should == []
  end

  specify "should fetch correctly with a limit in an IN subselect" do
    @ds.where(:id=>@ds.select(:id).order(:id).limit(2)).all.should == [{:id=>1, :number=>10}]
    @ds.insert(:number=>20)
    @ds.where(:id=>@ds.select(:id).order(:id).limit(1)).all.should == [{:id=>1, :number=>10}]
    @ds.where(:id=>@ds.select(:id).order(:id).limit(2)).order(:id).all.should == [{:id=>1, :number=>10}, {:id=>2, :number=>20}]
  end
  
  specify "should fetch correctly with a limit and offset in an IN subselect" do
    @ds.where(:id=>@ds.select(:id).order(:id).limit(2, 0)).all.should == [{:id=>1, :number=>10}]
    @ds.where(:id=>@ds.select(:id).order(:id).limit(2, 1)).all.should == []
    @ds.insert(:number=>20)
    @ds.where(:id=>@ds.select(:id).order(:id).limit(1, 1)).all.should == [{:id=>2, :number=>20}]
    @ds.where(:id=>@ds.select(:id).order(:id).limit(2, 0)).order(:id).all.should == [{:id=>1, :number=>10}, {:id=>2, :number=>20}]
    @ds.where(:id=>@ds.select(:id).order(:id).limit(2, 1)).all.should == [{:id=>2, :number=>20}]
  end
  
  specify "should alias columns correctly" do
    @ds.select(:id___x, :number___n).first.should == {:x=>1, :n=>10}
  end

  specify "should handle true/false properly" do
    @ds.filter(Sequel::TRUE).select_map(:number).should == [10]
    @ds.filter(Sequel::FALSE).select_map(:number).should == []
    @ds.filter(true).select_map(:number).should == [10]
    @ds.filter(false).select_map(:number).should == []
  end
end

describe Sequel::Dataset do
  before do
    INTEGRATION_DB.create_table!(:test) do
      String :name
      Integer :value
    end
    @d = INTEGRATION_DB[:test]
  end
  after do
    INTEGRATION_DB.drop_table(:test)
  end

  specify "should return the correct record count" do
    @d.count.should == 0
    @d << {:name => 'abc', :value => 123}
    @d << {:name => 'abc', :value => 456}
    @d << {:name => 'def', :value => 789}
    @d.count.should == 3
  end

  specify "should handle aggregate methods on limited datasets correctly" do
    @d << {:name => 'abc', :value => 6}
    @d << {:name => 'bcd', :value => 12}
    @d << {:name => 'def', :value => 18}
    @d = @d.order(:name).limit(2)
    @d.count.should == 2
    @d.avg(:value).to_i.should == 9
    @d.min(:value).to_i.should == 6
    @d.reverse.min(:value).to_i.should == 12
    @d.max(:value).to_i.should == 12
    @d.sum(:value).to_i.should == 18
    @d.interval(:value).to_i.should == 6
  end

  specify "should return the correct records" do
    @d.to_a.should == []
    @d << {:name => 'abc', :value => 123}
    @d << {:name => 'abc', :value => 456}
    @d << {:name => 'def', :value => 789}

    @d.order(:value).to_a.should == [
      {:name => 'abc', :value => 123},
      {:name => 'abc', :value => 456},
      {:name => 'def', :value => 789}
    ]
  end

  specify "should update records correctly" do
    @d << {:name => 'abc', :value => 123}
    @d << {:name => 'abc', :value => 456}
    @d << {:name => 'def', :value => 789}
    @d.filter(:name => 'abc').update(:value => 530)
    @d[:name => 'def'][:value].should == 789
    @d.filter(:value => 530).count.should == 2
  end

  specify "should delete records correctly" do
    @d << {:name => 'abc', :value => 123}
    @d << {:name => 'abc', :value => 456}
    @d << {:name => 'def', :value => 789}
    @d.filter(:name => 'abc').delete
    @d.count.should == 1
    @d.first[:name].should == 'def'
  end
  
  specify "should be able to truncate the table" do
    @d << {:name => 'abc', :value => 123}
    @d << {:name => 'abc', :value => 456}
    @d << {:name => 'def', :value => 789}
    @d.count.should == 3
    @d.truncate.should == nil
    @d.count.should == 0
  end

  specify "should be able to literalize booleans" do
    proc {@d.literal(true)}.should_not raise_error
    proc {@d.literal(false)}.should_not raise_error
  end
end

describe Sequel::Database do
  specify "should correctly escape strings" do
    INTEGRATION_DB.get("\\dingo".as(:a)) == "\\dingo"
  end

  specify "should correctly escape strings with quotes" do
    INTEGRATION_DB.get("\\'dingo".as(:a)) == "\\'dingo"
  end

  specify "should properly escape binary data" do
    INTEGRATION_DB.get("\1\2\3".to_sequel_blob.as(:a)) == "\1\2\3"
  end

  specify "should have a working table_exists?" do
    t = :basdfdsafsaddsaf
    INTEGRATION_DB.drop_table(t) rescue nil
    INTEGRATION_DB.table_exists?(t).should == false
    INTEGRATION_DB.create_table(t){Integer :a}
    begin
      INTEGRATION_DB.table_exists?(t).should == true
    ensure
      INTEGRATION_DB.drop_table(t)
    end
  end
end

describe Sequel::Dataset do
  before do
    INTEGRATION_DB.create_table! :items do
      primary_key :id 
      Integer :value
    end 
    @d = INTEGRATION_DB[:items]
    @d << {:value => 123}
    @d << {:value => 456}
    @d << {:value => 789}
  end 
  after do
    INTEGRATION_DB.drop_table(:items)
  end 
  
  specify "should correctly return avg" do
    @d.avg(:value).to_i.should == 456
  end 
  
  specify "should correctly return sum" do
    @d.sum(:value).to_i.should == 1368
  end 
  
  specify "should correctly return max" do
    @d.max(:value).to_i.should == 789 
  end 
  
  specify "should correctly return min" do
    @d.min(:value).to_i.should == 123 
  end 
end

describe "Simple Dataset operations" do
  before do
    INTEGRATION_DB.create_table!(:items) do
      Integer :number
      TrueClass :flag
    end
    @ds = INTEGRATION_DB[:items]
  end
  after do
    INTEGRATION_DB.drop_table(:items)
  end

  specify "should deal with boolean conditions correctly" do
    @ds.insert(:number=>1, :flag=>true)
    @ds.insert(:number=>2, :flag=>false)
    @ds.insert(:number=>3, :flag=>nil)
    @ds.order!(:number)
    @ds.filter(:flag=>true).map(:number).should == [1]
    @ds.filter(:flag=>false).map(:number).should == [2]
    @ds.filter(:flag=>nil).map(:number).should == [3]
    @ds.exclude(:flag=>true).map(:number).should == [2, 3]
    @ds.exclude(:flag=>false).map(:number).should == [1, 3]
    @ds.exclude(:flag=>nil).map(:number).should == [1, 2]
  end
end

describe "Simple Dataset operations in transactions" do
  before do
    INTEGRATION_DB.create_table!(:items) do
      primary_key :id
      integer :number
    end
    @ds = INTEGRATION_DB[:items]
  end
  after do
    INTEGRATION_DB.drop_table(:items)
  end

  cspecify "should insert correctly with a primary key specified inside a transaction", :db2, :mssql do
    INTEGRATION_DB.transaction do
      @ds.insert(:id=>100, :number=>20)
      @ds.count.should == 1
      @ds.order(:id).all.should == [{:id=>100, :number=>20}]
    end
  end
  
  specify "should have insert return primary key value inside a transaction" do
    INTEGRATION_DB.transaction do
      @ds.insert(:number=>20).should == 1
      @ds.count.should == 1
      @ds.order(:id).all.should == [{:id=>1, :number=>20}]
    end
  end
  
  specify "should support for_update" do
    INTEGRATION_DB.transaction{@ds.for_update.all.should == []}
  end
end

describe "Dataset UNION, EXCEPT, and INTERSECT" do
  before do
    INTEGRATION_DB.create_table!(:i1){integer :number}
    INTEGRATION_DB.create_table!(:i2){integer :number}
    @ds1 = INTEGRATION_DB[:i1]
    @ds1.insert(:number=>10)
    @ds1.insert(:number=>20)
    @ds2 = INTEGRATION_DB[:i2]
    @ds2.insert(:number=>10)
    @ds2.insert(:number=>30)
  end
  
  specify "should give the correct results for simple UNION, EXCEPT, and INTERSECT" do
    @ds1.union(@ds2).order(:number).map{|x| x[:number].to_s}.should == %w'10 20 30'
    if @ds1.supports_intersect_except?
      @ds1.except(@ds2).order(:number).map{|x| x[:number].to_s}.should == %w'20'
      @ds1.intersect(@ds2).order(:number).map{|x| x[:number].to_s}.should == %w'10'
    end
  end
  
  cspecify "should give the correct results for UNION, EXCEPT, and INTERSECT when used with ordering and limits", :mssql do
    @ds1.insert(:number=>8)
    @ds2.insert(:number=>9)
    @ds1.insert(:number=>38)
    @ds2.insert(:number=>39)

    @ds1.order(:number.desc).union(@ds2).order(:number).map{|x| x[:number].to_s}.should == %w'8 9 10 20 30 38 39'
    @ds1.union(@ds2.order(:number.desc)).order(:number).map{|x| x[:number].to_s}.should == %w'8 9 10 20 30 38 39'

    @ds1.order(:number.desc).limit(1).union(@ds2).order(:number).map{|x| x[:number].to_s}.should == %w'9 10 30 38 39'
    @ds2.order(:number.desc).limit(1).union(@ds1).order(:number).map{|x| x[:number].to_s}.should == %w'8 10 20 38 39'

    @ds1.union(@ds2.order(:number).limit(1)).order(:number).map{|x| x[:number].to_s}.should == %w'8 9 10 20 38'
    @ds2.union(@ds1.order(:number).limit(1)).order(:number).map{|x| x[:number].to_s}.should == %w'8 9 10 30 39'

    @ds1.union(@ds2).limit(2).order(:number).map{|x| x[:number].to_s}.should == %w'8 9'
    @ds2.union(@ds1).order(:number.desc).limit(2).map{|x| x[:number].to_s}.should == %w'39 38'

    @ds1.order(:number.desc).limit(2).union(@ds2.order(:number.desc).limit(2)).order(:number).limit(3).map{|x| x[:number].to_s}.should == %w'20 30 38'
    @ds2.order(:number).limit(2).union(@ds1.order(:number).limit(2)).order(:number.desc).limit(3).map{|x| x[:number].to_s}.should == %w'10 9 8'
  end

  specify "should give the correct results for compound UNION, EXCEPT, and INTERSECT" do
    INTEGRATION_DB.create_table!(:i3){integer :number}
    @ds3 = INTEGRATION_DB[:i3]
    @ds3.insert(:number=>10)
    @ds3.insert(:number=>40)

    @ds1.union(@ds2).union(@ds3).order(:number).map{|x| x[:number].to_s}.should == %w'10 20 30 40'
    @ds1.union(@ds2.union(@ds3)).order(:number).map{|x| x[:number].to_s}.should == %w'10 20 30 40'
    if @ds1.supports_intersect_except?
      @ds1.union(@ds2).except(@ds3).order(:number).map{|x| x[:number].to_s}.should == %w'20 30'
      @ds1.union(@ds2.except(@ds3)).order(:number).map{|x| x[:number].to_s}.should == %w'10 20 30'
      @ds1.union(@ds2).intersect(@ds3).order(:number).map{|x| x[:number].to_s}.should == %w'10 '
      @ds1.union(@ds2.intersect(@ds3)).order(:number).map{|x| x[:number].to_s}.should == %w'10 20'
      
      @ds1.except(@ds2).union(@ds3).order(:number).map{|x| x[:number].to_s}.should == %w'10 20 40'
      @ds1.except(@ds2.union(@ds3)).order(:number).map{|x| x[:number].to_s}.should == %w'20'
      @ds1.except(@ds2).except(@ds3).order(:number).map{|x| x[:number].to_s}.should == %w'20'
      @ds1.except(@ds2.except(@ds3)).order(:number).map{|x| x[:number].to_s}.should == %w'10 20'
      @ds1.except(@ds2).intersect(@ds3).order(:number).map{|x| x[:number].to_s}.should == %w''
      @ds1.except(@ds2.intersect(@ds3)).order(:number).map{|x| x[:number].to_s}.should == %w'20'
      
      @ds1.intersect(@ds2).union(@ds3).order(:number).map{|x| x[:number].to_s}.should == %w'10 40'
      @ds1.intersect(@ds2.union(@ds3)).order(:number).map{|x| x[:number].to_s}.should == %w'10'
      @ds1.intersect(@ds2).except(@ds3).order(:number).map{|x| x[:number].to_s}.should == %w''
      @ds1.intersect(@ds2.except(@ds3)).order(:number).map{|x| x[:number].to_s}.should == %w''
      @ds1.intersect(@ds2).intersect(@ds3).order(:number).map{|x| x[:number].to_s}.should == %w'10'
      @ds1.intersect(@ds2.intersect(@ds3)).order(:number).map{|x| x[:number].to_s}.should == %w'10'
    end
  end
end

if INTEGRATION_DB.dataset.supports_cte?
  describe "Common Table Expressions" do
    before(:all) do
      @db = INTEGRATION_DB
      @db.create_table!(:i1){Integer :id; Integer :parent_id}
      @ds = @db[:i1]
      @ds.insert(:id=>1)
      @ds.insert(:id=>2)
      @ds.insert(:id=>3, :parent_id=>1)
      @ds.insert(:id=>4, :parent_id=>1)
      @ds.insert(:id=>5, :parent_id=>3)
      @ds.insert(:id=>6, :parent_id=>5)
    end
    after(:all) do
      @db.drop_table(:i1)
    end
    
    specify "should give correct results for WITH" do
      @db[:t].with(:t, @ds.filter(:parent_id=>nil).select(:id)).order(:id).map(:id).should == [1, 2]
    end
    
    cspecify "should give correct results for recursive WITH", :db2 do
      ds = @db[:t].select(:i___id, :pi___parent_id).with_recursive(:t, @ds.filter(:parent_id=>nil), @ds.join(:t, :i=>:parent_id).select(:i1__id, :i1__parent_id), :args=>[:i, :pi])
      ds.all.should == [{:parent_id=>nil, :id=>1}, {:parent_id=>nil, :id=>2}, {:parent_id=>1, :id=>3}, {:parent_id=>1, :id=>4}, {:parent_id=>3, :id=>5}, {:parent_id=>5, :id=>6}]
      ps = @db[:t].select(:i___id, :pi___parent_id).with_recursive(:t, @ds.filter(:parent_id=>:$n), @ds.join(:t, :i=>:parent_id).filter(:t__i=>:parent_id).select(:i1__id, :i1__parent_id), :args=>[:i, :pi]).prepare(:select, :cte_sel)
      ps.call(:n=>1).should == [{:id=>3, :parent_id=>1}, {:id=>4, :parent_id=>1}, {:id=>5, :parent_id=>3}, {:id=>6, :parent_id=>5}]
      ps.call(:n=>3).should == [{:id=>5, :parent_id=>3}, {:id=>6, :parent_id=>5}]
      ps.call(:n=>5).should == [{:id=>6, :parent_id=>5}]
    end

    specify "should support joining a dataset with a CTE" do
      @ds.inner_join(@db[:t].with(:t, @ds.filter(:parent_id=>nil)), :id => :id).select(:i1__id).order(:i1__id).map(:id).should == [1,2]
      @db[:t].with(:t, @ds).inner_join(@db[:s].with(:s, @ds.filter(:parent_id=>nil)), :id => :id).select(:t__id).order(:t__id).map(:id).should == [1,2]
    end

    specify "should support a subselect in the FROM clause with a CTE" do
      @ds.from(@db[:t].with(:t, @ds)).select_order_map(:id).should == [1,2,3,4,5,6]
      @db[:t].with(:t, @ds).from_self.select_order_map(:id).should == [1,2,3,4,5,6]
    end

    specify "should support using a CTE inside a CTE" do
      @db[:s].with(:s, @db[:t].with(:t, @ds)).select_order_map(:id).should == [1,2,3,4,5,6]
      @db[:s].with_recursive(:s, @db[:t].with(:t, @ds), @db[:t2].with(:t2, @ds)).select_order_map(:id).should == [1,1,2,2,3,3,4,4,5,5,6,6]
    end

    specify "should support using a CTE inside UNION/EXCEPT/INTERSECT" do
      @ds.union(@db[:t].with(:t, @ds)).select_order_map(:id).should == [1,2,3,4,5,6]
      if @ds.supports_intersect_except?
        @ds.intersect(@db[:t].with(:t, @ds)).select_order_map(:id).should == [1,2,3,4,5,6]
        @ds.except(@db[:t].with(:t, @ds)).select_order_map(:id).should == []
      end
    end
  end
end

if INTEGRATION_DB.dataset.supports_cte?(:update) # Assume INSERT and DELETE support as well
  describe "Common Table Expressions in INSERT/UPDATE/DELETE" do
    before do
      @db = INTEGRATION_DB
      @db.create_table!(:i1){Integer :id}
      @ds = @db[:i1]
      @ds2 = @ds.with(:t, @ds)
      @ds.insert(:id=>1)
      @ds.insert(:id=>2)
    end
    after do
      @db.drop_table(:i1)
    end
    
    specify "should give correct results for WITH" do
      @ds2.insert(@db[:t])
      @ds.select_order_map(:id).should == [1, 1, 2, 2]
      @ds2.filter(:id=>@db[:t].select{max(id)}).update(:id=>:id+1)
      @ds.select_order_map(:id).should == [1, 1, 3, 3]
      @ds2.filter(:id=>@db[:t].select{max(id)}).delete
      @ds.select_order_map(:id).should == [1, 1]
    end
  end
end

if INTEGRATION_DB.dataset.supports_returning?(:insert)
  describe "RETURNING clauses in INSERT" do
    before do
      @db = INTEGRATION_DB
      @db.create_table!(:i1){Integer :id; Integer :foo}
      @ds = @db[:i1]
    end
    after do
      @db.drop_table(:i1)
    end
    
    specify "should give correct results" do
      h = {}
      @ds.returning(:foo).insert(1, 2){|r| h = r}
      h.should == {:foo=>2}
      @ds.returning(:id).insert(3, 4){|r| h = r}
      h.should == {:id=>3}
      @ds.returning.insert(5, 6){|r| h = r}
      h.should == {:id=>5, :foo=>6}
      @ds.returning(:id___foo, :foo___id).insert(7, 8){|r| h = r}
      h.should == {:id=>8, :foo=>7}
    end
  end
end

if INTEGRATION_DB.dataset.supports_returning?(:update) # Assume DELETE support as well
  describe "RETURNING clauses in UPDATE/DELETE" do
    before do
      @db = INTEGRATION_DB
      @db.create_table!(:i1){Integer :id; Integer :foo}
      @ds = @db[:i1]
      @ds.insert(1, 2)
    end
    after do
      @db.drop_table(:i1)
    end
    
    specify "should give correct results" do
      h = []
      @ds.returning(:foo).update(:id=>:id+1, :foo=>:foo*2){|r| h << r}
      h.should == [{:foo=>4}]
      h.clear
      @ds.returning(:id).update(:id=>:id+1, :foo=>:foo*2){|r| h << r}
      h.should == [{:id=>3}]
      h.clear
      @ds.returning.update(:id=>:id+1, :foo=>:foo*2){|r| h << r}
      h.should == [{:id=>4, :foo=>16}]
      h.clear
      @ds.returning(:id___foo, :foo___id).update(:id=>:id+1, :foo=>:foo*2){|r| h << r}
      h.should == [{:id=>32, :foo=>5}]
      h.clear

      @ds.returning.delete{|r| h << r}
      h.should == [{:id=>5, :foo=>32}]
      h.clear
      @ds.returning.delete{|r| h << r}
      h.should == []
    end
  end
end

if INTEGRATION_DB.dataset.supports_window_functions?
  describe "Window Functions" do
    before(:all) do
      @db = INTEGRATION_DB
      @db.create_table!(:i1){Integer :id; Integer :group_id; Integer :amount}
      @ds = @db[:i1].order(:id)
      @ds.insert(:id=>1, :group_id=>1, :amount=>1)
      @ds.insert(:id=>2, :group_id=>1, :amount=>10)
      @ds.insert(:id=>3, :group_id=>1, :amount=>100)
      @ds.insert(:id=>4, :group_id=>2, :amount=>1000)
      @ds.insert(:id=>5, :group_id=>2, :amount=>10000)
      @ds.insert(:id=>6, :group_id=>2, :amount=>100000)
    end
    after(:all) do
      @db.drop_table(:i1)
    end
    
    specify "should give correct results for aggregate window functions" do
      @ds.select(:id){sum(:over, :args=>amount, :partition=>group_id){}.as(:sum)}.all.should ==
        [{:sum=>111, :id=>1}, {:sum=>111, :id=>2}, {:sum=>111, :id=>3}, {:sum=>111000, :id=>4}, {:sum=>111000, :id=>5}, {:sum=>111000, :id=>6}]
      @ds.select(:id){sum(:over, :args=>amount){}.as(:sum)}.all.should ==
        [{:sum=>111111, :id=>1}, {:sum=>111111, :id=>2}, {:sum=>111111, :id=>3}, {:sum=>111111, :id=>4}, {:sum=>111111, :id=>5}, {:sum=>111111, :id=>6}]
    end
      
    specify "should give correct results for ranking window functions with orders" do
      @ds.select(:id){rank(:over, :partition=>group_id, :order=>id){}.as(:rank)}.all.should ==
        [{:rank=>1, :id=>1}, {:rank=>2, :id=>2}, {:rank=>3, :id=>3}, {:rank=>1, :id=>4}, {:rank=>2, :id=>5}, {:rank=>3, :id=>6}]
      @ds.select(:id){rank(:over, :order=>id){}.as(:rank)}.all.should ==
        [{:rank=>1, :id=>1}, {:rank=>2, :id=>2}, {:rank=>3, :id=>3}, {:rank=>4, :id=>4}, {:rank=>5, :id=>5}, {:rank=>6, :id=>6}]
    end
      
    cspecify "should give correct results for aggregate window functions with orders", :mssql do
      @ds.select(:id){sum(:over, :args=>amount, :partition=>group_id, :order=>id){}.as(:sum)}.all.should ==
        [{:sum=>1, :id=>1}, {:sum=>11, :id=>2}, {:sum=>111, :id=>3}, {:sum=>1000, :id=>4}, {:sum=>11000, :id=>5}, {:sum=>111000, :id=>6}]
      @ds.select(:id){sum(:over, :args=>amount, :order=>id){}.as(:sum)}.all.should ==
        [{:sum=>1, :id=>1}, {:sum=>11, :id=>2}, {:sum=>111, :id=>3}, {:sum=>1111, :id=>4}, {:sum=>11111, :id=>5}, {:sum=>111111, :id=>6}]
    end
    
    cspecify "should give correct results for aggregate window functions with frames", :mssql do
      @ds.select(:id){sum(:over, :args=>amount, :partition=>group_id, :order=>id, :frame=>:all){}.as(:sum)}.all.should ==
        [{:sum=>111, :id=>1}, {:sum=>111, :id=>2}, {:sum=>111, :id=>3}, {:sum=>111000, :id=>4}, {:sum=>111000, :id=>5}, {:sum=>111000, :id=>6}]
      @ds.select(:id){sum(:over, :args=>amount, :order=>id, :frame=>:all){}.as(:sum)}.all.should ==
        [{:sum=>111111, :id=>1}, {:sum=>111111, :id=>2}, {:sum=>111111, :id=>3}, {:sum=>111111, :id=>4}, {:sum=>111111, :id=>5}, {:sum=>111111, :id=>6}]
        
      @ds.select(:id){sum(:over, :args=>amount, :partition=>group_id, :order=>id, :frame=>:rows){}.as(:sum)}.all.should ==
        [{:sum=>1, :id=>1}, {:sum=>11, :id=>2}, {:sum=>111, :id=>3}, {:sum=>1000, :id=>4}, {:sum=>11000, :id=>5}, {:sum=>111000, :id=>6}]
      @ds.select(:id){sum(:over, :args=>amount, :order=>id, :frame=>:rows){}.as(:sum)}.all.should ==
        [{:sum=>1, :id=>1}, {:sum=>11, :id=>2}, {:sum=>111, :id=>3}, {:sum=>1111, :id=>4}, {:sum=>11111, :id=>5}, {:sum=>111111, :id=>6}]
    end
  end
end

describe Sequel::SQL::Constants do
  before do
    @db = INTEGRATION_DB
    @ds = @db[:constants]
    @c = proc do |v|
      case v
      when Time
        v
      when DateTime, String
        Time.parse(v.to_s)
      else
        v
      end
    end
    @c2 = proc{|v| v.is_a?(Date) ? v : Date.parse(v) }
  end
  after do
    @db.drop_table(:constants) if @db.table_exists?(:constants)
  end
  
  cspecify "should have working CURRENT_DATE", [:odbc, :mssql], [:jdbc, :sqlite], :oracle do
    @db.create_table!(:constants){Date :d}
    @ds.insert(:d=>Sequel::CURRENT_DATE)
    d = @c2[@ds.get(:d)]
    d.should be_a_kind_of(Date)
    d.to_s.should == Date.today.to_s
  end

  cspecify "should have working CURRENT_TIME", [:do, :mysql], [:jdbc, :sqlite], [:mysql2] do
    @db.create_table!(:constants){Time :t, :only_time=>true}
    @ds.insert(:t=>Sequel::CURRENT_TIME)
    (Time.now - @c[@ds.get(:t)]).should be_within(2).of(0)
  end

  cspecify "should have working CURRENT_TIMESTAMP", [:jdbc, :sqlite] do
    @db.create_table!(:constants){DateTime :ts}
    @ds.insert(:ts=>Sequel::CURRENT_TIMESTAMP)
    (Time.now - @c[@ds.get(:ts)]).should be_within(2).of(0)
  end
end

describe "Sequel::Dataset#import and #multi_insert" do
  before(:all) do
    @db = INTEGRATION_DB
    @db.create_table!(:imp){Integer :i}
    @ids = @db[:imp].order(:i)
  end
  before do
    @ids.delete
  end
  after(:all) do
    @db.drop_table(:imp)
  end

  it "should import with multi_insert and an array of hashes" do
    @ids.multi_insert([{:i=>10}, {:i=>20}])
    @ids.all.should == [{:i=>10}, {:i=>20}]
  end

  it "should import with an array of arrays of values" do
    @ids.import([:i], [[10], [20]])
    @ids.all.should == [{:i=>10}, {:i=>20}]
  end

  it "should import with a dataset" do
    @db.create_table!(:exp2){Integer :i}
    @db[:exp2].import([:i], [[10], [20]])
    @ids.import([:i], @db[:exp2])
    @ids.all.should == [{:i=>10}, {:i=>20}]
    @db.drop_table(:exp2)
  end
  
  it "should have import work with the :slice_size option" do
    @ids.import([:i], [[10], [20], [30]], :slice_size=>1)
    @ids.all.should == [{:i=>10}, {:i=>20}, {:i=>30}]
    @ids.delete
    @ids.import([:i], [[10], [20], [30]], :slice_size=>2)
    @ids.all.should == [{:i=>10}, {:i=>20}, {:i=>30}]
    @ids.delete
    @ids.import([:i], [[10], [20], [30]], :slice_size=>3)
    @ids.all.should == [{:i=>10}, {:i=>20}, {:i=>30}]
  end
end

describe "Sequel::Dataset convenience methods" do
  before(:all) do
    @db = INTEGRATION_DB
    @db.create_table!(:a){Integer :a; Integer :b}
    @ds = @db[:a].order(:a)
  end
  before do
    @ds.delete
  end
  after(:all) do
    @db.drop_table(:a)
  end
  
  it "#[]= should update matching rows" do
    @ds.insert(20, 10)
    @ds[:a=>20] = {:b=>30}
    @ds.all.should == [{:a=>20, :b=>30}]
  end
  
  it "#empty? should return whether the dataset returns no rows" do
    @ds.empty?.should == true
    @ds.insert(20, 10)
    @ds.empty?.should == false
  end
  
  it "#group_and_count should return a grouping by count" do
    @ds.group_and_count(:a).order(:count).all.should == []
    @ds.insert(20, 10)
    @ds.group_and_count(:a).order(:count).all.each{|h| h[:count] = h[:count].to_i}.should == [{:a=>20, :count=>1}]
    @ds.insert(20, 30)
    @ds.group_and_count(:a).order(:count).all.each{|h| h[:count] = h[:count].to_i}.should == [{:a=>20, :count=>2}]
    @ds.insert(30, 30)
    @ds.group_and_count(:a).order(:count).all.each{|h| h[:count] = h[:count].to_i}.should == [{:a=>30, :count=>1}, {:a=>20, :count=>2}]
  end
  
  it "#group_and_count should support column aliases" do
    @ds.group_and_count(:a___c).order(:count).all.should == []
    @ds.insert(20, 10)
    @ds.group_and_count(:a___c).order(:count).all.each{|h| h[:count] = h[:count].to_i}.should == [{:c=>20, :count=>1}]
    @ds.insert(20, 30)
    @ds.group_and_count(:a___c).order(:count).all.each{|h| h[:count] = h[:count].to_i}.should == [{:c=>20, :count=>2}]
    @ds.insert(30, 30)
    @ds.group_and_count(:a___c).order(:count).all.each{|h| h[:count] = h[:count].to_i}.should == [{:c=>30, :count=>1}, {:c=>20, :count=>2}]
  end
  
  specify "#range should return the range between the maximum and minimum values" do
    @ds = @ds.unordered
    @ds.insert(20, 10)
    @ds.insert(30, 10)
    @ds.range(:a).should == (20..30)
    @ds.range(:b).should == (10..10)
  end
  
  it "#interval should return the different between the maximum and minimum values" do
    @ds = @ds.unordered
    @ds.insert(20, 10)
    @ds.insert(30, 10)
    @ds.interval(:a).to_i.should == 10
    @ds.interval(:b).to_i.should == 0
  end
end
  
describe "Sequel::Dataset main SQL methods" do
  before(:all) do
    @db = INTEGRATION_DB
    @db.create_table!(:a){Integer :a; Integer :b}
    @ds = @db[:a].order(:a)
  end
  before do
    @ds.delete
  end
  after(:all) do
    @db.drop_table(:a)
  end
  
  it "#exists should return a usable exists clause" do
    @ds.filter(@db[:a___c].filter(:c__a=>:a__b).exists).all.should == []
    @ds.insert(20, 30)
    @ds.insert(10, 20)
    @ds.filter(@db[:a___c].filter(:c__a=>:a__b).exists).all.should == [{:a=>10, :b=>20}]
  end
  
  it "#filter and #exclude should work with placeholder strings" do
    @ds.insert(20, 30)
    @ds.filter("a > ?", 15).all.should == [{:a=>20, :b=>30}]
    @ds.exclude("b < ?", 15).all.should == [{:a=>20, :b=>30}]
    @ds.filter("b < ?", 15).invert.all.should == [{:a=>20, :b=>30}]
  end
  
  it "#and and #or should work correctly" do
    @ds.insert(20, 30)
    @ds.filter(:a=>20).and(:b=>30).all.should == [{:a=>20, :b=>30}]
    @ds.filter(:a=>20).and(:b=>15).all.should == []
    @ds.filter(:a=>20).or(:b=>15).all.should == [{:a=>20, :b=>30}]
    @ds.filter(:a=>10).or(:b=>15).all.should == []
  end

  it "#select_group should work correctly" do
    @ds.unordered!
    @ds.select_group(:a).all.should == []
    @ds.insert(20, 30)
    @ds.select_group(:a).all.should == [{:a=>20}]
    @ds.select_group(:b).all.should == [{:b=>30}]
    @ds.insert(20, 40)
    @ds.select_group(:a).all.should == [{:a=>20}]
    @ds.order(:b).select_group(:b).all.should == [{:b=>30}, {:b=>40}]
  end

  it "#select_group should work correctly when aliasing" do
    @ds.unordered!
    @ds.insert(20, 30)
    @ds.select_group(:b___c).all.should == [{:c=>30}]
  end
  
  it "#having should work correctly" do
    @ds.unordered!
    @ds.select{[b, max(a).as(c)]}.group(:b).having{max(a) > 30}.all.should == []
    @ds.insert(20, 30)
    @ds.select{[b, max(a).as(c)]}.group(:b).having{max(a) > 30}.all.should == []
    @ds.insert(40, 20)
    @ds.select{[b, max(a).as(c)]}.group(:b).having{max(a) > 30}.all.each{|h| h[:c] = h[:c].to_i}.should == [{:b=>20, :c=>40}]
  end
  
  cspecify "#having should work without a previous group", :sqlite do
    @ds.unordered!
    @ds.select{max(a).as(c)}.having{max(a) > 30}.all.should == []
    @ds.insert(20, 30)
    @ds.select{max(a).as(c)}.having{max(a) > 30}.all.should == []
    @ds.insert(40, 20)
    @ds.select{max(a).as(c)}.having{max(a) > 30}.all.each{|h| h[:c] = h[:c].to_i}.should == [{:c=>40}]
  end
end

describe "Sequel::Dataset convenience methods" do
  before(:all) do
    @db = INTEGRATION_DB
    @db.create_table!(:a){Integer :a; Integer :b; Integer :c; Integer :d}
    @ds = @db[:a].order(:a)
  end
  before do
    @ds.delete
    @ds.insert(1, 2, 3, 4)
    @ds.insert(5, 6, 7, 8)
  end
  after(:all) do
    @db.drop_table(:a)
  end
  
  specify "should have working #map" do
    @ds.map(:a).should == [1, 5]
    @ds.map(:b).should == [2, 6]
    @ds.map([:a, :b]).should == [[1, 2], [5, 6]]
  end
  
  specify "should have working #to_hash" do
    @ds.to_hash(:a).should == {1=>{:a=>1, :b=>2, :c=>3, :d=>4}, 5=>{:a=>5, :b=>6, :c=>7, :d=>8}}
    @ds.to_hash(:b).should == {2=>{:a=>1, :b=>2, :c=>3, :d=>4}, 6=>{:a=>5, :b=>6, :c=>7, :d=>8}}
    @ds.to_hash([:a, :b]).should == {[1, 2]=>{:a=>1, :b=>2, :c=>3, :d=>4}, [5, 6]=>{:a=>5, :b=>6, :c=>7, :d=>8}}

    @ds.to_hash(:a, :b).should == {1=>2, 5=>6}
    @ds.to_hash([:a, :c], :b).should == {[1, 3]=>2, [5, 7]=>6}
    @ds.to_hash(:a, [:b, :c]).should == {1=>[2, 3], 5=>[6, 7]}
    @ds.to_hash([:a, :c], [:b, :d]).should == {[1, 3]=>[2, 4], [5, 7]=>[6, 8]}
  end

  specify "should have working #select_map" do
    @ds.select_map(:a).should == [1, 5]
    @ds.select_map(:b).should == [2, 6]
    @ds.select_map([:a]).should == [[1], [5]]
    @ds.select_map([:a, :b]).should == [[1, 2], [5, 6]]

    @ds.select_map(:a___e).should == [1, 5]
    @ds.select_map(:b___e).should == [2, 6]
    @ds.select_map([:a___e, :b___f]).should == [[1, 2], [5, 6]]
    @ds.select_map([:a__a___e, :a__b___f]).should == [[1, 2], [5, 6]]
    @ds.select_map([:a__a.as(:e), :a__b.as(:f)]).should == [[1, 2], [5, 6]]
    @ds.select_map([:a.qualify(:a).as(:e), :b.qualify(:a).as(:f)]).should == [[1, 2], [5, 6]]
    @ds.select_map([:a.identifier.qualify(:a).as(:e), :b.qualify(:a).as(:f)]).should == [[1, 2], [5, 6]]
  end
  
  specify "should have working #select_order_map" do
    @ds.select_order_map(:a).should == [1, 5]
    @ds.select_order_map(:a__b.desc).should == [6, 2]
    @ds.select_order_map(:a__b___e.desc).should == [6, 2]
    @ds.select_order_map(:b.qualify(:a).as(:e)).should == [2, 6]
    @ds.select_order_map([:a]).should == [[1], [5]]
    @ds.select_order_map([:a.desc, :b]).should == [[5, 6], [1, 2]]

    @ds.select_order_map(:a___e).should == [1, 5]
    @ds.select_order_map(:b___e).should == [2, 6]
    @ds.select_order_map([:a___e.desc, :b___f]).should == [[5, 6], [1, 2]]
    @ds.select_order_map([:a__a___e.desc, :a__b___f]).should == [[5, 6], [1, 2]]
    @ds.select_order_map([:a__a.desc, :a__b.as(:f)]).should == [[5, 6], [1, 2]]
    @ds.select_order_map([:a.qualify(:a).desc, :b.qualify(:a).as(:f)]).should == [[5, 6], [1, 2]]
    @ds.select_order_map([:a.identifier.qualify(:a).desc, :b.qualify(:a).as(:f)]).should == [[5, 6], [1, 2]]
  end

  specify "should have working #select_hash" do
    @ds.select_hash(:a, :b).should == {1=>2, 5=>6}
    @ds.select_hash(:a__a___e, :b).should == {1=>2, 5=>6}
    @ds.select_hash(:a__a.as(:e), :b).should == {1=>2, 5=>6}
    @ds.select_hash(:a.qualify(:a).as(:e), :b).should == {1=>2, 5=>6}
    @ds.select_hash(:a.identifier.qualify(:a).as(:e), :b).should == {1=>2, 5=>6}
    @ds.select_hash([:a, :c], :b).should == {[1, 3]=>2, [5, 7]=>6}
    @ds.select_hash(:a, [:b, :c]).should == {1=>[2, 3], 5=>[6, 7]}
    @ds.select_hash([:a, :c], [:b, :d]).should == {[1, 3]=>[2, 4], [5, 7]=>[6, 8]}
  end
end

describe "Sequel::Dataset DSL support" do
  before(:all) do
    @db = INTEGRATION_DB
    @db.create_table!(:a){Integer :a; Integer :b}
    @ds = @db[:a].order(:a)
  end
  before do
    @ds.delete
  end
  after(:all) do
    @db.drop_table(:a)
  end
  
  it "should work with standard mathematical operators" do
    @ds.insert(20, 10)
    @ds.get{a + b}.to_i.should == 30
    @ds.get{a - b}.to_i.should == 10
    @ds.get{a * b}.to_i.should == 200
    @ds.get{a / b}.to_i.should == 2
  end
  
  cspecify "should work with bitwise shift operators", :derby do
    @ds.insert(3, 2)
    @ds.get{a.sql_number << b}.to_i.should == 12
    @ds.get{a.sql_number >> b}.to_i.should == 0
    @ds.get{a.sql_number << b << 1}.to_i.should == 24
    @ds.delete
    @ds.insert(3, 1)
    @ds.get{a.sql_number << b}.to_i.should == 6
    @ds.get{a.sql_number >> b}.to_i.should == 1
    @ds.get{a.sql_number >> b >> 1}.to_i.should == 0
  end

  cspecify "should work with bitwise AND and OR operators", :derby do
    @ds.insert(3, 5)
    @ds.get{a.sql_number | b}.to_i.should == 7
    @ds.get{a.sql_number & b}.to_i.should == 1
    @ds.get{a.sql_number | b | 8}.to_i.should == 15
    @ds.get{a.sql_number & b & 8}.to_i.should == 0
  end
  
  specify "should work with the bitwise compliment operator" do
    @ds.insert(-3, 3)
    @ds.get{~a.sql_number}.to_i.should == 2
    @ds.get{~b.sql_number}.to_i.should == -4
  end
  
  cspecify "should work with the bitwise xor operator", :derby do
    @ds.insert(3, 5)
    @ds.get{a.sql_number ^ b}.to_i.should == 6
    @ds.get{a.sql_number ^ b ^ 1}.to_i.should == 7
  end
  
  specify "should work with inequality operators" do
    @ds.insert(10, 11)
    @ds.insert(11, 11)
    @ds.insert(20, 19)
    @ds.insert(20, 20)
    @ds.filter{a > b}.select_order_map(:a).should == [20]
    @ds.filter{a >= b}.select_order_map(:a).should == [11, 20, 20]
    @ds.filter{a < b}.select_order_map(:a).should == [10]
    @ds.filter{a <= b}.select_order_map(:a).should == [10, 11, 20]
  end
  
  specify "should work with casting and string concatentation" do
    @ds.insert(20, 20)
    @ds.get{a.cast_string + b.cast_string}.should == '2020'
  end
  
  it "should work with ordering" do
    @ds.insert(10, 20)
    @ds.insert(20, 10)
    @ds.order(:a, :b).all.should == [{:a=>10, :b=>20}, {:a=>20, :b=>10}]
    @ds.order(:a.asc, :b.asc).all.should == [{:a=>10, :b=>20}, {:a=>20, :b=>10}]
    @ds.order(:a.desc, :b.desc).all.should == [{:a=>20, :b=>10}, {:a=>10, :b=>20}]
  end
  
  it "should work with qualifying" do
    @ds.insert(10, 20)
    @ds.get(:a__b).should == 20
    @ds.get{a__b}.should == 20
    @ds.get(:b.qualify(:a)).should == 20
  end
  
  it "should work with aliasing" do
    @ds.insert(10, 20)
    @ds.get(:a__b___c).should == 20
    @ds.get{a__b.as(c)}.should == 20
    @ds.get(:b.qualify(:a).as(:c)).should == 20
    @ds.get(:b.as(:c)).should == 20
  end
  
  it "should work with selecting all columns of a table" do
    @ds.insert(20, 10)
    @ds.select(:a.*).all.should == [{:a=>20, :b=>10}]
  end
  
  it "should work with ranges as hash values" do
    @ds.insert(20, 10)
    @ds.filter(:a=>(10..30)).all.should == [{:a=>20, :b=>10}]
    @ds.filter(:a=>(25..30)).all.should == []
    @ds.filter(:a=>(10..15)).all.should == []
    @ds.exclude(:a=>(10..30)).all.should == []
    @ds.exclude(:a=>(25..30)).all.should == [{:a=>20, :b=>10}]
    @ds.exclude(:a=>(10..15)).all.should == [{:a=>20, :b=>10}]
  end
  
  it "should work with nil as hash value" do
    @ds.insert(20, nil)
    @ds.filter(:a=>nil).all.should == []
    @ds.filter(:b=>nil).all.should == [{:a=>20, :b=>nil}]
    @ds.exclude(:b=>nil).all.should == []
    @ds.exclude(:a=>nil).all.should == [{:a=>20, :b=>nil}]
  end
  
  it "should work with arrays as hash values" do
    @ds.insert(20, 10)
    @ds.filter(:a=>[10]).all.should == []
    @ds.filter(:a=>[20, 10]).all.should == [{:a=>20, :b=>10}]
    @ds.exclude(:a=>[10]).all.should == [{:a=>20, :b=>10}]
    @ds.exclude(:a=>[20, 10]).all.should == []
  end
  
  it "should work with ranges as hash values" do
    @ds.insert(20, 10)
    @ds.filter(:a=>(10..30)).all.should == [{:a=>20, :b=>10}]
    @ds.filter(:a=>(25..30)).all.should == []
    @ds.filter(:a=>(10..15)).all.should == []
    @ds.exclude(:a=>(10..30)).all.should == []
    @ds.exclude(:a=>(25..30)).all.should == [{:a=>20, :b=>10}]
    @ds.exclude(:a=>(10..15)).all.should == [{:a=>20, :b=>10}]
  end
  
  it "should work with CASE statements" do
    @ds.insert(20, 10)
    @ds.filter({{:a=>20}=>20}.case(0) > 0).all.should == [{:a=>20, :b=>10}]
    @ds.filter({{:a=>15}=>20}.case(0) > 0).all.should == []
    @ds.filter({20=>20}.case(0, :a) > 0).all.should == [{:a=>20, :b=>10}]
    @ds.filter({15=>20}.case(0, :a) > 0).all.should == []
  end
  
  specify "should work with multiple value arrays" do
    @ds.insert(20, 10)
    @ds.quote_identifiers = false
    @ds.filter([:a, :b]=>[[20, 10]].sql_array).all.should == [{:a=>20, :b=>10}]
    @ds.filter([:a, :b]=>[[10, 20]].sql_array).all.should == []
    @ds.filter([:a, :b]=>[[20, 10], [1, 2]].sql_array).all.should == [{:a=>20, :b=>10}]
    @ds.filter([:a, :b]=>[[10, 10], [20, 20]].sql_array).all.should == []
    
    @ds.exclude([:a, :b]=>[[20, 10]].sql_array).all.should == []
    @ds.exclude([:a, :b]=>[[10, 20]].sql_array).all.should == [{:a=>20, :b=>10}]
    @ds.exclude([:a, :b]=>[[20, 10], [1, 2]].sql_array).all.should == []
    @ds.exclude([:a, :b]=>[[10, 10], [20, 20]].sql_array).all.should == [{:a=>20, :b=>10}]
  end

  it "should work with IN/NOT in with datasets" do
    @ds.insert(20, 10)
    ds = @ds.unordered
    @ds.quote_identifiers = false

    @ds.filter(:a=>ds.select(:a)).all.should == [{:a=>20, :b=>10}]
    @ds.filter(:a=>ds.select(:a).where(:a=>15)).all.should == []
    @ds.exclude(:a=>ds.select(:a)).all.should == []
    @ds.exclude(:a=>ds.select(:a).where(:a=>15)).all.should == [{:a=>20, :b=>10}]

    @ds.filter([:a, :b]=>ds.select(:a, :b)).all.should == [{:a=>20, :b=>10}]
    @ds.filter([:a, :b]=>ds.select(:b, :a)).all.should == []
    @ds.exclude([:a, :b]=>ds.select(:a, :b)).all.should == []
    @ds.exclude([:a, :b]=>ds.select(:b, :a)).all.should == [{:a=>20, :b=>10}]

    @ds.filter([:a, :b]=>ds.select(:a, :b).where(:a=>15)).all.should == []
    @ds.exclude([:a, :b]=>ds.select(:a, :b).where(:a=>15)).all.should == [{:a=>20, :b=>10}]
  end

  specify "should work empty arrays" do
    @ds.insert(20, 10)
    @ds.filter(:a=>[]).all.should == []
    @ds.exclude(:a=>[]).all.should == [{:a=>20, :b=>10}]
    @ds.filter([:a, :b]=>[]).all.should == []
    @ds.exclude([:a, :b]=>[]).all.should == [{:a=>20, :b=>10}]
  end
  
  specify "should work empty arrays with nulls" do
    @ds.insert(nil, nil)
    @ds.filter(:a=>[]).all.should == []
    @ds.exclude(:a=>[]).all.should == [{:a=>nil, :b=>nil}]
    @ds.filter([:a, :b]=>[]).all.should == []
    @ds.exclude([:a, :b]=>[]).all.should == [{:a=>nil, :b=>nil}]
  end
  
  it "should work multiple conditions" do
    @ds.insert(20, 10)
    @ds.filter(:a=>20, :b=>10).all.should == [{:a=>20, :b=>10}]
    @ds.filter([[:a, 20], [:b, 10]]).all.should == [{:a=>20, :b=>10}]
    @ds.filter({:a=>20} & {:b=>10}).all.should == [{:a=>20, :b=>10}]
    @ds.filter({:a=>20} | {:b=>5}).all.should == [{:a=>20, :b=>10}]
    @ds.filter(~{:a=>10}).all.should == [{:a=>20, :b=>10}]
  end
end

describe "SQL Extract Function" do
  before do
    @db = INTEGRATION_DB
    @db.create_table!(:a){DateTime :a}
    @ds = @db[:a].order(:a)
  end
  after do
    @db.drop_table(:a)
  end
  
  specify "should return the part of the datetime asked for" do
    t = Time.now
    def @ds.supports_timestamp_timezones?() false end
    @ds.insert(t)
    @ds.get{a.extract(:year)}.should == t.year
    @ds.get{a.extract(:month)}.should == t.month
    @ds.get{a.extract(:day)}.should == t.day
    @ds.get{a.extract(:hour)}.should == t.hour
    @ds.get{a.extract(:minute)}.should == t.min
    @ds.get{a.extract(:second)}.to_i.should == t.sec
  end
end

describe "Dataset string methods" do
  before(:all) do
    @db = INTEGRATION_DB
    @db.create_table!(:a){String :a; String :b}
    @ds = @db[:a].order(:a)
  end
  before do
    @ds.delete
  end
  after(:all) do
    @db.drop_table(:a)
  end
  
  it "#grep should return matching rows" do
    @ds.insert('foo', 'bar')
    @ds.grep(:a, 'foo').all.should == [{:a=>'foo', :b=>'bar'}]
    @ds.grep(:b, 'foo').all.should == []
    @ds.grep(:b, 'bar').all.should == [{:a=>'foo', :b=>'bar'}]
    @ds.grep(:a, 'bar').all.should == []
    @ds.grep([:a, :b], %w'foo bar').all.should == [{:a=>'foo', :b=>'bar'}]
    @ds.grep([:a, :b], %w'boo far').all.should == []
  end
  
  it "#grep should work with :all_patterns and :all_columns options" do
    @ds.insert('foo bar', ' ')
    @ds.insert('foo d', 'bar')
    @ds.insert('foo e', ' ')
    @ds.insert(' ', 'bar')
    @ds.insert('foo f', 'baz')
    @ds.insert('foo baz', 'bar baz')
    @ds.insert('foo boo', 'boo foo')

    @ds.grep([:a, :b], %w'%foo% %bar%', :all_patterns=>true).all.should == [{:a=>'foo bar', :b=>' '}, {:a=>'foo baz', :b=>'bar baz'}, {:a=>'foo d', :b=>'bar'}]
    @ds.grep([:a, :b], %w'%foo% %bar% %blob%', :all_patterns=>true).all.should == []

    @ds.grep([:a, :b], %w'%bar% %foo%', :all_columns=>true).all.should == [{:a=>"foo baz", :b=>"bar baz"}, {:a=>"foo boo", :b=>"boo foo"}, {:a=>"foo d", :b=>"bar"}]
    @ds.grep([:a, :b], %w'%baz%', :all_columns=>true).all.should == [{:a=>'foo baz', :b=>'bar baz'}]

    @ds.grep([:a, :b], %w'%baz% %foo%', :all_columns=>true, :all_patterns=>true).all.should == []
    @ds.grep([:a, :b], %w'%boo% %foo%', :all_columns=>true, :all_patterns=>true).all.should == [{:a=>'foo boo', :b=>'boo foo'}]
  end
  
  it "#like should return matching rows" do
    @ds.insert('foo', 'bar')
    @ds.filter(:a.like('foo')).all.should == [{:a=>'foo', :b=>'bar'}]
    @ds.filter(:a.like('bar')).all.should == []
    @ds.filter(:a.like('foo', 'bar')).all.should == [{:a=>'foo', :b=>'bar'}]
  end
  
  it "#ilike should return matching rows, in a case insensitive manner" do
    @ds.insert('foo', 'bar')
    @ds.filter(:a.ilike('Foo')).all.should == [{:a=>'foo', :b=>'bar'}]
    @ds.filter(:a.ilike('baR')).all.should == []
    @ds.filter(:a.ilike('FOO', 'BAR')).all.should == [{:a=>'foo', :b=>'bar'}]
  end
  
  it "should work with strings created with sql_string_join" do
    @ds.insert('foo', 'bar')
    @ds.get([:a, :b].sql_string_join).should == 'foobar'
    @ds.get([:a, :b].sql_string_join(' ')).should == 'foo bar'
  end
end

describe "Dataset identifier methods" do
  before(:all) do
    class ::String
      def uprev
        upcase.reverse
      end
    end
    @db = INTEGRATION_DB
    @db.create_table!(:a){Integer :ab}
    @db[:a].insert(1)
  end
  before do
    @ds = @db[:a].order(:ab)
  end
  after(:all) do
    @db.drop_table(:a)
  end
  
  cspecify "#identifier_output_method should change how identifiers are output", [:mysql2], [:swift] do
    @ds.identifier_output_method = :upcase
    @ds.first.should == {:AB=>1}
    @ds.identifier_output_method = :uprev
    @ds.first.should == {:BA=>1}
  end
  
  it "should work when not quoting identifiers" do
    @ds.quote_identifiers = false
    @ds.first.should == {:ab=>1}
  end
end

describe "Dataset defaults and overrides" do
  before(:all) do
    @db = INTEGRATION_DB
    @db.create_table!(:a){Integer :a}
    @ds = @db[:a].order(:a)
  end
  before do
    @ds.delete
  end
  after(:all) do
    @db.drop_table(:a)
  end
  
  it "#set_defaults should set defaults that can be overridden" do
    @ds = @ds.set_defaults(:a=>10)
    @ds.insert
    @ds.insert(:a=>20)
    @ds.all.should == [{:a=>10}, {:a=>20}]
  end
  
  it "#set_overrides should set defaults that cannot be overridden" do
    @ds = @ds.set_overrides(:a=>10)
    @ds.insert
    @ds.insert(:a=>20)
    @ds.all.should == [{:a=>10}, {:a=>10}]
  end
end

if INTEGRATION_DB.dataset.supports_modifying_joins?
  describe "Modifying joined datasets" do
    before do
      @db = INTEGRATION_DB
      @db.create_table!(:a){Integer :a; Integer :d}
      @db.create_table!(:b){Integer :b; Integer :e}
      @db.create_table!(:c){Integer :c; Integer :f}
      @ds = @db.from(:a, :b).join(:c, :c=>:e.identifier).where(:d=>:b, :f=>6)
      @db[:a].insert(1, 2)
      @db[:a].insert(3, 4)
      @db[:b].insert(2, 5)
      @db[:c].insert(5, 6)
      @db[:b].insert(4, 7)
      @db[:c].insert(7, 8)
    end
    after do
      @db.drop_table(:a, :b, :c)
    end
    
    it "#update should allow updating joined datasets" do
      @ds.update(:a=>10)
      @ds.all.should == [{:c=>5, :b=>2, :a=>10, :d=>2, :e=>5, :f=>6}]
      @db[:a].order(:a).all.should == [{:a=>3, :d=>4}, {:a=>10, :d=>2}]
      @db[:b].order(:b).all.should == [{:b=>2, :e=>5}, {:b=>4, :e=>7}]
      @db[:c].order(:c).all.should == [{:c=>5, :f=>6}, {:c=>7, :f=>8}]
    end
    
    it "#delete should allow deleting from joined datasets" do
      @ds.delete
      @ds.all.should == []
      @db[:a].order(:a).all.should == [{:a=>3, :d=>4}]
      @db[:b].order(:b).all.should == [{:b=>2, :e=>5}, {:b=>4, :e=>7}]
      @db[:c].order(:c).all.should == [{:c=>5, :f=>6}, {:c=>7, :f=>8}]
    end
  end
end
