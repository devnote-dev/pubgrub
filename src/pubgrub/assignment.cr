module PubGrub
  class Assignment < Term
    getter decision_level : Int32
    getter index : Int32
    getter cause : Incompatibility?

    def initialize(package : Package, positive : Bool, @cause : Cause?, @decision_level : Int32, @index : Int32)
      super package, positive
    end

    def self.decision(package : Package, decision_level : Int32, index : Int32)
      new package, true, nil, decision_level, index
    end

    def self.derivation(package : Package, positive : Bool, cause : Cause?, decision_level : Int32, index : Int32)
      new package, positive, cause, decision_level, index
    end

    def decision? : Bool
      @cause.nil?
    end
  end
end
