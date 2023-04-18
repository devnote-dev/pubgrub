module PubGrub
  abstract class PackageSource
    abstract def root : Hash(String, String)
    abstract def packages : Hash(String, Hash(String, Hash(String, String)))

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
  end
end
