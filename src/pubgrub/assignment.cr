module PubGrub
  class Assignment
    getter term : Term
    getter cause
    getter decision_level : Int32
    getter index

    def self.decision(package : Package, version : Version, decision_level : Int32, index) : Assignment
      term = Term.new(VersionConstraint.new(package, version), true)

      new term, :decision, decision_level, index
    end

    def initialize(@term : Term, @cause, @decision_level : Int32, @index)
    end

    def decision? : Bool
      @cause == :decision
    end
  end
end
