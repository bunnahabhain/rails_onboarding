require "test_helper"

module RailsOnboarding
  # The host model can be loaded before its table exists, and that is not an
  # edge case: an initializer that references the user model (OmniAuth's
  # :identity provider takes `model:`) loads it during boot, so `db:prepare`
  # against a genuinely new database would boot, query columns_hash, and die on
  # the very table it was about to create.
  class OnboardableMissingTableTest < ActiveSupport::TestCase
    def missing_table_model
      Class.new(ActiveRecord::Base) do
        self.table_name = "onboardable_absent_table"

        def self.name
          "OnboardableAbsentTableUser"
        end
      end
    end

    test "columns_queryable? is false when the table does not exist" do
      refute RailsOnboarding::SchemaGuard.columns_queryable?(missing_table_model)
    end

    test "columns_queryable? is true for a model whose table exists" do
      assert RailsOnboarding::SchemaGuard.columns_queryable?(User)
    end

    # The concern is includable into plain classes that are not ActiveRecord
    # models. They answer columns_hash but not table_exists?, and must keep
    # being configured exactly as they were before this guard existed.
    test "columns_queryable? is true for a class that is not an AR model" do
      double = Class.new do
        def self.columns_hash = {}
      end

      assert RailsOnboarding::SchemaGuard.columns_queryable?(double)
    end

    test "including the concern does not raise when the table is absent" do
      klass = missing_table_model

      assert_nothing_raised do
        klass.include(RailsOnboarding::Onboardable)
      end
    end

    # Onboardable was not the only concern doing this. ProgressiveDisclosure and
    # AbTestable inspect columns at include time too, and a host that includes
    # them alongside Onboardable still could not boot. Guarding only the first
    # one found fixed nothing for such a host.
    test "every concern that inspects columns can be included without the table" do
      [
        RailsOnboarding::Onboardable,
        RailsOnboarding::ProgressiveDisclosure,
        RailsOnboarding::AbTestable
      ].each do |concern|
        klass = missing_table_model

        # assert_nothing_raised takes no message here, so name the concern by
        # letting the raise propagate with its own backtrace.
        assert_nothing_raised do
          klass.include(concern)
        end
      end
    end

    test "the concerns can all be included together without the table" do
      klass = missing_table_model

      assert_nothing_raised do
        klass.include(RailsOnboarding::Onboardable)
        klass.include(RailsOnboarding::ProgressiveDisclosure)
        klass.include(RailsOnboarding::AbTestable)
      end
    end

    # There is deliberately no "onboarding_column? with a missing table" test:
    # it cannot be written. ActiveRecord cannot instantiate a model whose table
    # is absent -- `klass.new` raises inside _has_attribute? while building the
    # attribute types -- so the method is unreachable in that state and its
    # guard can never fire. It is kept for symmetry with the class-level
    # callers, and this test only pins that guarding it did not change what it
    # answers when the table is there.
    test "onboarding_column? still answers for a real column" do
      assert User.new.send(:onboarding_column?, "onboarding_completed")
      refute User.new.send(:onboarding_column?, "no_such_column_here")
    end

    test "onboarding_replay_supported? is false when the table is absent" do
      klass = missing_table_model
      klass.include(RailsOnboarding::Onboardable)

      refute klass.onboarding_replay_supported?
    end

    # The guard must not cost anything once the schema is in place: a host with
    # text columns still gets JSON serialization configured.
    test "serialization is still configured when the table exists" do
      skip "host model has no text feature_tooltips_shown column" unless
        User.columns_hash["feature_tooltips_shown"]&.type == :text

      assert_kind_of ActiveRecord::Type::Serialized,
        User.type_for_attribute("feature_tooltips_shown")
    end
  end
end
