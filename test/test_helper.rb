ENV["RAILS_ENV"] ||= "test"

# Start SimpleCov before loading the app so it captures all files.
require "simplecov"
SimpleCov.start "rails" do
  add_filter "/test/"
  add_filter "/config/"
  add_filter "/db/"
  add_filter "/bin/"
  add_filter "/vendor/"

  add_group "Services", "app/services"
  add_group "Jobs", "app/jobs"
  add_group "Models", "app/models"
  add_group "Controllers", "app/controllers"

  # Fail the build if coverage drops below this baseline.
  # Bump it up as tests are added per PRD §5 Phase C.
  minimum_coverage 25
end

require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "webmock/minitest"
require "factory_bot_rails"

# Block any unstubbed outbound HTTP. Tests must stub Gemini etc.
WebMock.disable_net_connect!(allow_localhost: true)

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # SimpleCov needs each parallel worker to namespace its result file and
    # the parent process to merge them at exit.
    parallelize_setup do |worker|
      SimpleCov.command_name "test-worker-#{worker}"
    end

    parallelize_teardown do |_worker|
      SimpleCov.result
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # FactoryBot syntax: `create(:user)` instead of `FactoryBot.create(:user)`.
    include FactoryBot::Syntax::Methods
  end
end
