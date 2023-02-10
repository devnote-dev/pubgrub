module PubGrub
  class VersionConstraint
    getter package : Package
    getter range : VersionRange

    def_equals @package, @range

    def initialize(@package : Package, @range : VersionRange)
    end

    def exact(package : Package, version : Int32) : VersionConstraint
      range = VersionRange.new(min: version, max: version, include_min: true, include_max: true)

      new package, range
    end

    def any(package : Package) : VersionConstraint
      new package, VersionRange.any
    end

    def empty(package : Package) : VersionConstraint
      new package, VersionRange.empty
    end

    def intersect(other : VersionConstraint) : VersionConstraint
      unless @package == other.package
        raise ArgumentError.new "Can only intersect between version constraints of the same package"
      end

      new @package, @range.intersect(other.range)
    end

    def union(other : VersionConstraint) : VersionConstraint
      unless @package == other.package
        raise ArgumentError.new "Can only union between version constraints of the same package"
      end

      new @package, @range.union(other.range)
    end

    def invert : VersionConstraint
      new @package, range.invert
    end

    def difference(other : VersionConstraint) : VersionConstraint
      intersect other.invert
    end

    def allows_all?(other : VersionConstraint) : Bool
      @range.allows_all? other.range
    end

    def allows_any?(other : VersionConstraint) : Bool
      @range.intersects? other.range
    end

    def subset?(other : VersionConstraint) : Bool
      other.allows_all? self
    end

    def allows_any?(other : VersionConstraint) : Bool
      other.allows_any? self
    end

    def disjoint?(other : VersionConstraint) : Bool
      !overlap?(other)
    end

    def relation(other : VersionConstraint) : Relation
      if subset? other
        :subset
      elsif overlap? other
        :overlap
      else
        :disjoint
      end
    end

    def any? : Bool
      @range.any? # ameba:disable Performance/AnyInsteadOfEmpty
    end

    def empty? : Bool
      @range.empty?
    end

    def to_s(allow_every : Bool = false) : String
      if Package.root? @package
        package.to_s
      elsif allow_every && any?
        "every version of #{@package}"
      else
        "#{@package} #{constraint_string}"
      end
    end

    def constraint_string : String
      if any?
        ">= 0"
      else
        @range.to_s
      end
    end
  end
end
