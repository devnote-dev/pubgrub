module PubGrub
  abstract struct Cause
    struct Root < Cause
    end

    struct Dependency < Cause
      getter depender : Package
      getter target : Package

      def initialize(@depender, @target)
      end
    end

    struct NoVersions < Cause
      getter constraint : Version::Constraint

      def initialize(@constraint : Version::Constraint)
      end
    end

    struct UnknownSource < Cause
    end

    struct Conflict < Cause
      getter conflict : Incompatibility
      getter other : Incompatibility

      def initialize(@conflict, @other)
      end
    end

    struct NotFound < Cause
      getter exception : Exception

      def initialize(@exception)
      end
    end

    struct Forbidden < Cause
      getter reason : String

      def initialize(@reason)
      end
    end
  end
end
