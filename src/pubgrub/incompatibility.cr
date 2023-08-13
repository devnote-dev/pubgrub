module PubGrub
  abstract struct Cause
    struct Root < Cause
    end

    struct Decision < Cause
    end

    struct Dependency < Cause
    end

    struct Conflict < Cause
      getter incompatibility : Incompatibility
      getter satisfier : Incompatibility

      def initialize(@incompatibility : Incompatibility, @satisfier : Incompatibility)
      end
    end

    struct InvalidDependency < Cause
      getter package : Package
      getter constraint : Version::Constraint

      def initialize(@package : Package, @constraint : Version::Constraint)
      end
    end

    struct NoVersions < Cause
      getter constraint : Version::Constraint

      def initialize(@constraint : Version::Constraint)
      end
    end
  end

  class Incompatibility
    getter terms : Array(Term)
    getter cause : Cause
    @explanation : String?

    def_equals @terms, @cause

    def initialize(@terms : Array(Term), @cause : Cause, @explanation : String? = nil)
      if cause.dependency? && terms.size != 2
        raise ArgumentError.new "a dependency incompatibility must have exactly 2 terms; got #{terms.size}"
      end
    end

    def failure? : Bool
      @terms.empty? || (@terms.size == 1 && @terms.first.root? && @terms.first.positive?)
    end

    def to_s(io : IO) : Nil
      return @explanation if @explanation

      case cause = @cause
      when Cause::Root
        "(root dependency)"
      when Cause::Dependency
        "#{@terms[0].to_s(true)} depends on #{@terms[1].invert}"
      when Cause::InvalidDependency
        "#{@terms[0].to_s(true)} depends on unknown package #{cause.package}"
      when Cause::NoVersions
        "no versions satisfy #{cause.constraint}"
      when Cause::Conflict
        return "version solving has failed" if failure?

        if @terms.size == 1
          term = terms.first

          if term.positive?
            if term.constraint.any? # ameba:disable Performance/AnyInsteadOfEmpty
              "#{term.package} cannot be used"
            else
              "#{term.to_s(true)} cannot be used"
            end
          else
            "#{term.invert} is required"
          end
        else
          if @terms.all? &.positive?
            if @terms.size == 2
              "#{@terms[0].to_s(true)} is incompatible with #{@terms[1]}"
            else
              "one of #{@terms.map(&.to_s).join(" or ")} must be false"
            end
          elsif @terms.all? &.negative?
            if @terms.size == 2
              "either #{@terms[0].invert} or #{@terms[1].invert}"
            else
              "one of #{@terms.map(&.invert).join(" or ")} must be true"
            end
          else
            positive, negative = @terms.partition &.positive?
            negative.map! &.invert

            if positive.size == 1
              "#{positive[0].to_s(true)} requires #{negative.join(" or ")}"
            else
              "if #{positive.join(" and ")} then #{negative.join(" or ")}"
            end
          end
        end
      else
        raise "unknown cause: #{cause}"
      end
    end
  end
end
