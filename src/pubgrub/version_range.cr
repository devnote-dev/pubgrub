module PubGrub
  class VersionRange
    EMPTY = Empty.new

    getter min : Int32?
    getter max : Int32?
    getter? include_min : Bool
    getter? include_max : Bool
    getter name : String?

    def initialize(*, @min : Int32?, @max : Int32?, @include_min : Bool = false,
                   @include_max : Bool = false, @name : String? = nil)
    end

    def self.any
      new min: nil, max: nil
    end

    def ranges : Array(VersionRange)
      [self]
    end

    def includes?(version : Int32) : Bool
      compare_version(version) == 0
    end

    def partition_versions(versions : Enumerable(Int32)) : {Int32, Int32, Int32}
      min_index = if @min.nil? || versions.empty?
                    0
                  elsif @include_min
                    (0..versions.size).bsearch { |i| versions[i].nil? || versions[i] >= @min }
                  else
                    (0..versions.size).bsearch { |i| versions[i].nil? || versions[i] > @min }
                  end

      lower = versions.slice 0, min_index
      versions = versions.slice min_index, versions.size

      max_index = if @max.nil? || versions.empty?
                    versions.size
                  elsif @include_max
                    (0..versions.size).bsearch { |i| versions[i].nil? || versions[i] > @max }
                  else
                    (0..versions.size).bsearch { |i| versions[i].nil? || versions[i] >= @max }
                  end

      {lower, versions.slice(0, max_index), versions.slice(max_index, versions.size)}
    end

    def select_versions(versions : Enumerable(Int32)) : Array(Int32)
      return versions.to_a if any?

      partition_versions(versions)[1]
    end

    def compare_version(version : Int32) : Int32
      if min = @min
        case version <=> min
        when -1 then return -1
        when  0 then return -1 unless @include_min
        end
      end

      if max = @max
        case version <=> max
        when 0 then return 1 unless @include_max
        when 1 then return 1
        end
      end

      0
    end

    def strictly_lower?(other : VersionRange) : Bool
      return false if @max.nil? || other.min.nil?

      case @max <=> other.min
      when -1
        true
      when 0
        !@include_max && !other.include_min
      when 1
        false
      end
    end

    def strictly_higher?(other : VersionRange) : Bool
      other.strictly_lower? self
    end

    def intersects?(other : VersionRange) : Bool
      return false if other.empty?
      return other.intersects?(self) if other.is_a? VersionUnion

      !strictly_lower?(other) && !strictly_higher?(other)
    end

    def intersect(other : VersionRange) : VersionRange
      return other if other.empty?
      return other.intersect(self) if other.is_a? VersionUnion

      min_range = if @min.nil?
                    other
                  elsif other.min.nil?
                    self
                  else
                    case @min <=> other.min
                    when -1 then other
                    when  0 then @include_min ? other : self
                    when  1 then self
                    end
                  end

      max_range = if @max.nil?
                    other
                  elsif other.max.nil?
                    self
                  else
                    case @max <=> other.max
                    when -1 then self
                    when  0 then @include_max ? other : self
                    when  1 then other
                    end
                  end

      if min_range != max_range && (min = min_range.min) && (max = max_range.max)
        case min <=> max
        when 0
          return EMPTY if !min_range.include_min || !max_range.include_max
        when 1
          return EMPTY
        end
      end

      new(
        min: min_range.min,
        max: max_range.max,
        include_min: min_range.include_min,
        include_max: max_range.include_max
      )
    end

    def span(other : VersionRange) : VersionRange
      return self if other.empty?

      min_range = if min.nil?
                    self
                  elsif other.min.nil?
                    other
                  else
                    case @min <=> other.min
                    when -1 then self
                    when  0 then @include_min ? self : other
                    when  1 then other
                    end
                  end

      max_range = if @max.nil?
                    self
                  elsif other.max.nil?
                    other
                  else
                    case @max <=> other.max
                    when -1 then other
                    when  0 then @include_max ? self : other
                    when  1 then self
                    end
                  end

      new(
        min: min_range.min,
        max: max_range.max,
        include_min: min_range.include_min,
        include_max: max_range.include_max
      )
    end

    def union(other : VersionRange) : VersionRange
      return other.union(self) if other.is_a? VersionUnion

      if contiguous_to? other
        span other
      else
        VersionUnion.union [self, other]
      end
    end

    def contiguous_to?(other : VersionRange) : Bool
      return false if other.empty?

      intersects?(other) ||
        (@min == other.max && (@include_min || other.include_max)) ||
        (@max == other.min && (@include_max || other.include_min))
    end

    def allows_all?(other : VersionRange) : Bool
      return true if other.empty?

      if other.is_a? VersionUnion
        return VersionUnion.new([self]).allows_all?(other)
      end

      return false if @max && other.max.nil?
      return false if @min && other.min.nil?

      if min = @min
        case min <=> other.min
        when 0
          return false if !@include_min && other.include_min
        when 1
          return false
        end
      end

      if max = @max
        case max <=> other.max
        when -1
          return false
        when 0
          return false if !@include_max && other.include_max
        end
      end

      true
    end

    def any? : Bool
      @min.nil? && @max.nil?
    end

    def empty? : Bool
      false
    end

    def upper_invert : VersionRange
      return EMPTY unless @max

      new(@min, nil, include_min: !@include_max)
    end

    def invert : VersionRange
      return EMPTY if any?

      low = new(nil, @min, include_max: !@include_min)
      high = new(@max, nil, include_min: !@include_max)

      if @min.nil?
        high
      elsif @max.nil?
        low
      else
        low.union high
      end
    end

    private def constraints : Array(String)
      return ["any"] if any?
      return ["= #{@min}"] if @min == @max

      arr = [] of String
      arr << %(#{@include_min ? ">=" : ">"} #{@min}) if @min
      arr << %(#{@include_max ? "<=" : "<"} #{@max}) if @max
    end

    def to_s : String
      @name ||= constraints.join ", "
    end

    class Empty < VersionRange
      def initialize
        super 0, 0
      end

      def empty? : Bool
        true
      end

      def intersects?(o : _) : Bool
        false
      end

      def intersect(o : _) : VersionRange
        self
      end

      def allows_all?(other : VersionRange) : Bool
        other.empty?
      end

      def includes?(o : _) : Bool
        false
      end

      def any? : Bool
        false
      end

      def invert : VersionRange
        VersionRange.any
      end

      def to_s : String
        "(no versions)"
      end
    end
  end
end
