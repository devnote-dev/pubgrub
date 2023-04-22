module PubGrub
  abstract class PackageSource
    abstract def root : Hash(String, String)
    abstract def packages : Hash(String, Hash(String, Hash(String, String)))
    abstract def all_versions_for(package : Package) : Array(String)
    abstract def dependencies_for(package : Package, version : String) : Hash(String, String)
    abstract def parse_dependency(package : Package, dependency) : Version

    def root_dependencies : Hash(Package, String)
      dependencies_for(BasicPackage.new("root", 0), 0)
    end

    def sort_versions_by_preferred(package : Package, sorted_versions : Array(Version)) : Array(Version)
      indexes = version_indexes[package]
      sorted_versions.sort_by { |v| indexes[v] }
    end

    def root(dependencies : Hash(String, String)) : Nil
      @root.merge! dependencies
    end

    def root(name : String, version : String) : Nil
      @root[name] = version
    end

    def add(name : String, version : String, dependencies : Hash(String, String)? = nil) : Nil
      if package = @packages[name]?
        raise ArgumentError.new "#{name} #{version} declared twice" if package.has_key? version
      end

      @packages[name] ||= Hash(String, Hash(String, String)).new
      if deps = dependencies
        @packages[name][version] = deps.reject do |dep, _|
          name == dep # && parse_range(req).includes?(version)
        end
      end
    end
  end

  class StaticPackageSource < PackageSource
    getter root : Hash(String, String)
    getter packages : Hash(String, Hash(String, Hash(String, String)))

    def initialize(& : self ->)
      @root = {} of String => String
      @packages = Hash(String, Hash(String, Hash(String, String))).new

      yield self
    end

    def all_versions_for(package : Package) : Array(String)
      @packages[package.name].keys
    end

    def dependencies_for(package : Package, version : String) : Hash(String, String)
      @packages[package.name][version]
    end

    def parse_dependency(package : Package, dependency) : Version
      Version::Constraint.new SemanticVersion.parse(dependency)
    end
  end
end
