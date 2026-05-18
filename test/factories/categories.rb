FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Category #{n}" }
    description { "Test category" }
  end
end
