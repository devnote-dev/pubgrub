module PubGrub
  class Version
    class Range
      include Constraint
      include Comparable(Range)

      getter min : Version?
      getter max : Version?
      getter? include_min : Bool
      getter? include_max : Bool

      def initialize(*, min : Version? = nil, max : Version? = nil,
                     include_min : Bool = false, include_max : Bool = false)
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
        # TODO
        other
      end

      def union(other : Version::Constraint) : Version::Constraint
        # TODO
        other
      end

      def difference(other : Version::Constraint) : Version::Constraint
        # TODO
        self
      end

      def ==(other : Range) : Bool
        (@min == other.min) && (@max == other.max) &&
          (@include_min & other.include_min?) && (@include_max & other.include_max?)
      end

      def <=>(other : Range) : Int32
      end

      private def compare_min(other : Version::Constraint) : Int32
      end

      private def compare_max(other : Version::Constraint) : Int32
      end

      def to_s : String
        String.build { |io| to_s io }
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
