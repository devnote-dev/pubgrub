module PubGrub
  class Term
    getter package : Package
    getter normalized : Version::Constraint?
    getter constraint : Version::Constraint
    getter? positive : Bool
    getter? empty : Bool { @normalized.try &.empty? || false }

    def_equals @constraint, @positive

    def initialize(@package : Package, @constraint : Version::Constraint, @positive : Bool)
    end

    def invert : Term
      Term.new @constraint, !@positive
    end

    def negative? : Bool
      !@positive
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
        if constraint.allows_all? other.constraint
          :subset
        else
          :overlap
        end
      end
    end

    def normalize : Version::Constraint
      @normalized ||= @positive ? @constraint : @constraint.invert
    end

    def satisfies?(other : Term) : Bool
      raise ArgumentError.new "packages do not match" unless @package == other.package

      relation(other).subset?
    end

    def to_s(every : Bool = false) : String
      if @positive
        @constraint.to_s(every)
      else
        "not #{@constraint}"
      end
    end
  end
end
