module PubGrub
  class Assignment < Term
    getter decision_level : Int32
    getter index : Int32
    getter cause : Incompatibility?

    def self.decision(constraint : Constraint, decision_level : Int32, index : Int32)
      new constraint, true, decision_level, index, nil
    end

    def initialize(constraint : Constraint, positive : Bool, @decision_level : Int32, @index : Int32, @cause : Cause?)
      super constraint, positive
    end

    def decision? : Bool
      @cause.nil?
    end
  end
end
