FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "Passw0rd!Passw0rd!" } # satisfies the strong-password validator
    password_confirmation { password }
    role { :employee }

    trait :admin do
      role { :admin }
    end

    trait :locked do
      after(:create) do |user|
        user.update_column(:locked_at, Time.current)
      end
    end
  end
end
