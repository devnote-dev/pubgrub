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

    def versions_for(package : Package, constraint : VersionConstraint) : Array(Version)
      @packages[package.name].keys
    end

    def dependencies_for(package : Package, version : VersionConstraint) : Hash(String, String)
      @packages[package.name][version]
    end

    def incompatibilities_for(package : Package, version : VersionConstraint) : Array(Incompatibility)
      dependencies = dependencies_for package, version
      package_constraint = Constraint.new package, Range.new(min: version, max: version, include_min: true, include_max: true)
      incomps = [] of Incompatibility

      dependencies.each do |_, dep|
        constraint = convert dep
        unless constraint.is_a? VersionConstraint
          constraint = Constraint.new package, constraint
        end

        incomps << Incompatibility.new(
          [Term.new(package_constraint, true), Term.new(constraint, false)],
          Cause::Dependency.new(package_constraint.package, constraint.package)
        )
      end

      incomps
    end

    def root(dependencies : Hash(String, String)) : Nil
      @packages["root"][Version.parse("0.0.0")] = dependencies
    end

    private def convert(dependency : String) : Version
      # TODO
      raise NotImplementedError.new "StaticSource#convert"
    end
  end
end
