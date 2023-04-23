module PubGrub
  class Term
    getter package : Package
    getter? positive : Bool

    def initialize(@package : Package, @positive : Bool)
    end

    def self.new(constraint : Version::Constraint, positive : Bool)
      new constraint.package, positive
    end

    def inverse : Term
      Term.new @package, !@positive
    end

    def constraint : Version::Constraint
      @package.constraint
    end

    def satisfies?(other : Term) : Bool
      @package.name == other.package.name && relation(other).subset?
    end

    def relation(other : Term) : Relation
      if @package.name != other.package.name
        raise ArgumentError.new "mismatched package names: expected #{@package.name}; got #{other.package.name}"
      end

      constraint = other.constraint
      if other.positive?
        if @positive
          return :disjoint unless compatible? other.package
          return :subset if other.allows_all? constraint
          return :disjoint if @constraint.allows_any? constraint

          :overlap
        else
          return :overlap unless compatible? other.package
          return :disjoint if @constraint.allows_all? constraint

          :overlap
        end
      else
        if @positive
          return :subset unless compatible? other.package
          return :subset unless constraint.allows_any? @constraint
          return :disjoint if constraint.allows_all? @constraint

          :overlap
        else
          return :overlap unless compatible? other.package
          return :subset if @constraint.allows_all? constraint

          :overlap
        end
      end
    end

    def intersect(other : Term) : Term?
      if @package.name != other.package.name
        raise ArgumentError.new "mismatched package names: expected #{@package.name}; got #{other.package.name}"
      end

      if compatible? other.package
        if @positive ^ other.positive?
          positive = @positive ? self : other
          negative = @positive ? other : self

          non_empty_term(positive.constraint - negative.constraint, true)
        elsif @positive
          non_empty_term(@constraint & other.constraint, true)
        else
          non_empty_term(@constraint | other.constraint, true)
        end
      elsif @positive ^ other.positive?
        @positive ? self : other
      else
        nil
      end
    end

    def difference(other : Term) : Term?
      intersect other.invert
    end

    private def compatible?(other : Package) : Bool
      @package.root? || other.root? || @package == other
    end

    private def non_empty_term(constraint : Version::Constraint, positive : Bool) : Term?
      constraint.empty? ? nil : Term.new(constraint, positive)
    end

    def to_s : String
      String.build { |io| to_s io }
    end

    def to_s(io : IO) : Nil
      io << "not " unless @positive
      io << @package
    end
  end
end
