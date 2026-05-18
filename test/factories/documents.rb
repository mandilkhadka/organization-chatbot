FactoryBot.define do
  factory :document do
    user
    sequence(:title) { |n| "Document #{n}" }
    sequence(:filename) { |n| "doc#{n}.txt" }
    content_type { "text/plain" }
    file_size { 1024 }
    status { :ready }

    trait :pending do
      status { :pending }
    end

    trait :failed do
      status { :failed }
      error_message { "Parser failed" }
    end
  end
end
