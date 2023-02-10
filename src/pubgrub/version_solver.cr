module PubGrub
  class VersionSolver
    getter source
    getter solution : PartialSolution
    getter incompatibilities : Hash(Package, Array(Incompatibility)) do |hash, key|
      hash[key] = [] of Incompatibility
    end
    getter seen_incompatibilities : Hash(Package, Incompatibility)

    def initialize(@source, root : Package)
      add_incompatibility Incompatibility.new([Term.new(VersionConstraint.any(root))], false)
      propogate root
    end

    def solved? : Bool
      @solution.unsatisfied.empty?
    end

    def work : Bool
      return false if solved?

      next_package = choose_package_version
      propogate next_package

      if solved?
        Log.info { "Solution found after #{@solution.attempted_solutions} attempts:" }
        @solution.decisions.each do |package, version|
          next if Package.root? package
          Log.info { "* #{package} #{version}" }
        end

        false
      else
        true
      end
    end

    def solve
      until solved?
        work
      end

      @solution.decisions
    end

    private def propogate(initial : Package) : Nil
      changed = [initial] of Package

      while package = changed.shift?
        @incompatibilities[package].reverse_each do |incompatibility|
          result = propogate_incompatibility incompatibility
          if result == :conflict
            root_cause = resolve_conflict incompatibility
            changed.clear
            changed << propogate_incompatibility root_cause
          elsif result
            changed << result
          end
        end

        changed.uniq!
      end
    end

    private def propogate_incompatibility(incompatibility : Incompatibility) : Package
      unsatisfied = nil

      incompatibility.terms.each do |term|
        relation = @solution.relation term
        if relation == :disjoint
          return nil
        elsif relation == :overlap
          return nil if unsatisfied
          unsatisfied = term
        end
      end

      return :conflict unless unsatisfied

      Log.debug { "derived: #{unsatisfied.invert}" }
      @solution.derive unsatisfied.invert, incompatibility

      unsatisfied.package
    end

    private def next_package_to_try : Package?
      @solution.unsatisfied.min_by do |term|
        package = term.package
        range = term.constraint.range
        matching_versions = @source.versions_for package, range
        higher_versions = @source.versions_for package, range.upper_invert

        {matching_versions.size <= 1 ? 0 : 1, higher_versions.size}
      end.package
    end

    private def choose_package_version
      if @solution.unsatisfied.empty?
        Log.info { "No packages unsatisfied; solving complete!" }
        return nil
      end

      package = next_package_to_try
      unsatisfied_term = @solution.unsatisfied.find &.package.== package
      version = @source.version_for(package, unsatisfied_term.constraint.range).first

      Log.debug { "attempting #{package} #{version}" }

      if version.nil?
        add_incompatibility @source.no_versions_incompatibility_for(package, unsatisfied_term)
        return package
      end

      conflict = false

      @source.incompatibilities_for(package, version).each do |incompatibility|
        if @seen_incompatibilities.includes? incompatibility
          Log.debug { "knew: #{incompatibility}" }
          next
        end

        @seen_incompatibilities[incompatibility] = true
        add_incompatibility incompatibility

        conflict ||= incompatibility.terms.all? do |term|
          term.package == package || @solution.satisfies? term
        end
      end

      if conflict
        Log.info { "conflict: #{conflict}" }
      else
        Log.info { "selected #{package} #{version}" }

        @solution.decide package, version
      end

      package
    end

    private def resolve_conflict(incompatibility : Incompatibility)
      Log.info { "conflict: #{incompatibility}" }

      new_incompatibility = false

      until incompatibility.failure?
        most_recent_term = nil
        most_recent_satisfier = nil
        difference = nil
        previous_level = 1

        incompatibility.terms.each do |term|
          satisfier = @solution.satisfier term

          if most_recent_satisfier.nil?
            most_recent_term = term
            most_recent_satisfier = satisfier
          elsif most_recent_satisfier.index < satisfier.index
            previous_level = [previous_level, most_recent_satisfier.decision_level].max
            most_recent_term = term
            most_recent_satisfier = satisfier
            difference = nil
          else
            previous_level = [previous_level, most_recent_satisfier.decision_level].max
          end

          if most_recent_term == term
            difference = most_recent_satisfier.term.difference most_recent_term
            if difference.empty?
              difference = nil
            else
              difference_satisfier = @solution.satisfier difference.inverse
              previous_level = [previous_level, difference_satisfier.decision_level].max
            end
          end
        end

        if previous_level < most_recent_satisfier.decision_level || most_recent_satisfier.decision?
          Log.info { "backtracking to #{previous_level}" }

          @solution.backtrack previous_level
          if new_incompatibility
            add_incompatibility incompatibility
          end

          return incompatibility
        end

        new_terms = incompatibility.terms - [most_recent_term]
        new_terms += most_recent_satisfier.cause.terms.reject do |term|
          term.package == most_recent_satisfier.term.package
        end

        if difference
          new_terms << difference.invert
        end

        incompatibility = Incompatibility.new(
          new_terms,
          Incompatibility::ConflictCause.new(incompatibility, most_recent_satisfier.cause)
        )
        new_incompatibility = true

        partially = difference ? " partially" : ""
        Log.info do |entry|
          entry.emit "! #{most_recent_term} is#{partially} satisfied by #{most_recent_satisfier.term}"
          entry.emit "! which is caused by #{most_recent_satisfier.cause}"
          entry.emit "! thus #{incompatibility}"
        end
      end

      raise SolveFailure.new incompatibility
    end

    private def add_incompatibility(incompatibility : Incompatibility) : Nil
      Log.debug { "fact: #{incompatibility}" }
      incompatibility.terms.each do |term|
        @incompatibilities[term.package] << incompatibility
      end
    end
  end
end
