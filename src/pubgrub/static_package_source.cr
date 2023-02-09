module PubGrub
  class StaticPackageSource < BasicPackageSource
    class DSL
      getter packages : Array(Package)
      getter root_deps

      def initialize(@packages : Array(Package), @root_deps)
      end

      def root(deps)
        @root_deps.update deps
      end

      def add(name, version, deps)
        @packages[name] ||= {} of _ => _
        raise ArgumentError.new("#{name} #{version} declared twice") if @packages[name].has_key? version
        @packages[name][version] = clean_deps(name, version, deps)
      end

      private def clean_deps(name, version, deps)
        deps.reject do |key, _|
          key == name # && Shards.parse_range(value).includes?(version)
        end
      end
    end
  end
end
