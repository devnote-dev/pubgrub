module PubGrub
  class Term
    getter constraint : VersionConstraint
    getter package : Package
    getter? positive : Bool
    getter normalized_constraint : VersionConstraint?

    enum Relation
      Disjoint
      Overlap
      Subset
    end

    def initialize(@constraint : VersionConstraint, @positive : Bool)
      @package = constraint.package
      @normalized_constraint = nil
    end

    def negative? : Bool
      !@positive
    end

    def invert : Term
      new @package, @constraint, !@positive
    end

    def intersect(other : Term) : Term
      raise ArgumentError.new "packages must match" unless @package == other.package

      if @positive && other.positive?
        new @constraint.intersect(other.constraint), true
      elsif negative? && other.negative?
        new constraint.union(other.constraint), false
      else
        positive = @positive ? self : other
        negative = negative? ? self : other

        new positive.constraint.intersect(negative.constraint.invert), true
      end
    end

    def difference(other : Term) : Term
      intersect other.invert
    end

    def relation(other : Term) : Relation
      case
      when @positive && other.positive?
        @constraint.relation other.constraint
      when negative? && other.positive?
        if @constraint.allows_all? other.constraint
          :disjoint
        else
          :overlap
        end
      when @positive && other.negative?
        if !other.constraint.allows_any? @constraint
          :subset
        elsif other.constraint.allows_all? @constraint
          :disjoint
        else
          :overlap
        end
      when negative? && other.negative?
        if @constraint.allows_all? other.constraint
          :subset
        else
          :overlap
        end
      end
    end

    def normalize_constraint : VersionConstraint
      @normalized_constraint ||= @positive ? @constraint : @constraint.invert
    end

    def satisfies?(other : Term) : Bool
      raise ArgumentError.new "Packages must match" unless @package == other.package

      relation(other) == :subset
    end

    def empty? : Bool
      @normalized_constraint.empty?
    end
  end
end
