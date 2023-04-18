module PubGrub
  enum Relation
    Subset
    Overlap
    Disjoint
  end

  class VersionConstraint
    getter package : Package
    getter range : VersionRange?

    def_equals @package, @range

    def self.any(package : Package)
      new package, VersionRange.new
    end

    def self.empty(package : Package)
      new package, VersionRange::Empty.new
    end

    def self.exact(package : Package, version : Int32)
      range = VersionRange.new(min: version, max: version, include_min: true, include_max: true)
      new package, range
    end

    def initialize(@package : Package, @range : VersionRange?)
    end

    def to_s(every : Bool = false) : String
      if @package.root?
        @package.to_s
      elsif every && @range.any?
        "every version of #{@package}"
      else
        "#{@package} #{@range.any? ? ">= 0" : @range.to_s}"
      end
    end
  end

  class VersionRange
    getter name : String?
    getter min : Int32?
    getter max : Int32?
    getter? include_min : Bool
    getter? include_max : Bool

    def initialize(*, @name : String? = nil, @min : Int32? = nil,
                   @max : Int32? = nil, @include_min : Bool = false,
                   @include_max : Bool = false)
    end

    def ranges : Array(VersionRange)
      [self]
    end

    def invert : VersionRange
      new
    end

    def includes?(version : VersionRange) : Bool
      self <=> version == 0
    end

    def any? : Bool
      !@min && !@max
    end

    def empty? : Bool
      false
    end

    def to_s : String
      @name ||= constraints.join ", "
    end

    private def constraints : Array(String)
      return ["any"] if any?
      return ["= #{min}"] if @min == @max

      arr = [] of String
      arr << ">#{"=" if @include_min} #{@min}" if @min
      arr << "<#{"=" if @include_max} #{@max}" if @max

      arr
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

    class Empty < VersionRange
      def initialize
        super
      end

      def ranges : Array(VersionRange)
        [] of VersionRange
      end

      def invert : VersionRange
        VersionRange.any
      end

      def any? : Bool
        false
      end

      def empty? : Bool
        true
      end

      def to_s : String
        "(no versions)"
      end

      def ==(other : VersionRange) : Bool
        other.empty?
      end
    end
  end

  class VersionUnion
    getter ranges : Array(VersionRange)

    def initialize(@ranges : Array(VersionRange))
    end

    def normalize : Array(VersionRange)
      ranges = @ranges.flat_map(&.ranges).reject(&.empty?)
      return ranges if ranges.empty?

      mins, ranges = ranges.partition &.min.nil?
      originals = mins + ranges.sort_by { |r| {r.min, r.include_min? ? 0 : 1} }
      ranges = [originals.shift]

      originals.each do |range|
        if ranges.last.contigious_to? range
          ranges << ranges.pop.span(range)
        else
          ranges << range
        end
      end

      range
    end

    def self.union(ranges : Array(VersionRange), normalize : Bool = true)
      ranges = normalize(ranges) if normalize

      case ranges.size
      when 0
        VersionRange.empty
      when 1
        ranges.first
      else
        new ranges
      end
    end

    def to_s : String
      String.build { |io| to_s io }
    end

    def to_s(io : IO) : Nil
      ranges = @ranges.dup

      until ranges.empty?
        ne = [] of Int32
        range = ranges.shift

        while !ranges.empty? && ranges.first.min == range.max
          ne << range.max
          range = range.span(ranges.shift)
        end

        ne.map! {|x| "!= #{x}" }
        if ne.empty?
          output << range.to_s
        elsif range.any?
          output << ne.join ", "
        else
          output << "#{range}, #{ne.join(", ")}"
        end
      end

      output.join(" OR ")
    end

    def ==(other : Union) : Bool
      @ranges == other.ranges
    end
  end
end
