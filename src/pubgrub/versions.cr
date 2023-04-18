module PubGrub
  enum Relation
    Subset
    Overlap
    Disjoint
  end

  class VersionRange
    getter name : String?
    getter min : Int32?
    getter max : Int32?
    getter? include_min : Bool
    getter? include_max : Bool

    def initialize(*, @name : String? = nil, @min : Int32? = nil,
                   @max : Int32? = nil, @include_min : Int32? = nil,
                   @include_max : Int32? = nil)
    end

    def ranges : Array(VersionRange)
      [self]
    end

    def invert : VersionRange
      new
    end

    def ==(other : VersionRange) : Bool
      if other.is_a? Range
        (@name ? @name == other.name : true) &&
          (@min ? @min == other.min : true) &&
          (@max ? @max == other.max : true) &&
          (@include_min & other.include_min?) &&
          (@include_max & other.include_max?)
      else
        @ranges == other.ranges
      end
    end

    def <=>(other : VersionRange)
      if min = @min
        case other.min <=> min
        when -1 then return -1
        when 0 then return -1 unless @include_min
        end
      end

      if max = @max
        case other.max <=> max
        when 0 then return 1 unless @include_max
        when 1 then return 1
        end
      end

      0
    end
  end

  class VersionConstraint
    getter package : Package
    getter range : VersionRange?

    def self.any(package : Package)
      new package, VersionRange.new
    end

    def self.empty(package : Package)
      new package, VersionRange.new
    end

    def self.exact(package : Package, version : Int32)
      range = VersionRange.new(min: version, max: version, include_min: true, include_max: true)
      new package, range
    end

    def initialize(@package : Package, @range : VersionRange?)
    end

    def ==(other : VersionConstraint) : Bool
      @package == other.package && @range == other.range
    end
  end
end
