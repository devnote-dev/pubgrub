module PubGrub
  class VersionUnion
    getter ranges : Array(VersionRange)

    def_equals @ranges

    def self.normalize_ranges(ranges : Array(VersionRange)) : Array(VersionRange)
      total_ranges = ranges.flat_map &.ranges
      total_ranges.reject! &.empty?

      return [] of VersionRange if total_ranges.empty?

      mins, maxes = total_ranges.partition &.min.nil?
      originals = mins + maxes.sort_by { |r| [r.min, r.include_min ? 0 : 1] }
      normalized = [originals.shift]

      originals.each do |range|
        if ranges.last.contiguous_to? range
          normalized << ranges.pop.span(range)
        else
          normalized << range
        end
      end

      normalized
    end

    def self.union(ranges : Enumerable(VersionRange), normalize : Bool = true) : VersionRange
      ranges = normalize_ranges(ranges) if normalize

      if ranges.empty?
        VersionRange.empty
      elsif ranges.size == 1
        ranges.first
      else
        new ranges
      end
    end

    def initialize(@ranges : Array(VersionRange))
    end

    def includes?(version : Int32) : Bool
      @ranges.bsearch(&.compare_version version).nil?
    end

    def select_versions(versions : Enumerable(Int32)) : Array(VersionRange)
      selected = [] of VersionRange
      ranges.reduce(versions) do |acc, range|
        _, matching, higher = range.partition_versions(acc)
        selected.concat matching
        higher
      end

      selected
    end

    def intersects?(other : VersionUnion) : Bool
      my_ranges = @ranges.dup
      other_ranges = other.ranges.dup
      my_range = my_ranges.shift?
      other_range = other_ranges.shift?

      while my_ranges && other_range
        return true if my_range.intersects? other_range

        if my_range.max.nil? || other_range.empty? || (other_range.max && other_range.max < my_range.max)
          other_range = other_ranges.shift?
        else
          my_range = my_ranges.shift?
        end
      end
    end

    def allows_any?(other : VersionUnion) : Bool
      intersects? other
    end

    def allows_all?(other : VersionUnion) : Bool
      my_ranges = @ranges.dup
      my_range = my_ranges.shift?

      other.ranges.all? do |range|
        while my_range
          break if my_range.allows_all? range
          my_range = my_ranges.shift?
        end
      end

      my_range.nil?
    end

    def empty? : Bool
      false
    end

    def any? : Bool
      false
    end

    def intersect(other : VersionUnion) : VersionUnion
      my_ranges = @ranges.dup
      other_ranges = other.ranges.dup
      my_range = my_ranges.shift?
      other_range = other_ranges.shift?
      new_ranges = [] of VersionRange

      while my_range && other_range
        new_ranges << my_range.intersect other_range

        if my_range.max.nil? || other_range.empty? || (other_range.max && other_range.max < my_range.max)
          other_range = other_ranges.shift?
        else
          my_range = my_ranges.shift?
        end
      end

      new_ranges.reject! &.empty?
      VersionUnion.union(new_ranges, false)
    end

    def upper_invert : VersionRange
      @ranges.last.upper_invert
    end

    def invert : Array(VersionRange)
      @ranges.map(&.invert).reduce(&.intersect)
    end

    def union(other : VersionUnion) : VersionUnion
      VersionUnion.union [self, other]
    end

    def to_s : String
      arr = [] of String
      ranges = @ranges.dup

      until ranges.empty?
        ne = [] of Int32
        range = ranges.shift

        while !ranges.empty? && ranges.first.min.to_s == range.max.to_s
          ne << range.max
          range = range.span(ranges.shift)
        end

        if ne.empty?
          arr << range.to_s
        elsif range.any? # ameba:disable Performance/AnyInsteadOfEmpty
          arr << ne.map { |x| "!= #{x}" }.join(", ")
        else
          arr << "#{range}, " + ne.map { |x| "!= #{x}" }.join(", ")
        end
      end

      arr.join " OR "
    end
  end
end
