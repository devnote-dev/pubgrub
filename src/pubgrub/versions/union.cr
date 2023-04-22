module PubGrub
  class Version
    class Union
      include Constraint

      getter ranges : Array(Version::Range)

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
        ours_moved = our_ranges.next
        their_ranges = other.ranges.each
        theirs_moved = their_ranges.next

        while our_ranges.next && their_ranges.next
          return true if ours.allows_any? thiers

          if allows_higher?(theirs, ours)
            ours_moved = our_ranges.next
          else
            theirs_moved = their_ranges.next
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
      end
    end
  end
end
