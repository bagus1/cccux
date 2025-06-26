require_relative "lib/cccux/version"

Gem::Specification.new do |spec|
  spec.name        = "cccux"
  spec.version     = Cccux::VERSION
  spec.authors     = ["John"]
  spec.email       = ["john@example.com"]
  spec.homepage    = "https://github.com/username/cccux"
  spec.summary     = "CanCanCan UX - Admin interface and user experience enhancements for CanCanCan authorization"
  spec.description = "CCCUX provides a comprehensive admin interface and user experience layer for CanCanCan authorization. It includes role-based access control (RBAC) models, admin controllers for managing users, roles, and permissions, and a clean interface for authorization management."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/username/cccux"
  spec.metadata["changelog_uri"] = "https://github.com/username/cccux/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.1.5.1"
  spec.add_dependency "cancancan", "~> 3.0"
  
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "rspec-rails"
end
