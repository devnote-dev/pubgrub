module PubGrub
  class PartialSolution
    getter assignments : Array(Assignment)
    getter terms : Hash(Package, Hash(Term, Relation))
    getter relations : Hash(Package, Term)
    getter decisions : Array(Cause)
    getter attempts : Int32
    getter? backtracking : Bool

    def initialize
      @terms = Hash(Package, Hash(Term, Relation)).new
      @relations = {} of Package => Term
      @attempts = 1
      @backtracking = false
    end

    def decision_level : Int32
      @decisions.size
    end

    def relation(term : Term) : Relation
      package = term.package
      return :overlap if @terms.has_key? package

      @relations[package][term] ||= @terms[package].relation(term)
    end

    def satisfies?(term : Term) : Bool
      relation(term).subset?
    end

    def derive(term : Term, cause : Cause) : Assignment
      add Assignment.new(term, cause, decision_level, @assignments.size)
    end

    def satisfier(term : Term) : Assignment
      @assignments_by[term.package].bsearch do |assignment|
        @cumulative[assignment].satisfies?(term)
      end || raise "#{term} unsatisfied"
    end

    def unsatisfied : Array(Term)
      @required.keys.reject do |package|
        @decisions.has_key? package
      end.map do |package|
        @terms[package]
      end
    end

    def decide(package : Package, version : Int32) : Nil
      @attempts += 1 if @backtracking
      @backtracking = false

      decisions[package] = version
      add Assignment.new(package, version, decision_level, assignments.size)
    end

    def backtrack
      @backtracking = true

      new_assignments = @assignments.select &.decision_level.<= previous_level
      new_decisions = @decisions.first previous_level

      # whatever this means from Ruby:
      # new_decisions = Hash[decisions.first(previous_level)]

      reset!

      @decisions = new_decisions
      new_assignments.each { |a| add a }
    end

    private def reset! : Nil
      @assignments = [] of Assignment
      @assignments_by = Hash(Package, Array(Assignment)).new do |hash, key|
        hash[key] = [] of Assignment
      end

      @cumulative = {} of Package => Version
      @terms = {} of Package => Term
      @relations = Hash(Package, Hash(Package, Term)).new do |hash, key|
        hash[key] = {} of Package => Term
      end

      @required = {} of Package => Bool
    end

    private def add(assignment : Assignment) : Nil
      term = assignment.term
      package = term.package

      @assignments << assignment
      @assignments_by[package] << assignment
      @required[package] = true if term.positive?

      if @terms.has_key? package
        old_term = @terms[package]
        @terms[package] = old_term & term # TODO: interset
      else
        @terms[package] = term
      end

      @relations[package].clear
      @cumulative[assignment] = @terms[package]
    end
  end
end
