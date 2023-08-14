module PubGrub
  class Constraint
    getter package : Package
    getter constraint : VersionConstraint

    def initialize(@package, @constraint)
    end

    def difference(other : VersionConstraint) : Constraint
      Constraint.new @package, @constraint.difference(other)
    end
  end
end
