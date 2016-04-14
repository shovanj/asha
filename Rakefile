require "bundler/gem_tasks"
require "rake/testtask"

namespace :test do
  Rake::TestTask.new(:all) do |t|
    t.libs = %w(lib test)
    t.pattern = "test/**/*_test.rb"
  end
  %w(helpers).each do |name|
    Rake::TestTask.new(name) do |t|
      t.libs = %W(lib/#{ name } test test/#{ name })
      t.pattern = "test/#{ name }/**/*_test.rb"
    end
  end
end
task test: ["test:all"]
task default: "test"
