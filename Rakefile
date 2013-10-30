require 'bundler'
Bundler::GemHelper.install_tasks

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

task :default => "spec:all"

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  require 'sorted/version'

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "sorted #{Sorted::VERSION}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

namespace :spec do
  desc "Run Tests against all ORMs"
  task :all do
    %w(active_record_40 mongoid_30).each do |gemfile|
      sh "BUNDLE_GEMFILE='gemfiles/#{gemfile}.gemfile' bundle --quiet"
      sh "BUNDLE_GEMFILE='gemfiles/#{gemfile}.gemfile' bundle exec rake -t spec"
    end
  end
end
