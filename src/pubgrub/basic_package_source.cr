module PubGrub
  abstract class BasicPackageSource
    getter root_package : Package
    getter root_version : Int32

    def initialize
      @root_package = Package::ROOT
      @root_version = Package::ROOT_VERSION
      @cached_versions = Hash(Package, Array(String)).new do |hash, key|
        if key == @root_package
          hash[key] = [@root_version.to_s]
        else
          hash[key] = all_versions_for key
        end
      end

      @sorted_versions = Hash(Package, Array(String)).new do |hash, key|
        hash[key] = @cached_versions[key].sort
      end

      @version_indexes = Hash(String, Hash(String, Int32)).new do |hash, key|
        hash[key] = @cached_versions[key].each.with_index.to_h
      end

      @cached_dependencies = Hash(Package, Hash(String, Package)).new do |hash, key|
        if key == @root_package
          hash[key] = root_dependencies
        else
          hash[key] = Hash(Int32, Package).new do |h, k|
            h[k] = dependencies_for key, k
          end
        end
      end
    end

    abstract def all_versions_for(package : Package) : Array(String)

    abstract def dependencies_for(package : Package, version : String) : String

    abstract def parse_dependency(package : Package, dependency)

    def root_dependencies
      dependencies_for @root_package, @root_version
    end

    def sort_versions_by_preferred(package : Package, sorted_versions)
      indexes = @version_indexes[package]
      sorted_versions.sort_by { |v| indexes[v] }
    end

    def versions_for(package : Package, range : VersionRange = VersionRange.any)
      versions = range.select_versions @sorted_versions[package]
      if versions.size > 1
        sort_versions_by_preferred package, versions
      else
        versions
      end
    end

    def no_versions_incompatibility_for(package : Package, unsatisfied : Term)
      cause = Incompatibility::NoVersions.new unsatisfied

      Incompatibility.new([unsatisfied], cause)
    end

    def incompatibilities_for(package : Package, version)
      package_deps = @cached_dependencies[package]
      sorted_versions = @sorted_versions[package]

      package_deps[version].map do |dep_package, constraint|
        low = high = sorted_versions.index(version)

        while low > 0 && package_deps[sorted_versions[low - 1]][dep_package] == constraint
          low -= 1
        end

        range_low = if low == 0
                      nil
                    else
                      sorted_versions[low]
                    end

        while high < sorted_versions.size && package_deps[sorted_versions[high]][dep_package] == constraint
          high += 1
        end

        range_high = if high == sorted_versions.size
                       nil
                     else
                       sorted_versions[high]
                     end

        range = VersionRange.new min: range_low, max: range_high, include_min: true
        self_constraint = VersionConstraint.new package, range

        dep_constraint = parse_dependency dep_package, constraint
        if !dep_constraint
          cause = Incompatibility::InvalidDependency.new dep_package, constraint
          return [Incompatibility.new(Term.new(self_constraint, true), cause)]
        elsif !dep_constraint.is_a?(VersionConstraint)
          dep_constraint = VersionConstraint.new dep_package, dep_constraint
        end

        Incompatibility.new([Term.new(self_constraint, true), Term.new(dep_constraint, false)], :dependency)
      end
    end
  end
end
