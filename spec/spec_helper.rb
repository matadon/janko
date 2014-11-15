root = File.join(File.dirname(File.expand_path(__FILE__)), "..")
$LOAD_PATH.unshift(root) unless $LOAD_PATH.include?(root)

require "simplecov"
require "config/environment"

SimpleCov.start do
    add_filter "/spec/"
    add_filter "/config/"
end

#
# http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
#
RSpec.configure do |config|
    config.filter_run(:focus)
    config.run_all_when_everything_filtered = true
    config.order = :random
    config.default_formatter = "doc" if config.files_to_run.one?
    Kernel.srand(config.seed)

    # config.profile_examples = 10

    config.expect_with :rspec do |expectations|
        expectations.syntax = :expect
    end

    config.mock_with :rspec do |mocks|
        mocks.syntax = :expect
        mocks.verify_partial_doubles = true
    end
end
