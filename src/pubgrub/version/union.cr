module PubGrub
  class Union < VersionConstraint
    getter ranges : Array(Range)

    def min
      self
    end

    def min?
      self
    end

    def max
      self
    end

    def max?
      self
    end

    def include_min?
      true
    end

    def include_max?
      true
    end

    def self.of(*ranges : VersionConstraint)
      of ranges
    end

    def self.of(ranges : Enumerable(VersionConstraint))
      flattened = [] of Range

      ranges.each do |constraint|
        next if constraint.empty?

        if constraint.is_a? Union
          flattened += constraint.ranges
        end

        flattened << constraint.as(Range)
      end

      return Empty.new if flattened.empty?
      return Range.new if flattened.any? &.any?

      flattened.each do |constraint|
        next if constraint.is_a? Range

        raise ArgumentError.new "Unknown VersionConstraint type #{constraint.class}"
      end

      merged = [] of Range
      flattened.each do |range|
        if merged.empty? || (!merged[-1].allows_any?(range) && !merged[-1].adjacent_to?(range))
          merged << range
        else
          merged[-1] = merged[-1].union(range).as(Range)
        end
      end

      return merged[0] if merged.size == 1

      new merged
    end

    def initialize(@ranges)
    end

    def empty? : Bool
      false
    end

    def any? : Bool
      false
    end

    def allows?(other : VersionConstraint) : Bool
      @ranges.any? &.allows? other
    end

    def allows_any?(other : VersionConstraint) : Bool
      our_ranges = @ranges.each
      their_ranges = ranges_for(other).each

      our_current = our_ranges.next
      their_current = their_ranges.next

      while our_current != Iterator::Stop::INSTANCE && their_current != Iterator::Stop::INSTANCE
        return true if our_current.allows_any? thier_current

        if their_current.allows_higher? our_current
          our_current = our_ranges.next
        else
          their_current = their_ranges.next
        end
      end
    end

    def allows_all?(other : VersionConstraint) : Bool
      our_ranges = @ranges.each
      their_ranges = ranges_for(other).each

      our_current = our_ranges.next
      their_current = their_ranges.next

      while our_current != Iterator::Stop::INSTANCE && their_current != Iterator::Stop::INSTANCE
        if our_current.allows_all? their_current
          their_current = their_ranges.next
        else
          our_current = our_ranges.next
        end
      end

      their_current == Iterator::Stop::INSTANCE
    end

    def intersect(other : VersionConstraint) : VersionConstraint
      our_ranges = @ranges.each
      their_ranges = ranges_for(other).each
      new_ranges = [] of VersionConstraint

      our_current = our_ranges.next
      their_current = their_ranges.next

      while our_current != Iterator::Stop::INSTANCE && their_current != Iterator::Stop::INSTANCE
        inter = our_current.as(Range).intersect their_current.as(Range)
        new_ranges << inter unless inter.empty?

        if their_current.as(Range).allows_higher? our_current.as(Range)
          our_current = our_ranges.next
        else
          their_current = their_ranges.next
        end
      end

      Union.of new_ranges
    end

    def union(other : VersionConstraint) : VersionConstraint
      Union.of(self, other)
    end

    def difference(other : VersionConstraint) : VersionConstraint
      our_ranges = @ranges.each
      their_ranges = ranges_for(other).each
      new_ranges = [] of VersionConstraint

      our_current = our_ranges.next
      their_current = their_ranges.next

      our_next_range = ->(include_current : Bool) do
        new_ranges << our_current.as(Range) if include_current
        ours = our_ranges.next
        return false if ours == Iterator::Stop::INSTANCE
        our_current = ours

        true
      end

      their_next_range = ->do
        theirs = their_ranges.next
        unless theirs == Iterator::Stop::INSTANCE
          their_current = theirs
          return true
        end

        new_ranges << their_current.as(Range)
        ours = our_ranges.next

        while ours != Iterator::Stop::INSTANCE
          new_ranges << ours.as(Range)
          ours = our_ranges.next
        end
      end

      loop do
        break if their_current == Iterator::Stop::INSTANCE

        if their_current.as(Range).strictly_lower? our_current.as(Range)
          break unless their_next_range.call
          next
        end

        if their_current.as(Range).strictly_higher? our_current.as(Range)
          break unless our_next_range.call true
          next
        end

        diff = our_current.as(Range).difference their_current.as(Range)
        if diff.is_a? Union
          new_ranges << diff.ranges[0]
          our_current = diff.ranges[-1]

          break unless their_next_range.call
        elsif diff.empty?
          break unless our_next_range.call false
        else
          our_current = diff
          if our_current.as(Range).allows_higher? their_current.as(Range)
            break unless their_next_range.call
          else
            break unless our_next_range.call true
          end
        end
      end

      return Empty.new if new_ranges.empty?
      return new_ranges[0] if new_ranges.size == 1

      Union.of new_ranges
    end

    def to_s(io : IO) : Nil
      diff = Range.new.difference self
      if diff.is_a? Version
        io << "!=" << diff
      else
        @ranges.join(io, " || ")
      end
    end

    def ==(other : Union) : Bool
      @ranges == other.ranges
    end

    private def ranges_for(constraint : VersionConstraint) : Array(Range)
      return [] of Range if constraint.empty?

      case constraint
      when Union then constraint.ranges
      when Range then [constraint]
      else            raise ArgumentError.new "Unknown VersionConstraint type #{constraint.class}"
      end
    end
  end
end
