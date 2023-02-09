module PubGrub
  class SolveFailure < Exception
    getter incompatibility : Incompatibility
    getter explanation : String { FailureWriter.new(@incompatibility).write }

    def initialize(@incompatibility : Incompatibility)
      @message = "Could not find compatible versions\n\n#{explanation}"
    end

    def to_s : String
      @message
    end
  end
end
