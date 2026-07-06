# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [ File.expand_path("../test/dummy/db/migrate", __dir__) ]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "rails/test_help"

# turbo-rails is a development-only dependency in the gemspec, so
# Bundler.require(*Rails.groups) never loads it in the test environment -
# Turbo/Stimulus stay undefined and :turbo_stream is never registered as a
# Mime::Type here, unlike in any real host app that actually depends on
# turbo-rails. Without this, every respond_to block with format.turbo_stream
# anywhere in the engine raises NoMethodError ("register it as a MIME type
# first") the moment it's exercised - silently masked in most existing tests
# because the rescue_from StandardError fallback happens to redirect to the
# same URL the success path does, so weak assertions can't tell the two apart.
unless Mime::Type.lookup_by_extension(:turbo_stream)
  Mime::Type.register "text/vnd.turbo-stream.html", :turbo_stream
end

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [ File.expand_path("fixtures", __dir__) ]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path = File.expand_path("fixtures", __dir__) + "/files"
  ActiveSupport::TestCase.fixtures :all
end

# Authentication helper for tests
module AuthenticationTestHelper
  def sign_in(user)
    get "/test_auth/login?user_id=#{user.id}"
  end

  def sign_out
    get "/test_auth/logout"
  end
end

class ActionDispatch::IntegrationTest
  include AuthenticationTestHelper
end
