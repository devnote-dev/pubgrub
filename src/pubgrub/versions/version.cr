module PubGrub
  class Version
    @inner : SemanticVersion

    def self.parse(text : String)
      new SemanticVersion.parse text
    end

    def initialize(@inner)
    end
  end
end
