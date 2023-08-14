module PubGrub
  class StaticSource
    include PackageSource

    @packages : Hash(String, Hash(Version, Hash(String, String)))

    def self.new(& : self ->) : self
      with (this = new) yield this
      this
    end

    def initialize
      @packages = Hash(String, Hash(Version, Hash(String, String))).new do |hash, key|
        hash[key] = Hash(Version, Hash(String, String)).new do |h, k|
          h[k] = {} of String => String
        end
      end
    end

    def add(name : String, version : String, dependencies : Hash(String, String)? = nil) : Nil
      version = Version.parse version
      if @packages[name].has_key? version
        raise ArgumentError.new "#{name} #{version} declared twice"
      end

      @packages[name][version] = dependencies || {} of String => String
    end

    def versions_for(package : Package, constraint : Version::Constraint) : Array(Version)
      @packages[package.name].keys
    end

    def dependencies_for(package : Package, version : Version) : Hash(String, String)
      @packages[package.name][version]
    end

    def incompatibilities_for(package : Package, version : Version) : Array(Incompatibility)
      dependencies = dependencies_for package, version
      package_constraint = Version::Constraint.new package, Version::Range.new(version, version, true, true)
      incomps = [] of Incompatibility

      dependencies.each do |dep|
        constraint = convert dep
        unless constraint.is_a? Version::Constraint
          constraint = Version::Constraint.new package, constraint
        end

        incomps << Incompatibility.new(
          [Term.new(package_constraint, true), Term.new(constraint, false)],
          Cause::Dependency
        )
      end

      incomps
    end

    private def convert(dependency : Hash(String, String)) : Version
      # TODO
      raise NotImplementedError.new
    end
  end
end
