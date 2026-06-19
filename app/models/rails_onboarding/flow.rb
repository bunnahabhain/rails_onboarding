module RailsOnboarding
  class Flow < ApplicationRecord
    self.table_name = "rails_onboarding_flows"

    serialize :steps, coder: JSON

    validates :name, presence: true

    scope :active, -> { where(active: true) }

    # Hash-style reader so views written against the old session-hash flows
    # (flow[:name], flow[:steps], ...) keep working against this AR-backed model.
    def [](key)
      public_send(key)
    end

    # JSON round-trips a saved flow's steps back with string keys, but every
    # view reads them with symbols (step[:icon], step[:title], ...). Normalize
    # on read so it doesn't matter whether a step hash was just assigned in
    # memory or came back from the database.
    def steps
      Array(super).map { |step| step.is_a?(Hash) ? step.with_indifferent_access : step }
    end

    def self.seed_default!
      create!(
        name: 'Current Configuration',
        description: 'Flow from current configuration',
        steps: RailsOnboarding.configuration.steps,
        active: true
      )
    end

    def self.activate!(flow)
      transaction do
        where.not(id: flow.id).update_all(active: false)
        flow.update!(active: true)
      end
    end
  end
end
