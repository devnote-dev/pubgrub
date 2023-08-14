module PubGrub
  class Version
    class Empty < Constraint
      def any? : Bool
        false
      end

      def empty? : Bool
        true
      end

      def allows?(version : Version) : Bool
        false
      end

      def allows_any?(other : Version::Constraint) : Bool
        false
      end

      def allows_all?(other : Version::Constraint) : Bool
        other.empty?
      end

      def intersect(other : Version::Constraint) : Version::Constraint
        self
      end

      def union(other : Version::Constraint) : Version::Constraint
        other
      end

      def difference(other : Version::Constraint) : Version::Constraint
        self
      end

      def to_s : String
        "(empty)"
      end
    end
  end
end
