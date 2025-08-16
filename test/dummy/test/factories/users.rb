FactoryBot.define do
  factory :user do
    email { "MyString" }
    onboarding_completed { false }
    onboarding_completed_at { "2025-08-15 13:29:01" }
    onboarding_current_step { "MyString" }
    onboarding_skipped { false }
    feature_tooltips_shown { "MyText" }
    milestones_achieved { "MyText" }
    milestone_points { 1 }
    last_milestone_at { "2025-08-15 13:29:01" }
  end
end
