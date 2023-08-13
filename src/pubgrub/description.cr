module PubGrub
  abstract class Description
    getter source : Source
  end

  class ResolvedDescription
    getter description : Description

    def initialize(@description)
    end

    def to_s : String
      @description.to_s
    end
  end
end
