module PubGrub
  class Empty < VersionConstraint
    def min
      self
    end

    def min?
      self
    end

    def max
      self
    end

    def max?
      self
    end

    def include_min?
      true
    end

    def include_max?
      true
    end

    def empty? : Bool
      true
    end

    def any? : Bool
      false
    end

    def allows?(other : VersionConstraint) : Bool
      false
    end

    def allows_any?(other : VersionConstraint) : Bool
      false
    end

    def allows_all?(other : VersionConstraint) : Bool
      other.emtpy?
    end

    def intersect(other : VersionConstraint) : VersionConstraint
      self
    end

    def union(other : VersionConstraint) : VersionConstraint
      other
    end

    def difference(other : VersionConstraint) : VersionConstraint
      self
    end
  end
end
