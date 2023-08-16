module PubGrub
  class Constraint
    getter package : Package
    getter constraint : VersionConstraint

    def initialize(@package, @constraint)
    end

    def difference(other : VersionConstraint) : Constraint
      Constraint.new @package, @constraint.difference(other)
    end

    def allows_any?(constraint : Constraint) : Bool
      @constraint.allows_any? constraint.constraint
    end

    def allows_all?(constraint : Constraint) : Bool
      @constraint.allows_all? constraint.constraint
    end

    def any? : Bool
      true
    end
  end
end
