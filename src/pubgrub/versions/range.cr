module PubGrub
  class Version
    class Range < Constraint
      include Comparable(Range)

      getter min : Version?
      getter max : Version?
      getter? include_min : Bool
      getter? include_max : Bool

      def initialize(*, @min : Version? = nil, @max : Version? = nil,
                     @include_min : Bool = false, @include_max : Bool = false)
        if min && max && min > max
          raise ArgumentError.new "minimum version '#{min}' must be less than maximum version '#{max}'"
        end
      end

      def any? : Bool
        false
      end

      def empty? : Bool
        false
      end

      def allows?(version : Version) : Bool
        if min = @min
          return false if other < min
          return false if @include_min && other == min
        end

        if max = @max
          return false if other > max
          return false if @include_max && other == max
        end

        true
      end

      def allows_any?(other : Version::Constraint) : Bool
        return false if other.empty?

        case other
        when Version
          allows? other
        when Version::Range
          !strictly_lower?(other, self) && !strictly_higher?(other, self)
        when Version::Union
          other.ranges.any? { |r| allows_any? r }
        else
          raise ArgumentError.new "unknown version constraint type: #{typeof(other)}"
        end
      end

      def allows_all?(first : Version::Range, second : Version::Range) : Bool
        return true if other.empty?

        case other
        when Version
          allows? other
        when Version::Range
          !allows_lower?(other, self) && !allows_higher?(other, self)
        when Version::Union
          other.ranges.all? { |r| allows_all? r }
        else
          raise ArgumentError.new "unknown version constraint type: #{typeof(other)}"
        end
      end

      def intersect(other : Version::Constraint) : Version::Constraint
        return other if other.empty?
        return other & this if other.is_a? Union

        if other.is_a? Version
          return allows?(other) ? other : empty
        end

        if other.is_a? Range
          intersect_min : Version?
          intersect_include_min : Bool

          if allows_lower?(self, other)
            return empty if strictly_lower?(self, other)
            intersect_min = other.min
            intersect_include_min = other.include_min?
          else
            return empty if strictly_lower?(other, self)
            intersect_min = @min
            intersect_include_min = @include_min
          end

          intersect_max : Version?
          intersect_include_max : Bool

          if allows_higher?(self, other)
            intersect_max = other.max
            intersect_include_max = other.include_max?
          else
            intersect_max = @max
            intersect_include_max = @include_max
          end

          return Range.new if intersect_min.nil? && intersect_max.nil?
          return intersect_min if intersect_min == intersect_max

          Range.new(min: intersect_min, max: intersect_max, include_min: intersect_include_min, include_max: intersect_include_max)
        end

        raise "Unknown Version::Constraint type #{other.class}"
      end

      def union(other : Version::Constraint) : Version::Constraint
        if other.is_a? Version
          return self if allows? other

          if other == @min
            return Range.new(min: @min, max: @max, include_min: true, include_max: @include_max)
          end

          if other == @max
            return Range.new(min: @min, max: @max, include_min: @include_min, include_max: true)
          end

          return Constraint.union_of(self, other)
        end

        if other.is_a? Range
          edges_touch = (!@max.nil? && @max == other.min && (@include_max & other.include_min?)) ||
            (!@min.nil? && @min == other.max && (@include_min | other.include_max?))

          if !edges_touch && !allows_any?(other)
            return Constraint.union_of(self, other)
          end

          union_min : Version?
          union_include_min : Bool

          if allows_lower?(self, other)
            union_min = @min
            union_include_min = @include_min
          else
            union_min = other.min
            union_include_min = other.include_min?
          end

          union_max : Version?
          union_include_max : Bool

          if allows_higher?(self, other)
            union_max = @max
            union_include_max = @include_max
          else
            union_max = other.max
            union_include_max = other.include_max?
          end

          return Range.new(min: union_min, max: union_max, include_min: union_include_min, include_max: union_include_max)
        end

        Constraint.union_of(self, other)
      end

      def difference(other : Version::Constraint) : Version::Constraint
        return empty if other.empty?

        if other.is_a? Version
          return self unless allows?(other)

          if other == @min
            return self unless @include_min
            return Range.new(min: @min, max: @max, include_max: @include_max)
          end

          if other == @max
            return self unless @include_max
            return Range.new(min: @min, max: @max, include_min: @include_min)
          end

          return Union.from_ranges(
            Range.new(min: @min, max: other, include_min: @include_min),
            Range.new(min: other, max: @max, include_max: @include_max)
          )
        elsif other.is_a? Range
          return self unless allows_any? other

          before : Range?
          if !allows_lower?(self, other)
            before = nil
          elsif @min == other.min
            before = @min
          else
            before = Range.new(min: @min, max: other.min, include_min: @include_min, include_max: !other.include_min?)
          end

          after : Range?
          if !allows_higher?(self, other)
            after = nil
          elsif @max == other.max
            after = @max
          else
            after = Range.new(min: other.max, max: @max, include_min: !other.include_max?, include_max: @include_max)
          end

          return empty if before.nil? && after.nil?
          return after if before.nil?
          return before if after.nil?

          Union.from_ranges(before, after)
        elsif other.is_a? Union
          ranges = [] of Range
          current = self

          other.ranges.each do |range|
            next if strictly_lower?(range, current)
            break if strictly_higher?(range, current)

            diff = current - range
            if diff.empty?
              return empty
            elsif diff.is_a? Union
              ranges << diff.ranges.first
              current = diff.ranges.last
            else
              current = diff.as(Range)
            end
          end

          return current if ranges.empty?

          Union.from_ranges(ranges << current)
        end

        raise "Unknown Version::Constraint type #{other.class}"
      end

      def ==(other : Range) : Bool
        (@min == other.min) && (@max == other.max) &&
          (@include_min & other.include_min?) && (@include_max & other.include_max?)
      end

      def <=>(other : Range) : Int32
        if @min.nil?
          return compare_max(other) if other.min.nil?
          return -1
        elsif other.min.nil?
          return 1
        end

        result = @min.as(Version) <=> other.min.as(Version)
        return result unless result.zero?
        if @include_min != other.include_min?
          return @include_min ? -1 : 1
        end

        compare_max other
      end

      private def compare_max(other : Version::Constraint) : Int32
        if @max.nil?
          return 0 if other.max.nil?
          return 1
        elsif other.max.nil?
          return -1
        end

        result = @max.as(Version) <=> other.max.as(Version)
        return result unless result.zero?
        if @include_max != other.include_max?
          return @include_max ? 1 : -1
        end

        0
      end

      def to_s(io : IO) : Nil
        return io << "any" if @min.nil? && @max.nil?

        if min = @min
          io << '>'
          io << '=' if @include_min
          io << ' ' << min
        end

        if max = @max
          io << '=' if @include_max
          io << '<' << ' ' << max
        end
      end
    end
  end
end
