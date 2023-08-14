module PubGrub
  class Incompatibility
    getter terms : Array(Term)
    getter cause : Cause

    def self.new(terms : Array(Term), cause : Cause)
      if terms.size != 1 && cause.is_a?(Cause::Conflict) && terms.any? { |t| t.positive? && t.package.root? }
        terms = terms.select { |t| !t.positive? || t.package.root? }
      end

      if terms.size == 1 || (terms.size == 2 && terms[0].package.name != terms[1].package.name)
        return new terms, cause
      end

      by_name = Hash(String, Hash(Package, Term)).new
      terms.each do |term|
        by_ref = by_name.put term.package.name { }
        ref = term.package.to_reference

        if by_ref.has_key? ref
          by_ref[ref] = by_ref[ref].intersect(term)
        else
          by_ref[ref] = term
        end
      end

      terms = by_name.flat_map do |by_ref|
        positive = by_ref.values.select &.positive?
        return positive unless positive.empty?

        by_ref.values
      end

      new terms, cause
    end

    def initialize(@terms, @cause)
    end

    def external(& : Incompatibility ->)
      if @cause.is_a? Cause::Conflict
        cause = @cause.as(Cause::Conflict)
        yield cause.conflict.external
        yield cause.other.external
      else
        yield self
      end
    end

    def to_s(details : Hash(String, Package::Detail)? = nil) : String
      if @cause.is_a? Cause::Dependency
        return "#{terse(@terms[0], details, true)} depends on #{terse(@terms[1], details)}"
      elsif @cause.is_a? Cause::NoVersions
        return "no versions of #{terse_ref(@terms[0], details)} match #{@terms[0].constraint}"
      elsif @cause.is_a? Cause::NotFound
        ex = @cause.as(Cause::NotFound).exception

        return "#{terse_ref(@terms[0], details)} doesn't exist (#{ex.message})"
      elsif @cause.is_a? Cause::UnknownSource
        return %(#{@terms[0].package.name} comes from an unknown source "#{@terms[0].package.source}")
      elsif @cause.is_a? Cause::Root
        return "#{@terms[0].package.name} is #{@terms[0].constraint}"
      elsif failure?
        return "version solving failed"
      end

      if @terms.size == 1
        term = @terms[0]
        if term.constraint.any?
          return "#{terse_ref(term, details)} is #{term.positive? ? "forbidden" : "required"}"
        else
          return "#{terse(term, details)} is #{term.positive? ? "forbidden" : "required"}"
        end
      end

      if @terms.size == 2
        term1, term2 = @terms
        if term1.positive? && term2.positive?
          if term1.positive?
            package1 = term1.constraint.any? ? terse_ref(term1, details) : terse(term1, details)
            package2 = term2.constraint.any? ? terse_ref(term2, details) : terse(term2, details)

            return "#{package1} is incompatible with #{package2}"
          else
            return "either #{terse(term1, details)} or #{terse(term2, details)}"
          end
        end
      end

      positive, negative = @terms.partition &.positive?
      positive.map! { |t| terse(t, details) }
      negative.map! { |t| terse(t, details) }

      if !positive.empty? && !negative.empty?
        if positive.size == 1
          term = @terms.find &.positive?

          "#{terse(term, details, true)} requires #{negative.join " or "}"
        else
          "if #{positive.join " and "} then #{negative.join " or "}"
        end
      elsif !positive.empty?
        "one of #{positive.join " or "} must be false"
      else
        "one of #{negative.join " or "} must be true"
      end
    end

    def and_to_s(other : Incompatibility, details : Hash(String, Package::Detail)? = nil, this_line : Int32? = nil, other_line : Int32? = nil) : String
      requires_both = try_requires_both other, details, this_line, other_line
      return requires_both if requires_both

      requires_through = try_requires_through other, details, this_line, other_line
      return requires_through if requires_through

      requires_forbidden = try_requires_forbidden other, details, this_line, other_line
      return requires_forbidden if requires_forbidden

      String.build do |io|
        io << to_s details
        if this_line
          io << ' ' << this_line
        end
        io << " and " << other.to_s details
        if other_line
          io << ' ' << other_line
        end
      end
    end

    private def try_requires_both(other : Incompatibility, details : Hash(String, Package::Detail)?, this_line : Int32? = nil, other_line : Int32? = nil) : String?
      return nil if @terms.size == 1 || other.terms.size == 1
      return nil unless this_positive = @terms.find &.positive?
      return nil unless other_positive = other.terms.find &.positive?
      return nil unless this_positive.package == other_positive.package

      this_negatives = @terms.reject(&.positive?).join(" or ") { |t| terse(t, details) }
      other_negatives = other.terms.reject(&.positive?).join(" or ") { |t| terse(t, details) }

      String.build do |io|
        io << terse(this_positive, details, true) << ' '
        if @cause.is_a?(Cause::Dependency) && other.cause.is_a?(Cause::Dependency)
          io << "depends on"
        else
          io << "requires"
        end

        io << " both " << this_negatives
        if this_line
          io << " (" << this_line << ')'
        end

        io << " and " << other_negatives
        if other_line
          io << " (" << other_line << ')'
        end
      end
    end

    private def try_requires_through(other : Incompatibility, details : Hash(String, Package::Detail)?, this_line : Int32?, other_line : Int32?) : String?
      return nil if @terms.size == 1 || other.terms.size == 1

      this_negative = @terms.find { |t| !t.positive? }
      other_negative = other.terms.find { |t| !t.positive? }
      return nil unless this_negative && other_negative

      this_positive = @terms.find &.positive?
      other_positive = other.terms.find &.positive?

      prior : Incompatibility
      prior_negative : Term
      prior_line : Int32? = nil

      latter : Incompatibility
      latter_line : Int32? = nil

      if !this_negative.nil? &&
         !other_positive.nil? &&
         this_negative.package.name == other_positive.package.name &&
         other_negative.inverse.satisfies?(this_positive)
        prior = self
        prior_negative = this_negative
        prior_line = this_line

        latter = other
        latter_line = other_line
      elsif !other_negative.nil? &&
            !this_positive.nil? &&
            other_negative.package.name == this_positive.package.name &&
            other_negative.inverse.satisfies?(this_positive)
        prior = other
        prior_negative = other_negative
        prior_line = other_line

        latter = self
        latter_line = this_line
      else
        return nil
      end

      prior_positives = prior.terms.select &.positive?

      String.build do |io|
        if prior_positives.size > 1
          prior_string = prior_positives.join(" or ") { |t| terse(t, details) }
          io << "if " << prior_string << " then "
        else
          verb = prior.cause.is_a?(Cause::Dependency) ? " depends on" : " requires"
          io << terse(prior_positives[0], details, true) << verb << ' '
        end

        io << terse prior_negative, details
        if prior_line
          io << " (" << prior_line << ')'
        end
        io << " which "

        if latter.cause.is_a? Cause::Dependency
          io << "depends on "
        else
          io << "requires "
        end

        io << latter.terms.reject(&.positive?).join(" or ") { |t| terse(t, details) }
        if latter_line
          io << " (" << latter_line << ')'
        end
      end
    end

    private def try_requires_forbidden(other : Incompatibility, details : Hash(String, Package::Detail)?, this_line : Int32?, other_line : Int32?) : String?
      return nil if @terms.size == 1 && other.terms.size == 1

      prior : Incompatibility
      latter : Incompatibility
      prior_line : Int32? = nil
      latter_line : Int32? = nil

      if @terms.size == 1
        prior = other
        latter = self
        prior_line = other_line
        latter_line = this_line
      else
        prior = self
        latter = other
        prior_line = this_line
        latter_line = other_line
      end

      return nil unless negative = prior.find { |t| !t.positive? }
      return nil unless negative.inverse.satisfies? latter.terms[0]

      positives = prior.terms.select &.positive?

      String.build do |io|
        if positives.size > 1
          prior_string = positives.join(" or ") { |t| terse(t, details) }
          io << "if " << prior_string << " then "
        else
          io << terse positives[0], details, true
          if prior.cause.is_a? Cause::Dependency
            io << " depends on "
          else
            io << " requires "
          end
        end

        if latter.cause.is_a? Cause::UnknownSource
          package = latter.terms[0].package
          io << package.name << ' '
          if prior_line
            io << '(' << prior_line << ") "
          end
          io << %(from unknown source ") << package.source << '"'
          if latter_line
            io << " (" << latter_line << ')'
          end
          return
        end

        io << terse latter.terms[0], details
        if prior_line
          io << '(' << prior_line << ") "
        end

        if latter.cause.is_a? Cause::NoVersions
          io << "which doesn't match any versions"
        elsif latter.cause.is_a? Cause::NotFound
          io << "which doesn't exist "
          io << latter.cause.as(Cause::NotFound).exception.message
        else
          io << "which is forbidden"
        end

        if latter_line
          io << " (" << latter_line << ')'
        end
      end
    end

    private def terse(term : Term, details : Hash(String, Package::Detail)?, every : Bool = false) : String
      if every && term.constraint.any?
        "every version of #{terse_ref(term, details)}"
      else
        term.package.to_s details.try &.[term.package.name]?
      end
    end

    private def terse_ref(term : Term, details : Hash(String, Package::Detail)?) : String
      term.package.to_reference.to_s details.try &.[term.package.name]?
    end
  end
end
