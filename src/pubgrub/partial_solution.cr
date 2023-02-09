module PubGrub
  class PartialSolution
    getter assignments : Array(Assignment)
    getter decisions
    getter attempted_solutions
    getter backtracking : Bool
    getter relation_cache
    getter terms

    def initialize
      reset!

      @attempted_solutions = 1
      @backtracking = false
    end

    def decision_level : Int32
      @decisions.size
    end

    def relation(term : Term)
      package = term.package
      return :overlap unless @terms.has_key? package

      @relation_cache[package][term] ||= @terms[package].relation(term)
    end

    def satisfies?(term : Term) : Bool
      relation(term) == :subset
    end

    def derive(term : Term, cause)
      add_assignment Assignment.new(term, cause, decision_level, @assignments.size)
    end

    def satisfier(term : Term)
      @assignments_by[term.package].bsearch do |assignment|
        @cumulative_assignments[assignment].satisfies?(term)
      end || raise "#{term} unsatisfied"
    end

    def unsatisfied
      @required
        .keys
        .reject { |key| @decisions.has_key? key }
        .map { |package| @terms[package] }
    end

    def decide(package : Package, version)
      @attempted_solutions += 1 if @backtracking
      @backtracking = false

      @decisions[package] = version
      add_assignment Assignment.decision(package, version, decision_level, @assignments.size)
    end

    def backtrack(previous_level)
      @backtracking = true

      new_assignments = @assignments.select &.decision_level.<= previous_level
      @decisions = @decisions.first previous_level

      reset!

      new_assignments.each ->add_assignment(Assignment)
    end

    private def reset!
      @assignments = [] of Assignment
      @assignments_by = Hash(Package, Array(Assignment)).new do |hash, key|
        hash[key] = [] of Assignment
      end
      @cumulative_assignments = {} of Assignment => Nil
      @decisions = {} of Package => Term
      @relation_cache = Hash(Package, Hash(Term, Relation)).new do |hash, key|
        hash[key] = {} of Term => Relation
      end
      @required = {} of Package => Bool
    end

    def add_assignment(assignment : Assignment)
      package = assignment.package

      @assignments << assignment
      @assignments_by[package] << assignment
      @required[package] = true if assignment.term.positive?

      if old_term = @terms[package]?
        @terms[package] = old_term.intersect assignment.term
      else
        @terms[package] = term
      end

      @relation_cache[package].clear
      @cumulative_assignments[assignment] = @terms[package]
    end
  end
end
