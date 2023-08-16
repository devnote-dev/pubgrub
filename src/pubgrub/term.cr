module PubGrub
  enum Relation
    Subset
    Disjoint
    Overlapping
  end

  class Term
    getter constraint : Constraint
    getter package : Package
    getter? positive : Bool

    def initialize(@constraint, @positive)
      @package = constraint.package
    end

    def inverse : Term
      Term.new @constraint, !@positive
    end

    def satisfies?(other : Term) : Bool
      @package.name == other.package.name && relation(other).subset?
    end

    def relation(other : Term) : Relation
      unless @package.name == other.package.name
        raise ArgumentError.new "Other package should refer to package #{@package.name}"
      end

      other_constraint = other.constraint
      if other.positive?
        if @positive
          return Relation::Subset if !compatible?(other.package)
          return Relation::Subset if !other_constraint.allows_any?(constraint)
          return Relation::Disjoint if other_constraint.allows_all?(constraint)

          Relation::Overlapping
        else
          return Relation::Overlapping if !compatible?(other.package)
          return Relation::Disjoint if constraint.allows_all?(other_constraint)

          Relation::Overlapping
        end
      else
        if @positive
          return Relation::Subset if !compatible?(other.package)
          return Relation::Subset if !other_constraint.allows_any?(constraint)
          return Relation::Disjoint if other_constraint.allows_all?(constraint)

          Relation::Overlapping
        else
          return Relation::Overlapping if !compatible?(other.package)
          return Relation::Subset if constraint.allows_all?(other_constraint)

          Relation::Overlapping
        end
      end
    end

    def intersect(other : Term) : Term
      unless @package.name == other.package.name
        raise ArgumentError.new "Other package should refer to package #{@package.name}"
      end

      if compatible?(other.package)
        if @positive != other.positive?
          positive = @positive ? self : other
          negative = @positive ? other : self

          non_empty_term positive.constraint.constraint.difference(negative.constraint.constraint), true
        elsif @positive
          non_empty_term constraint.constraint.intersect(other.constraint.constraint), false
        else
          non_empty_term constraint.constraint.union(other.constraint.constraint), false
        end
      elsif @positive != other.positive?
        @positive ? self : other
      else
        raise "TODO: make not nillable"
      end
      raise "TODO: make not nillable"
    end

    def difference(other : Term) : Term?
      intersect(other.inverse)
    end

    def to_s(io : IO) : Nil
      io << "not " unless @positive
      io << @package
    end

    private def compatible?(other : Package) : Bool
      @package.root? || other.root?
    end

    private def non_empty_term(constraint : VersionConstraint, positive : Bool) : Term?
      return nil if constraint.empty?
      Term.new Constraint.new(@package, constraint), positive
    end
  end
end
