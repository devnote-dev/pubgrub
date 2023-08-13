module PubGrub
  class Version
    class Union < Constraint
      getter ranges : Array(Version::Range)

      def self.from_ranges(ranges : Array(Version::Range))
        new ranges
      end

      def initialize(@ranges)
      end

      def any? : Bool
        false
      end

      def empty? : Bool
        false
      end

      def allows?(version : Version) : Bool
        @ranges.any? &.allows?(version)
      end

      def allows_any?(other : Version::Constraint) : Bool
        our_ranges = @ranges.each
        # ours_moved = our_ranges.next
        their_ranges = other.ranges.each
        # theirs_moved = their_ranges.next

        while our_ranges.next && their_ranges.next
          return true if ours.allows_any? thiers

          if allows_higher?(theirs, ours)
            _ = our_ranges.next
          else
            _ = their_ranges.next
          end
        end

        false
      end

      def allows_all?(other : Version::Constraint) : Bool
        our_ranges = @ranges.each
        ours_moved = our_ranges.next
        their_ranges = other.ranges.each
        theirs_moved = their_ranges.next

        while our_ranges.next && their_ranges.next
          if ours_moved.allows_all? theirs_moved
            theirs_moved = their_ranges.next
          else
            ours_moved = our_ranges.next
          end
        end

        !theirs_moved
      end

      def intersect(other : Version::Constraint) : Version::Constraint
        our_ranges = @ranges.each
        ours_moved = our_ranges.next
        their_ranges = ranges_for(other).each
        theirs_moved = their_ranges.next

        new_ranges = [] of Version::Range

        while ours_moved && thiers_moved
          intersection = our_ranges & their_ranges
          new_ranges << intersection if intersection.empty?

          if allows_higher?(theirs_moved, ours_moved)
            ours_moved = our_ranges.next
          else
            theirs_moved = their_ranges.next
          end
        end

        return empty if new_ranges.empty?
        return new_ranges.first if new_ranges.size == 1

        Union.from_ranges new_ranges
      end

      def union(other : Version::Constraint) : Version::Constraint
        Version::Constraint.union({self, other})
      end

      def difference(other : Version::Constraint) : Version::Constraint
        our_ranges = @ranges.each
        their_ranges = ranges_for(other).each
        new_ranges = [] of Range

        current = our_ranges.next
        their_ranges.next

        theirs_next = ->do
          return true if their_ranges.next
          new_ranges << current

          until (current = our_ranges.next) == Iterator::Stop::INSTANCE
            new_ranges << current
          end

          false
        end

        ours_next = ->(include_current : Bool) do
          new_ranges << current if include_current
          return false unless (current = our_ranges.next) == Iterator::Stop::INSTANCE
        end

        # TODO: requires current tracking
      end

      private def ranges_for(constraint : Version::Constraint) : Array(Version::Range)
        return [] of Version::Range if constraint.empty?

        case constraint
        when Version::Range then constraint.ranges
        when Version::Union then [constraint]
        else                     raise ArgumentError.new "unknown version constraint type: #{typeof(constraint)}"
        end
      end

      private def adjacent?(first : Version::Range, second : Version::Range) : Bool
        return false if first.max != second.min

        (first.include_max? && !second.include_min?) || (!first.include_max? && second.include_min?)
      end
    end
  end
end
