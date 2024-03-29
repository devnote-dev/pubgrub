module PubGrub
  class VersionSolver
    Log = ::Log.for(self)

    @source : PackageSource
    @incompatibilities : Hash(String, Array(Incompatibility))
    @solution : PartialSolution

    def initialize(@source)
      @incompatibilities = Hash(String, Array(Incompatibility)).new do |hash, key|
        hash[key] = [] of Incompatibility
      end
      @solution = PartialSolution.new
    end

    def solve : SolverResult
      add [Term.new(Constraint.new(Package.root, Range.new), false)], Cause::Root.new

      time = Time.measure do
        loop do
          break unless package = choose_next_package
          propagate package
        end
      end

      Log.info { "Version solving took #{time.total_seconds.to_i} seconds." }
      Log.info { "Tried #{@solution.attempted} solutions." }

      SolverResult.new(@solution.decisions, @solution.attempted)
    end

    private def add(incomp : Incompatibility) : Nil
      Log.info { "fact: #{incomp.to_s}" }

      incomp.terms.each do |term|
        @incompatibilities[term.package.name] << incomp
      end
    end

    private def add(terms : Array(Term), cause : Cause) : Nil
      incomp = Incompatibility.new(terms, cause)

      Log.info { "fact: #{incomp.to_s}" }

      incomp.terms.each do |term|
        @incompatibilities[term.package.name] << incomp
      end
    end

    private def propagate(package : Package) : Nil
      changed = [package]

      until changed.empty?
        package = changed.pop

        @incompatibilities[package.name].reverse_each do |incomp|
          case result = propagate incomp
          in Package
            changed << result
          in Symbol
            next if result == :none

            root_cause = resolve_conflict incomp
            changed.clear
            changed << propagate(root_cause).as(Package)
          end
        end
      end
    end

    private def propagate(incomp : Incompatibility) : Package | Symbol
      unsatisfied : Term? = nil

      incomp.terms.size.times do |i|
        term = incomp.terms[i]
        case @solution.relation term
        when .disjoint?
          return :none
        when .overlapping?
          return :none if unsatisfied.nil?
          unsatisfied = term
        end
      end

      return :conflict if unsatisfied.nil?

      Log.info { "derived: #{unsatisfied.inverse}" }
      @solution.derive unsatisfied.constraint, !unsatisfied.positive?, incomp

      unsatisfied.package
    end

    private def resolve_conflict(incomp : Incompatibility) : Incompatibility
      new_incomp = false

      until incomp.failure?
        most_recent_term : Term? = nil
        most_recent_satisfier : Assignment? = nil
        difference : Term? = nil
        previous_satisfier_level = 1

        incomp.terms.each do |term|
          satisfier = @solution.satisfier term
          if most_recent_satisfier.nil?
            most_recent_term = term
            most_recent_satisfier = satisfier
          elsif most_recent_satisfier.index < satisfier.index
            previous_satisfier_level = Math.max(previous_satisfier_level, most_recent_satisfier.decision_level)
            most_recent_term = term
            most_recent_satisfier = satisfier
            difference = nil
          else
            previous_satisfier_level = Math.max(previous_satisfier_level, satisfier.decision_level)
          end

          if most_recent_term == term
            # TODO: make sure not nil
            difference = most_recent_satisfier.difference most_recent_term.as(Term)
            if difference
              previous_satisfier_level = Math.max(previous_satisfier_level, @solution.satisfier(difference.inverse).decision_level)
            end
          end
        end

        thing = most_recent_satisfier.try(&.decision_level)
        # TODO: don't typecast
        if previous_satisfier_level < (thing.nil? ? 0 : thing) || most_recent_satisfier.as(Assignment).cause.nil?
          @solution.backtrack previous_satisfier_level
          add incomp if new_incomp
          return incomp
        end

        new_terms = incomp.terms.reject { |t| t == most_recent_term }
        most_recent_satisfier.try do |satisfier|
          satisfier.cause.try do |cause|
            new_terms += cause.terms.reject { |t| t.package == satisfier.package }
          end
        end

        new_terms << difference.inverse if difference
        incomp = Incompatibility.new(
          new_terms,
          # TODO: don't typecast
          Cause::Conflict.new(incomp, most_recent_satisfier.as(Assignment).cause.as(Incompatibility))
        )
        new_incomp = true

        partially = difference ? " partially" : ""
        Log.info { "! #{most_recent_term} is#{partially} satisfied by #{most_recent_satisfier}" }
        Log.info { "! which is caused by #{most_recent_satisfier.as(Assignment).cause}" }
        Log.info { "! thus: #{incomp}" }
      end

      raise SolverFailure.new incomp
    end

    private def choose_next_package : Package?
      return nil unless term = next_term_to_try

      versions = @source.versions_for term.package, term.constraint.constraint
      add([term], Cause::NoVersions.new(term.constraint)) if versions.empty?

      version = versions[0]
      conflict = false

      @source.incompatibilities_for(term.package, version).each do |incomp|
        add incomp

        conflict = conflict || incomp.terms.all? do |iterm|
          iterm.package == term.package || @solution.satisfies?(iterm)
        end
      end

      unless conflict
        @solution.decide term.constraint
        Log.info { "selecting #{term} (#{version})" }
      end

      term.package
    end

    private def next_term_to_try : Term?
      unsatisfied = @solution.unsatisfied
      Log.debug { "unsatisfied: #{unsatisfied}" }

      case unsatisfied.size
      when 0
        nil
      when 1
        unsatisfied[0]
      else
        unsatisfied.min_by do |term|
          versions = @source.versions_for term.package, term.constraint.constraint
          dependencies = if versions.empty?
                           [] of Void
                         else
                           @source.dependencies_for term.package, versions[0]
                         end

          {versions.size, dependencies.size}
        end
      end
    end
  end

  class SolverResult
    getter decisions : Array(Package)
    getter attempts : Int32

    def initialize(@decisions, @attempts)
    end
  end
end
