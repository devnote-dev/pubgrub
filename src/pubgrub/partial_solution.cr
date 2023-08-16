module PubGrub
  class PartialSolution
    @assignments : Array(Assignment)
    @decisions : Hash(String, Package)
    @positive : Hash(String, Term?)
    @negative : Hash(String, Hash(Package, Term))
    @backtracking : Bool
    getter attempted : Int32

    def initialize
      @assignments = [] of Assignment
      @decisions = {} of String => Package
      @positive = {} of String => Term?
      @negative = Hash(String, Hash(Package, Term)).new do |hash, key|
        hash[key] = {} of Package => Term
      end
      @backtracking = false
      @attempted = 1
    end

    def decisions : Array(Package)
      @decisions.values
    end

    def unsatisfied : Array(Term)
      @positive
        .values
        .compact
        .reject { |t| @decisions.has_key? t.package.name }
    end

    def decision_level : Int32
      @decisions.size
    end

    def decide(constraint : Constraint) : Nil
      @attempted += 1 if @backtracking
      @backtracking = false
      @decisions[constraint.package.name] = constraint.package

      assign Assignment.decision(constraint, @decisions.size, @assignments.size)
    end

    def derive(constraint : Constraint, positive : Bool, cause : Incompatibility) : Nil
      assign Assignment.new(constraint, positive, @decisions.size, @assignments.size, cause)
    end

    def backtrack(decision_level : Int32) : Nil
      @backtracking = true
      packages = [] of String

      while @assignments.last.decision_level > decision_level
        removed = @assignments.pop
        packages << removed.package.name
        @decisions.delete removed.package.name if removed.decision?
      end

      packages.each do |package|
        @positive.delete package
        @negative.delete package
      end

      @assignments.each do |assignment|
        register assignment if packages.includes? assignment.package.name
      end
    end

    def satisfier(term : Term) : Assignment
      assigned : Term? = nil

      @assignments.each do |assignment|
        next unless assignment.package.name == term.package.name

        if !assignment.package.root? && assignment.package != term.package
          next unless assignment.positive?
          return assignment
        end

        assigned = assigned.nil? ? assignment : assigned.intersect(assignment)
        return assignment if assigned.try &.satisfies? term
      end
      raise "TODO: don't return nil"
    end

    def satisfies?(term : Term) : Bool
      relation(term).subset?
    end

    def relation(term : Term) : Relation
      positive = @positive[term.package.name]?
      return positive.relation(term) if positive

      return Relation::Overlapping unless by_ref = @negative[term.package.name]?
      return Relation::Overlapping unless negative = by_ref[term.package.name]?

      negative.relation term
    end

    private def assign(assignment : Assignment) : Nil
      @assignments << assignment
      register assignment
    end

    private def register(assignment : Assignment) : Nil
      name = assignment.package.name
      if old_positive = @positive[name]?
        @positive[name] = old_positive.intersect assignment
        return
      end

      ref = assignment.package
      negative_by_ref = @negative[name]?
      old_negative = negative_by_ref.try &.[ref]?
      term = old_negative ? assignment.intersect(old_negative) : assignment

      if term.positive?
        @negative.delete name
        @positive[name] = term
      else
        @negative[name][ref] = term
      end
    end
  end
end
