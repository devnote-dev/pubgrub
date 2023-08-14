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
      new @package, !@positive
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
          return :subset if !compatible?(other.package)
          return :subset if !other_constraint.allows_any?(constraint)
          return :disjoint if other_constraint.allows_all?(constraint)

          :overlapping
        else
          return :overlapping if !compatible?(other.package)
          return :disjoint if constraint.allows_all?(other_constraint)

          :overlapping
        end
      else
        if @positive
          return :subset if !compatible?(other.package)
          return :subset if !other_constraint.allows_any?(constraint)
          return :disjoint if other_constraint.allows_all?(constraint)

          :overlapping
        else
          return :overlapping if !compatible?(other.package)
          return :subset if constraint.allows_all?(other_constraint)

          :overlapping
        end
      end
    end

    def intersect(other : Term) : Term?
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
        nil
      end
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
