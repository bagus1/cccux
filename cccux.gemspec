require_relative "lib/cccux/version"

Gem::Specification.new do |spec|
  spec.name        = "cccux"
  spec.version     = Cccux::VERSION
  spec.authors     = ["John"]
  spec.email       = ["bagus@bagus.org"]  # Update this with your real email
  spec.homepage    = "https://github.com/bagus1/cccux"  # Update with your GitHub username
  spec.summary     = "CanCanCan UX - Admin interface and user experience enhancements for CanCanCan authorization"
  spec.description = "CCCUX provides a comprehensive admin interface and user experience layer for CanCanCan authorization. It includes role-based access control (RBAC) models, admin controllers for managing users, roles, and permissions, and a clean interface for authorization management."
  spec.license     = "MIT"

  # Specify minimum Ruby version
  spec.required_ruby_version = ">= 3.0.0"

  # Remove the restriction for publishing to RubyGems
  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bagus1/cccux"
  spec.metadata["changelog_uri"] = "https://github.com/bagus1/cccux/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://github.com/bagus1/cccux/blob/main/README.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/bagus1/cccux/issues"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md", "CHANGELOG.md"]
  end

  # Runtime dependencies with proper version constraints
  spec.add_dependency "rails", ">= 7.1.5.1", "< 9.0"
  spec.add_dependency "cancancan", "~> 3.0"
  spec.add_dependency "zeitwerk", "~> 2.6"
  
  # Development dependencies with proper version constraints
  spec.add_development_dependency "sqlite3", "~> 1.4"
end
