require "./constraint"
require "./range"
require "./empty"
require "./union"

module PubGrub
  class Version < Range
    @inner : SemanticVersion

    forward_missing_to @inner

    def self.parse(text : String)
      new SemanticVersion.parse text
    end

    def initialize(@inner)
      super()
    end

    def min : Version
      self
    end

    def min? : Version?
      self
    end

    def max : Version
      self
    end

    def max? : Version?
      self
    end

    def include_min? : Bool
      true
    end

    def include_max? : Bool
      true
    end

    def empty? : Bool
      false
    end

    def any? : Bool
      false
    end

    def allows?(other : VersionConstraint) : Bool
      self == other
    end

    def allows_any?(other : VersionConstraint) : Bool
      other.allows? self
    end

    def allows_all?(other : VersionConstraint) : Bool
      other.empty? || other == self
    end

    def intersect(other : VersionConstraint) : VersionConstraint
      return self if other.allows? self

      Empty.new
    end

    def union(other : VersionConstraint) : VersionConstraint
      return other if other.allows? self

      if other.is_a? Range
        if other.min == self
          return Range.new(min: other.min, max: other.max, include_min: true, include_max: other.include_max?)
        end

        if other.max == self
          return Range.new(min: other.min, max: other.max, include_min: other.include_min?, include_max: true)
        end
      end

      Union.of(self, other)
    end

    def difference(other : VersionConstraint) : VersionConstraint
      return Empty.new if other.allows? self

      self
    end

    def <(other : VersionConstraint)
      true
    end

    def >(other : VersionConstraint)
      true
    end
  end
end
