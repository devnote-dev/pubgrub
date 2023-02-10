module PubGrub
  class StaticPackageSource < BasicPackageSource
    # TODO: merge into main class
    class DSL
      getter packages : Hash(String, Hash(String, String))
      getter root_deps : Hash(Int32, Package)

      def initialize(@packages, @root_deps)
      end

      def root(deps : Hash(String, String)) : Nil
        @root_deps.merge deps
      end

      def add(name : String, version : String, *, deps : Hash(String, String) = Hash(String, String).new) : Nil
        @packages[name] ||= {} of String => String
        raise ArgumentError.new("#{name} #{version} declared twice") if @packages[name].has_key? version
        # @packages[name][version] =
        clean_deps(name, version, deps)
      end

      private def clean_deps(name : String, version : String, deps : Hash(String, String))
        deps.reject do |key, _|
          key == name # && Shards.parse_range(value).includes?(version)
        end
      end
    end

    def initialize(& : DSL ->)
      @root_deps = {} of Int32 => Package
      @packages = Hash(String, Hash(String, String)).new

      yield DSL.new(@packages, @root_deps)

      super
    end

    def all_versions_for(package : Package) : Array(String)
      @packages[package].keys
    end

    def root_dependencies
      @root_deps
    end

    def dependencies_for(package : Package, version : String) : String
      @packages[package][version]
    end

    def parse_dependency(package : Package, dependency)
      return false unless @packages.has_key? package

      Shards.parse_constraint package, dependency
    end
  end
end
