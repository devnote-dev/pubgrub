module PubGrub
  abstract class VersionConstraint
    abstract def empty? : Bool
    abstract def any? : Bool
    abstract def allows?(other : VersionConstraint) : Bool
    abstract def allows_any?(other : VersionConstraint) : Bool
    abstract def allows_all?(other : VersionConstraint) : Bool
    abstract def intersect(other : VersionConstraint) : VersionConstraint
    abstract def union(other : VersionConstraint) : VersionConstraint
    abstract def difference(other : VersionConstraint) : VersionConstraint
  end
end
