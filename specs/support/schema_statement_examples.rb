require 'spec_helper'

shared_examples_for "an adapter" do |adapter|
  shared_base = Class.new do
    extend Spectacles::SchemaStatements.const_get(adapter)
    def self.quote_table_name(name); name; end
    def self.quote_column_name(name); name; end
    def self.execute(query); query; end 
  end

  describe "ActiveRecord::SchemaDumper#dump" do 
    before(:each) do
      ActiveRecord::Base.connection.drop_view(:new_product_users)

      ActiveRecord::Base.connection.create_view(:new_product_users) do 
        "SELECT name AS product_name, first_name AS username FROM
        products JOIN users ON users.id = products.user_id"
      end

      if ActiveRecord::Base.connection.supports_materialized_views?
        ActiveRecord::Base.connection.create_materialized_view(:materialized_product_users, force: true) do 
          "SELECT name AS product_name, first_name AS username FROM
          products JOIN users ON users.id = products.user_id"
        end

        ActiveRecord::Base.connection.create_materialized_view(:empty_materialized_product_users, storage: { fillfactor: 50 }, data: false, force: true) do 
          "SELECT name AS product_name, first_name AS username FROM
          products JOIN users ON users.id = products.user_id"
        end
      end
    end

    it "should return create_view in dump stream" do 
      stream = StringIO.new
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
      stream.string.must_match(/create_view/)
    end

    if ActiveRecord::Base.connection.supports_materialized_views?
      it "should return create_materialized_view in dump stream" do 
        stream = StringIO.new
        ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
        stream.string.must_match(/create_materialized_view/)
      end

      it "should include options for create_materialized_view" do
        stream = StringIO.new
        ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
        stream.string.must_match(/create_materialized_view.*fillfactor: 50/)
        stream.string.must_match(/create_materialized_view.*data: false/)
      end
    end

    it "should rebuild views in dump stream" do 
      stream = StringIO.new
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)

      if ActiveRecord::Base.connection.supports_materialized_views?
        ActiveRecord::Base.connection.materialized_views.each do |view|
          ActiveRecord::Base.connection.drop_materialized_view(view)
        end
      end

      ActiveRecord::Base.connection.views.each do |view|
        ActiveRecord::Base.connection.drop_view(view)
      end

      ActiveRecord::Base.connection.tables.each do |table|
        ActiveRecord::Base.connection.drop_table(table)
      end

      eval(stream.string)

      ActiveRecord::Base.connection.views.must_include('new_product_users')

      if ActiveRecord::Base.connection.supports_materialized_views?
        ActiveRecord::Base.connection.materialized_views.must_include('materialized_product_users')
      end
    end
  end

  describe "#create_view" do
    let(:view_name) { :view_name }

    it "throws error when block not given and no build_query" do 
      lambda { shared_base.create_view(view_name) }.must_raise(RuntimeError)
    end

    describe "view_name" do
      it "takes a symbol as the view_name" do 
        shared_base.create_view(view_name.to_sym, Product.all).must_match(/#{view_name}/)
      end

      it "takes a string as the view_name" do 
        shared_base.create_view(view_name.to_s, Product.all).must_match(/#{view_name}/)
      end
    end

    describe "build_query" do 
      it "uses a string if passed" do 
        select_statement = "SELECT * FROM products"
        shared_base.create_view(view_name, select_statement).must_match(/#{Regexp.escape(select_statement)}/)
      end

      it "uses an Arel::Relation if passed" do 
        select_statement = Product.all.to_sql
        shared_base.create_view(view_name, Product.all).must_match(/#{Regexp.escape(select_statement)}/)
      end
    end

    describe "block" do 
      it "can use an Arel::Relation from the yield" do 
        select_statement = Product.all.to_sql
        shared_base.create_view(view_name) { Product.all }.must_match(/#{Regexp.escape(select_statement)}/)
      end

      it "can use a String from the yield" do 
        select_statement = "SELECT * FROM products"
        shared_base.create_view(view_name) { "SELECT * FROM products" }.must_match(/#{Regexp.escape(select_statement)}/)
      end
    end
  end

  describe "#drop_view" do
    let(:view_name) { :view_name }

    describe "view_name" do
      it "takes a symbol as the view_name" do 
        shared_base.drop_view(view_name.to_sym).must_match(/#{view_name}/)
      end

      it "takes a string as the view_name" do 
        shared_base.drop_view(view_name.to_s).must_match(/#{view_name}/)
      end
    end
  end

  if shared_base.supports_materialized_views?
    describe "#create_materialized_view" do
      let(:view_name) { :view_name }

      it "throws error when block not given and no build_query" do
        lambda { shared_base.create_materialized_view(view_name) }.must_raise(RuntimeError)
      end

      describe "view_name" do
        it "takes a symbol as the view_name" do
          shared_base.create_materialized_view(view_name.to_sym, Product.all).must_match(/#{view_name}/)
        end

        it "takes a string as the view_name" do
          shared_base.create_materialized_view(view_name.to_s, Product.all).must_match(/#{view_name}/)
        end
      end

      describe "build_query" do
        it "uses a string if passed" do
          select_statement = "SELECT * FROM products"
          shared_base.create_materialized_view(view_name, select_statement).must_match(/#{Regexp.escape(select_statement)}/)
        end

        it "uses an Arel::Relation if passed" do
          select_statement = Product.all.to_sql
          shared_base.create_materialized_view(view_name, Product.all).must_match(/#{Regexp.escape(select_statement)}/)
        end
      end

      describe "block" do
        it "can use an Arel::Relation from the yield" do
          select_statement = Product.all.to_sql
          shared_base.create_materialized_view(view_name) { Product.all }.must_match(/#{Regexp.escape(select_statement)}/)
        end

        it "can use a String from the yield" do
          select_statement = "SELECT * FROM products"
          shared_base.create_materialized_view(view_name) { "SELECT * FROM products" }.must_match(/#{Regexp.escape(select_statement)}/)
        end
      end
    end

    describe "#drop_materialized_view" do
      let(:view_name) { :view_name }

      describe "view_name" do
        it "takes a symbol as the view_name" do
          shared_base.drop_materialized_view(view_name.to_sym).must_match(/#{view_name}/)
        end

        it "takes a string as the view_name" do
          shared_base.drop_materialized_view(view_name.to_s).must_match(/#{view_name}/)
        end
      end
    end

    describe "#refresh_materialized_view" do
      let(:view_name) { :view_name }

      describe "view_name" do
        it "takes a symbol as the view_name" do
          shared_base.refresh_materialized_view(view_name.to_sym).must_match(/#{view_name}/)
        end

        it "takes a string as the view_name" do
          shared_base.refresh_materialized_view(view_name.to_s).must_match(/#{view_name}/)
        end
      end
    end
  else
    describe "#materialized_views" do
      it "should not be supported by #{adapter}" do
        lambda { shared_base.materialized_views }.must_raise(NotImplementedError)
      end
    end
  end
end
