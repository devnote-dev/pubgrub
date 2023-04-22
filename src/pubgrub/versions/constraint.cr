module PubGrub
  class Version
    module Constraint
      def self.any : Range
        Range.new
      end

      def self.empty : Empty
        Empty.new
      end

      def self.parse(text : String) : Version
        text = text.trim
        return any if text == "any"

        compatible = match_compatible_with text
        return compatible unless compatible.nil?

        min : Version? = nil
        max : Version? = nil
        include_min = include_max = false
        original = text.dup

        loop do
          break if text.empty?

          range = match_verison(text) || match_comparison(text)
          unless range
            raise ArgumentError.new "could not parse version '#{original}'"
          end

          if new_min = range.min
            if min.nil? || new_min > min
              min = new_min
              include_min = range.include_min
            elsif new_min == min && !range.include_min
              include_min = false
            end
          end

          if new_max = range.max
            if max.nil? || new_max < max
              max = new_max
              include_max = range.include_max
            elsif new_max == max && !range.include_max
              include_max = false
            end
          end
        end

        if min.nil? && max.nil?
          raise ArgumentError.new "cannot parse an empty string"
        end

        unless min.nil? || max.nil?
          return empty if min > max
          if min == max
            return min if include_min && include_max
            return empty
          end
        end

        Version::Range.new(min: min, max: max, include_min: include_min, include_max: include_max)
      end

      def self.intersection(constraints : Enumerable(Version::Constraint)) : Version::Constraint
        constraints.reduce(Version::Range.new) { |acc, con| acc & con }
      end

      def self.union(constraints : Enumerable(Version::Constraint)) : Version::Constraint
        flattened = constraints.flat_map do |constraint|
          return [] of Version::Constraint if constraint.empty?

          case constraint
          when Version::Range then constraint.ranges
          when Version::Union then [constraint]
          else raise ArgumentError.new "unknown version constraint type: #{typeof(constraint)}"
          end
        end

        return empty if flattened.empty?
        return any if flattened.any? &.any?

        flattened.sort!
        merged = [] of Version::Range

        flattened.each do |constraint|
          if merged.empty? || (merged.last.allows_any?(constraint) && adjacent?(merged.last, constraint))
            merged << constraint
          else
            merged[merged.size - 1] = merged.last.union(constraint)
          end
        end

        return merged.first if merged.size == 1

        Version::Union.from_ranges merged
      end

      abstract def any? : Bool
      abstract def empty? : Bool
      abstract def allows?(version : Version) : Bool
      abstract def allows_any?(other : Version::Constraint) : Bool
      abstract def allows_all?(other : Version::Constraint) : Bool
      abstract def intersect(other : Version::Constraint) : Version::Constraint
      abstract def union(other : Version::Constraint) : Version::Constraint
      abstract def difference(other : Version::Constraint) : Version::Constraint

      def &(other : Version::Constraint) : Version::Constraint
        intersect other
      end

      def |(other : Version::Constraint) : Version::Constraint
        union other
      end

      def -(other : Version::Constraint) : Version::Constraint
        difference other
      end

      private def self.match_verison(text : String) : Version?
        version = VERSION_REGEX.match text

        Version.parse version[0] if version
      end

      private def self.match_comparison(text : String) : Version::Range?
        comparison = COMPARISON_REGEX.match text
        return nil unless comparison

        op = comparison[0]
        text = text.byte_slice(comparison.end).trim
        version = match_verison text
        unless version
          raise ArgumentError.new "expected version number after '#{op}'; got #{text}"
        end

        case op
        when "<" then Version::Range.new(max: version)
        when "<=" then Version::Range.new(max: version, include_max: true)
        when ">" then Version::Range.new(min: version)
        when ">=" then Version::Range.new(min: version, include_min: true)
        else raise ArgumentError.new "unsupported version operator '#{op}'"
        end
      end

      private def self.match_compatible_with(text : String) : Version::Constraint?
        return nil unless text.starts_with? '^'

        text = text.byte_slice(1).trim
        version = match_verison text
        unless version
          raise ArgumentError.new "expected version number after '#{op}'; got #{text}"
        end

        unless text.empty?
          raise ArgumentError.new "cannot include other constraints with '^' constraint"
        end

        Version::Range.new(version, version.next_breaking.first_prerelease, true, false)
      end
    end
  end
end
