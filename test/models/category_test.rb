require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  def setup
    @category = categories(:general)
  end

  test "valid category" do
    category = Category.new(name: "Test Category")

    assert_predicate category, :valid?
  end

  test "requires name" do
    category = Category.new(name: nil)

    assert_not category.valid?
    assert_includes category.errors[:name], "can't be blank"
  end

  test "name must be unique" do
    category = Category.new(name: @category.name)

    assert_not category.valid?
    assert_includes category.errors[:name], "has already been taken"
  end

  test "name max length is 100" do
    category = Category.new(name: "a" * 101)

    assert_not category.valid?
    assert_includes category.errors[:name], "is too long (maximum is 100 characters)"
  end

  test "description max length is 500" do
    category = Category.new(name: "Test", description: "a" * 501)

    assert_not category.valid?
    assert_includes category.errors[:description], "is too long (maximum is 500 characters)"
  end

  test "alphabetical scope orders by name" do
    categories = Category.alphabetical

    assert_equal categories.first.name, Category.order(name: :asc).first.name
  end

  test "has_many documents association with dependent nullify" do
    # Test that the association is configured correctly
    association = Category.reflect_on_association(:documents)

    assert_equal :has_many, association.macro
    assert_equal :nullify, association.options[:dependent]
  end
end
