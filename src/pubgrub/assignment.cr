module PubGrub
  class Assignment
    getter term : Term
    getter cause : Cause
    getter decision_level
    getter index

    def initialize(@term : Term, @cause : Cause, @decision_level, @index)
    end

    def self.decision(package : Package, version : Int32, decision_level, index)
      term = Term.new(Version::Constraint.exact(package, version), true)
      new(term, Cause::Decision.new, decision_level, index)
    end
  end
end
