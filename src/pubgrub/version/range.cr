module PubGrub
  class Range < VersionConstraint
    getter? min : Version?
    getter? max : Version?
    getter? include_min : Bool
    getter? include_max : Bool

    def initialize(*, @min = nil, @max = nil, @include_min = false, @include_max = false)
    end

    def min : Version
      @min.as(Version)
    end

    def max : Version
      @max.as(Version)
    end

    def empty? : Bool
      false
    end

    def any? : Bool
      @min.nil? && @max.nil?
    end

    def allows?(other : VersionConstraint) : Bool
      if min?
        return false if other < min
        return false if !@include_min && other == min
      end

      if max?
        return false if other > max
        return false if !@include_max && other == max
      end

      true
    end

    def allows_any?(other : VersionConstraint) : Bool
      return false if other.empty?

      case other
      when Version
        allows? other
      when Union
        other.ranges.any? { |r| allows? r }
      when Range
        !other.strictly_lower?(self) && !other.strictly_higher?(self)
      else
        raise ArgumentError.new "Unknown VersionConstraint type #{other.class}"
      end
    end

    def allows_all?(other : VersionConstraint) : Bool
      return true if other.empty?

      case other
      when Version
        allows? other
      when Union
        other.ranges.all? { |r| allows_all? r }
      when Range
        !other.allows_lower?(self) && !other.allows_higher?(self)
      else
        raise ArgumentError.new "Unknown VersionConstraint type #{other.class}"
      end
    end

    def intersect(other : VersionConstraint) : VersionConstraint
      return other if other.empty?

      case other
      when Version
        return other if allows? other

        Empty.new
      when Union
        other.intersect self
      when Range
        intersect_min : Version? = nil
        intersect_include_min = false

        if allows_lower? other
          return Empty.new if strictly_lower? other

          intersect_min = other.min?
          intersect_include_min = other.include_min?
        else
          return Empty.new if other.strictly_lower? self

          intersect_min = @min
          intersect_include_min = @include_min
        end

        intersect_max : Version? = nil
        intersect_include_max = false

        if allows_higher? other
          intersect_max = other.max?
          intersect_include_max = other.include_max?
        else
          intersect_max = @max
          intersect_include_max = @include_max
        end

        return Range.new if intersect_min.nil? && intersect_max.nil?
        return intersect_min if intersect_min && intersect_min == intersect_max

        Range.new(
          min: intersect_min,
          max: intersect_max,
          include_min: intersect_include_min,
          include_max: intersect_include_max
        )
      else
        raise ArgumentError.new "Unknown VersionConstraint type #{other.class}"
      end
    end

    def union(other : VersionConstraint) : VersionConstraint
      case other
      when Version
        return self if allows? other

        if other == min
          return Range.new(min: @min, max: @max, include_min: true, include_max: @include_max)
        end

        if other == max
          return Range.new(min: @min, max: @max, include_min: @include_min, include_max: true)
        end

        Union.of(self, other)
      when Range
        edges_touch = (@max == other.min && (@include_max | other.include_min?)) ||
                      (@min == other.max && (@include_min | other.include_max?))

        return Union.of(self, other) if !edges_touch && !allows_any?(other)
        # TODO: inverse expression?
        # return Union.of(self, other) unless edges_touch || allows_any?(other)

        union_min : Version? = nil
        union_include_min = false
        union_max : Version? = nil
        union_include_max = false

        if allows_lower? other
          union_min = @min
          union_include_min = @include_min
        else
          union_min = other.min?
          union_include_min = other.include_min?
        end

        if allows_higher? other
          union_max = @max
          union_include_max = @include_max
        else
          union_max = other.max?
          union_include_max = other.include_max?
        end

        Range.new(
          min: union_min,
          max: union_max,
          include_min: union_include_min,
          include_max: union_include_max
        )
      else
        Union.of(self, other)
      end
    end

    def difference(other : VersionConstraint) : VersionConstraint
      return self if other.empty?

      case other
      when Version
        return self unless allows? other

        if other == @min
          return self unless @include_min

          Range.new(min: @min, max: @max, include_min: false, include_max: @include_max)
        end

        if other == @max
          return self unless @include_max

          Range.new(min: @min, max: @max, include_min: @include_min, include_max: false)
        end

        Union.of(
          Range.new(min: @min, max: other, include_min: @include_min, include_max: false),
          Range.new(min: other, max: @max, include_min: false, include_max: @include_max)
        )
      when Union
        ranges = [] of Range
        current = self

        other.ranges.each do |range|
          next if range.strictly_lower? current
          break if range.strictly_higher? current.as(Range)

          diff = current.difference range
          return Empty.new if diff.empty?

          if diff.is_a? Union
            ranges << diff.ranges[0]
            current = diff.ranges[-1]
          else
            current = diff
          end
        end

        return current if ranges.empty?

        Union.of(ranges << current.as(Range))
      when Range
        return self unless allows_any? other

        before : VersionConstraint? = nil

        if !allows_lower?(other)
          # TODO: possibly an unnecessary check?
          before = nil
        elsif @min == other.min?
          before = @min
        else
          before = Range.new(
            min: @min,
            max: other.min,
            include_min: @include_min,
            include_max: !other.include_min?
          )
        end

        after : VersionConstraint? = nil

        if !allows_higher?(other)
          # TODO: also an unncessary check?
          after = nil
        elsif @max == other.max?
          after = @max
        else
          after = Range.new(
            min: other.max,
            max: @max,
            include_min: !other.include_max?,
            include_max: @include_max
          )
        end

        return after if after && before.nil?
        return before if before && after.nil?

        if before && after
          Union.of(before, after)
        else
          self
        end
      else
        raise ArgumentError.new "Unknown VersionConstraint type #{other.class}"
      end
    end

    def allows_higher?(other : VersionConstraint) : Bool
      return !other.max?.nil? if @max.nil?
      return false if other.max?.nil?
      return false if max < other.max
      return true if max > other.max

      @include_max && !other.include_max?
    end

    def allows_lower?(other : Range) : Bool
      return !other.min?.nil? if @min.nil?
      return false if other.min.nil?
      return true if min < other.min
      return false if min > other.min

      @include_min && !other.include_min?
    end

    def strictly_higher?(other : Range) : Bool
      other.strictly_lower? self
    end

    def strictly_lower?(other : VersionConstraint) : Bool
      return false if @max.nil? || other.min.nil?
      return true if max < other.min
      return false if max > other.min

      !@include_max || !other.include_min?
    end

    def adjacent_to?(other : VersionConstraint) : Bool
      return false unless @max == other.min?

      @include_max && !other.include_min? || !@include_max && other.include_min?
    end

    def to_s(io : IO) : Nil
      unless @min.nil?
        io << '>'
        io << '=' if @include_min
      end

      unless @max.nil?
        io << ',' unless @min.nil?
        io << '<'
        io << '=' if @include_max
      end

      io << '*' if @min.nil? && @max.nil?
    end

    def ==(other : Range) : Bool
      @min == other.min? && @max == other.max? &&
        @include_min == other.include_min? && @include_max == other.include_max?
    end

    def <(other : Range) : Bool
      self <=> other < 0
    end

    def <=(other : Range) : Bool
      self <=> other <= 0
    end

    def >(other : Range) : Bool
      self <=> other > 0
    end

    def >=(other : Range) : Bool
      self <=> other >= 0
    end

    def <=>(other : Range) : Int
      if @min.nil?
        if other.min?.nil?
          return compare_max other
        end

        return -1
      elsif other.min?.nil?
        return 1
      end

      result = min <=> other.min
      return result unless result == 0

      unless @include_min == other.include_min?
        return @include_min ? -1 : 1
      end

      compare_max other
    end

    private def compare_max(other : Range) : Int
      if @max.nil?
        return 0 if other.max?.nil?
        return 1
      elsif other.max?.nil?
        return -1
      end

      result = max <=> other.max
      return result unless result == 0

      unless @include_max == other.include_max?
        return @include_max ? 1 : -1
      end

      0
    end
  end
end
