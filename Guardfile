rspec_options = { cmd: "bundle exec rspec", all_on_start: false,
    all_after_pass: false }
guard "rspec", rspec_options do
    watch("spec/spec_helper.rb") { "spec" }
    watch(%r{^spec/.+_spec\.rb$}) { "spec" }
    watch(%r{^lib/.+\.rb$}) { "spec" }
end
