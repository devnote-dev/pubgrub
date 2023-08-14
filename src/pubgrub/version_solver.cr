require "log"

module PubGrub
  class VersionSolver
    Log = ::Log.for(self)

    @source : PackageSource
    @incompatibilities : Hash(String, Array(Incompatibility))
    @solutuion : PartialSolution

    def initialize
      @incompatibilities = Hash(String, Array(Incompatibility)).new do |hash, key|
        hash[key] = [] of Incompatibility
      end
      @solution = PartialSolution.new
    end

    def solve : SolverResult
      add [Term.new(Version::Constraint.new(@source.root), false)], Cause::Root.new
      propagate @source.root

      time = Time.measure do
        loop do
          break unless package = choose_next_package
          propagate package
        end
      end

      Log.info { "Version solving took #{time.total_seconds} seconds." }
      Log.info { "Tried #{@solution.attempted} solutions." }

      SolverResult.new(@solution.decisions, @solution.attempted)
    end

    private def add(terms : Array(Term), cause : Cause) : Nil
      add Incompatibility.new terms, cause
    end

    private def add(incomp : Incompatibility) : Nil
      Log.info { "fact: #{incomp}" }

      incomp.terms.each do |term|
        @incompatibilities[term.package.name] << incomp
      end
    end

    private def propagate(package : String) : Nil
      changed = [package]

      until changed.empty?
        package = changed.pop

        @incompatibilities[package.name].reverse_each do |incomp|
          case result = propagate incomp
          in String
            changed << result
          in Symbol
            next if result == :none

            root_cause = resolve_conflict incomp
            changed.clear
            changed << propagate(root_cause).as(String)
          end
        end
      end
    end

    private def propagate(incomp : Incompatibility) : String | Symbol
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
      @solution.derive unsatisfied.package, !unsatisfied.positive?, incomp

      unsatisfied.package.name
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
            difference = most_recent_satisfier.difference most_recent_term
            if difference
              previous_satisfier_level = Math.max(previous_satisfier_level, @solution.satisfier(difference.inverse).decision_level)
            end
          end
        end

        if previous_satisfier_level < most_recent_satisfier.try(&.decision_level) || most_recent_satisfier.cause.nil?
          @solution.backtrack previous_satisfier_level
          add_incompatibility incomp if new_incomp
          return incomp
        end

        new_terms = incomp.terms.reject { |t| t == most_recent_term }
        most_recent_satisfier.try do |satisfier|
          satisfier.cause.try do |terms|
            new_terms += terms.reject { |t| t.package == satisfier.package }
          end
        end

        new_terms << difference.inverse if difference
        incomp = Incompatibility.new(
          new_terms,
          Incompatibility::Cause::Conflict.new(incomp, most_recent_satisfier.cause)
        )
        new_incomp = true

        partially = difference ? " partially" : ""
        Log.info { "! #{most_recent_term} is#{partially} satisfied by #{most_recent_satisfier}" }
        Log.info { "! which is caused by #{most_recent_satisfier.cause}" }
        Log.info { "! thus: #{incomp}" }
      end

      raise SolverFailure.new incomp
    end

    private def choose_next_package : String?
      return nil unless term = next_term_to_try

      versions = @source.versions_for term.package, term.constraint
      add([term], Cause::NoVersions.new) if versions.empty?

      version = versions[0]
      conflict = false

      @source.incompatibilities_for(term.package, version).each do |incomp|
        add incomp

        conflict = confict || incomp.terms.all? do |iterm|
          iterm.package == term.package || @solution.satisfies?(iterm)
        end
      end

      unless conflict
        @solution.decide term.package, version
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
          versions = @source.versions_for term.package, term.constraint
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
end
