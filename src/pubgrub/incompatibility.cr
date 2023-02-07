module PubGrub
  class Incompatibility
    getter cause
    getter terms : Array(Term)
    getter custom_explanation : String?

    def initialize(@terms : Array(Term), @cause, @custom_explanation : String? = nil)
      if cause == :dependency && terms.size != 2
        raise ArgumentError.new "A dependency incompatibility must have exactly two terms; got #{terms.size}"
      end
    end

    def failure? : Bool
      @terms.empty? || (terms.size == 1 && Package.root?(terms[0].package) && terms[0].positive?)
    end

    def conflict? : Bool
      @cause == ConflictCause
    end

    def external_incompatibilities : Array(Incompatibility)
      if conflict?
        [
          @cause.conflict,
          @cause.other,
        ].flat_map &.external_incompatibilities
      else
        [self]
      end
    end

    def to_s : String
      return @custom_explanation if @custom_explanation

      case @cause
      when :root
        "(root dependency)"
      when :dependency
        "#{@terms.first.to_s(allow_every: true)} depends on #{@terms[1].invert}"
      when InvalidDependency
        "#{@terms.first.to_s(allow_every: true)} depends on unknown package #{@cause.package}"
      when NoVersions
        "no versions satisfy #{@cause.constraint}"
      when ConflictCause
        if failure?
          "version solving has failed"
        elsif @terms.size == 1
          if @terms.first.positive?
            "#{@terms.first.to_s(allow_every: true)} is forbidden"
          else
            "#{@terms.first.invert} is required"
          end
        else
          if @terms.all? &.positive?
            if @terms.size == 2
              "#{@terms.first.to_s(allow_every: true)} is incompatible with #{@terms[1]}"
            else
              "one of #{@terms.map(&.to_s).join(" or ")} must be false"
            end
          elsif @terms.all? &.negative?
            if @terms.length == 2
              "either #{@terms.first.invert} or #{terms[1].invert}"
            else
              "one of #{terms.map(&.invert).join(" or ")} must be true"
            end
          else
            positive = @terms.select &.positive?
            negative = @terms.select(&.negative?).map(&.invert)

            if positive.size == 1
              "#{positive.first.to_s(allow_every: true)} requires #{negative.join(" or ")}"
            else
              "if #{positive.join(" and ")} then #{negative.join(" or ")}"
            end
          end
        end
      else
        raise "unhandled cause: #{@cause}"
      end
    end

    private def cleanp_terms(terms : Array(Term)) : Array(Term)
      if terms.size != 1 && @cause == ConflictCause
        terms.reject! { |t| t.positive? && Package.root?(t.package) }
      end

      return terms if terms.size <= 1
      return terms if terms.size == 2 && terms.first.package != terms[1].package

      terms.group_by(&.package).map do |_, common_terms|
        common_terms.reduce do |acc, term|
          acc.intersect term
        end
      end
    end

    struct ConflictCause
      getter conflict
      getter other

      def initialize(@conflict, @other)
      end
    end

    struct InvalidDependency
      getter package : Package
      getter constraint : VersionConstraint

      def initialize(@package, @constraint)
      end
    end

    struct NoVersions
      getter constraint : VersionConstraint

      def initialize(@constraint)
      end
    end
  end
end
