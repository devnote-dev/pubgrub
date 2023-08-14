module PubGrub
  class Assignment < Term
    getter decision_level : Int32
    getter index : Int32
    getter cause : Incompatibility?

    def self.decision(package : Package, decision_level : Int32, index : Int32)
      new package, true, decision_level, index
    end

    def initialize(package : Package, positive : Bool, @decision_level : Int32, @index : Int32, @cause : Cause?)
      super package, positive
    end

    def decision? : Bool
      @cause.nil?
    end
  end
end
