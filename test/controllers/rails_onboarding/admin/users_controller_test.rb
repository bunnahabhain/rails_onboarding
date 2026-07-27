# frozen_string_literal: true

require "test_helper"

module RailsOnboarding
  module Admin
    class UsersControllerTest < ActionDispatch::IntegrationTest
      include Engine.routes.url_helpers

      def setup
        @admin_user = User.create!(email: "admin@example.com")
        @test_user = User.create!(
          email: "test@example.com",
          onboarding_current_step: "welcome",
          onboarding_completed: false
        )
        sign_in @admin_user
      end

      test "should list users" do
        get admin_users_path
        assert_response :success
      end

      test "non-admin cannot list users" do
        sign_out
        sign_in User.create!(email: "regular@example.com")

        get admin_users_path
        assert_redirected_to "/"
      end

      test "should show user details" do
        get admin_user_path(@test_user)
        assert_response :success
      end

      # Users predating the gem's install can carry NULL timestamps, which used
      # to raise NoMethodError on nil in the view's strftime calls and bounce
      # the admin back to the dashboard.
      test "should show user details when timestamps are NULL" do
        @test_user.update_columns(created_at: nil, updated_at: nil)

        get admin_user_path(@test_user)

        assert_response :success
        assert_select "dd", text: "N/A", count: 2
      end

      test "should reset user onboarding" do
        @test_user.update!(onboarding_completed: true, onboarding_completed_at: Time.current)

        post reset_onboarding_admin_user_path(@test_user)

        assert_redirected_to admin_user_path(@test_user)
        assert_not @test_user.reload.onboarding_completed
      end

      test "should complete user onboarding" do
        post complete_onboarding_admin_user_path(@test_user)

        assert_redirected_to admin_user_path(@test_user)
        assert @test_user.reload.onboarding_completed
      end

      test "should restart user onboarding" do
        @test_user.update!(onboarding_completed: true, onboarding_skipped: true, onboarding_completed_at: Time.current)

        post restart_onboarding_admin_user_path(@test_user)

        assert_redirected_to admin_user_path(@test_user)
        @test_user.reload
        assert_not @test_user.onboarding_completed
        assert_not @test_user.onboarding_skipped
        assert_not_nil @test_user.onboarding_current_step
      end

      test "should filter users by status" do
        completed_user = User.create!(email: "completed@example.com", onboarding_completed: true)

        get admin_users_path(status: "completed")

        assert_response :success
        assert_includes response.body, completed_user.email
        assert_not_includes response.body, @test_user.email
      end

      test "should search users" do
        get admin_users_path(search: @test_user.email)

        assert_response :success
        assert_includes response.body, @test_user.email
      end

      test "should search users by id" do
        get admin_users_path(search: @test_user.id.to_s)

        assert_response :success
        assert_includes response.body, @test_user.email
      end

      # A non-numeric term used to be cast against the id column too. That
      # clause could never match - ids are digits - and the cast target it used
      # (TEXT) is a syntax error on MySQL, so every search 500'd there.
      test "should not cast the id column for a non-numeric search" do
        other = User.create!(email: "unrelated@example.com")

        assert_no_match(/CAST/i, capture_search_sql("david"))

        get admin_users_path(search: "test@")
        assert_response :success
        assert_includes response.body, @test_user.email
        assert_not_includes response.body, other.email
      end

      test "should cast the id column only for a numeric search" do
        assert_match(/CAST/i, capture_search_sql("35"))
      end

      test "id cast type follows the adapter" do
        assert_equal "CHAR", UsersController.id_cast_type_for("Mysql2")
        assert_equal "CHAR", UsersController.id_cast_type_for("Trilogy")
        assert_equal "TEXT", UsersController.id_cast_type_for("PostgreSQL")
        assert_equal "TEXT", UsersController.id_cast_type_for("SQLite")
      end

      # With `encrypts :email` the column holds ciphertext, so a substring LIKE
      # can't match the plaintext - and it *can* match ciphertext that happens
      # to contain the term, which surfaces as confident nonsense. Deterministic
      # encryption still supports exact equality, so that's what we fall back to.
      test "deterministically encrypted email searches by equality, not LIKE" do
        sql = with_encrypted_email(deterministic: true) { capture_search_sql("dave@example.com") }

        assert_no_match(/email LIKE/i, sql)
        assert_match(/email. = /i, sql)
      end

      test "non-deterministically encrypted email is not searched at all" do
        sql = with_encrypted_email(deterministic: false) { capture_search_sql("dave@example.com") }

        assert_no_match(/email/i, sql)
      end

      # The id half must survive either way - it isn't encrypted.
      test "encrypted email still allows searching by id" do
        with_encrypted_email(deterministic: false) do
          get admin_users_path(search: @test_user.id.to_s)
        end

        assert_response :success
        assert_includes response.body, @test_user.email
      end

      # Guards the no-email-column branch: with nothing left to match on, an
      # empty WHERE would return every user rather than none.
      test "search returns nothing when the user model has no email column" do
        without_email_column do
          get admin_users_path(search: "david")
        end

        assert_response :success
        assert_not_includes response.body, @test_user.email
      end


      test "should paginate users beyond the first page" do
        # setup already created 2 users; top up to 3 full pages worth.
        page_size = UsersController::DEFAULT_PER_PAGE
        (page_size * 3 - User.count).times do |i|
          User.create!(email: "paginated#{i}@example.com")
        end

        get admin_users_path
        assert_response :success
        assert_select 'nav.series-nav a[aria-current="page"]', text: "1"
        assert_select 'nav.series-nav a[href*="page=2"]'

        first_page_ids = User.order(created_at: :desc).limit(page_size).pluck(:id)
        second_page_ids = User.order(created_at: :desc).offset(page_size).limit(page_size).pluck(:id)

        get admin_users_path(page: 2)
        assert_response :success
        assert_select 'nav.series-nav a[aria-current="page"]', text: "2"
        second_page_ids.each { |id| assert_select "tbody td", text: id.to_s }
        first_page_ids.each { |id| assert_select "tbody td", text: id.to_s, count: 0 }
      end

      test "pagination links preserve the active filters" do
        (UsersController::DEFAULT_PER_PAGE + 1).times do |i|
          User.create!(email: "filtered#{i}@example.com", onboarding_completed: true)
        end

        get admin_users_path(status: "completed")

        assert_response :success
        assert_select 'nav.series-nav a[href*="status=completed"]'
      end

      test "honours per_page but caps it at MAX_PER_PAGE" do
        (UsersController::MAX_PER_PAGE + 5 - User.count).times do |i|
          User.create!(email: "capped#{i}@example.com")
        end

        get admin_users_path(per_page: 5)
        assert_response :success
        assert_select "tbody tr", 5

        get admin_users_path(per_page: 1_000)
        assert_response :success
        assert_select "tbody tr", UsersController::MAX_PER_PAGE
      end

      test "should export users as csv" do
        get export_admin_users_path(format: :csv)

        assert_response :success
        assert_equal "text/csv", response.media_type
        assert_match(/attachment/, response.headers["Content-Disposition"])
        assert_match(/onboarding_users_#{Date.current}\.csv/, response.headers["Content-Disposition"])

        rows = CSV.parse(response.body, headers: true)
        assert_equal %w[ID Email Status], rows.headers.first(3)
        assert_includes rows.map { |r| r["Email"] }, @test_user.email
        assert_equal "In Progress", rows.find { |r| r["Email"] == @test_user.email }["Status"]
      end

      test "csv export works without an explicit format" do
        get export_admin_users_path

        assert_response :success
        assert_equal "text/csv", response.media_type
      end

      test "csv export covers every match, not just the first page" do
        page_size = BaseController::DEFAULT_PER_PAGE
        (page_size + 5 - User.count).times { |i| User.create!(email: "export#{i}@example.com") }

        get export_admin_users_path(format: :csv)

        assert_response :success
        assert_equal User.count, CSV.parse(response.body, headers: true).size
      end

      test "csv export honours the active filters" do
        completed = User.create!(email: "done@example.com", onboarding_completed: true)

        get export_admin_users_path(format: :csv, status: "completed")

        assert_response :success
        emails = CSV.parse(response.body, headers: true).map { |r| r["Email"] }
        assert_includes emails, completed.email
        assert_not_includes emails, @test_user.email
      end

      test "csv export reports each onboarding status" do
        User.create!(email: "done@example.com", onboarding_completed: true)
        User.create!(email: "skipped@example.com", onboarding_skipped: true)
        User.create!(email: "fresh@example.com")

        get export_admin_users_path(format: :csv)

        rows = CSV.parse(response.body, headers: true).to_h { |r| [ r["Email"], r["Status"] ] }
        assert_equal "Completed", rows["done@example.com"]
        assert_equal "Skipped", rows["skipped@example.com"]
        assert_equal "Not Started", rows["fresh@example.com"]
        assert_equal "In Progress", rows[@test_user.email]
      end

      test "the export link carries the filters currently in effect" do
        get admin_users_path(status: "completed", search: "example")

        assert_response :success
        assert_select "a[href*='users/export.csv']" do |links|
          href = links.first["href"]
          assert_includes href, "status=completed"
          assert_includes href, "search=example"
          # Paging is not a property of the export.
          assert_not_includes href, "page="
        end
      end

      test "renders the empty state without pagination when no users match" do
        get admin_users_path(search: "nobody-matches-this")

        assert_response :success
        assert_select ".admin-table-empty"
        assert_select "nav.series-nav", count: 0
      end

      private

      # Returns the users-table SQL issued while running a search, so a test
      # can assert on the shape of the query rather than only its results -
      # the adapter-specific half of this can't be exercised on SQLite.
      # Makes the controller believe the user model has no email column, which
      # is a configuration the gem supports. Hand-rolled rather than stubbed:
      # Minitest 6 dropped minitest/mock, and this isn't worth a new dependency.
      def without_email_column
        visible = User.column_names - [ "email" ]
        User.define_singleton_method(:column_names) { visible }
        yield
      ensure
        User.singleton_class.send(:remove_method, :column_names)
      end

      # Makes the controller see email as an encrypted attribute without
      # actually encrypting the dummy app's column - the controller only asks
      # `encrypted_attributes` and the attribute type whether it is, and
      # encrypting for real would mean a key setup and a rewritten fixture set
      # for no extra coverage of the branch under test.
      def with_encrypted_email(deterministic:)
        # A copy of the real attribute type with `deterministic?` bolted on,
        # rather than a bare double: `where(email: ...)` drives the full
        # ActiveModel::Type interface, so a stand-in has to behave like one.
        type = User.type_for_attribute("email").dup
        type.define_singleton_method(:deterministic?) { deterministic }

        User.define_singleton_method(:encrypted_attributes) { Set[:email] }
        User.define_singleton_method(:type_for_attribute) { |name, &b| name.to_s == "email" ? type : super(name, &b) }
        yield
      ensure
        User.singleton_class.send(:remove_method, :encrypted_attributes)
        User.singleton_class.send(:remove_method, :type_for_attribute)
      end

      def capture_search_sql(term)
        statements = []
        subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
          statements << payload[:sql]
        end
        get admin_users_path(search: term)
        statements.grep(/FROM .users./i).join("\n")
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end
    end
  end
end
