module PubGrub
  abstract class Package
    abstract def name : String
    abstract def version : SemanticVersion

    def_equals name, version

    def root? : Bool
      version == 0
    end

    def to_s : String
      name
    end
  end

  class BasicPackage < Package
    def initialize(@name : String, version : String)
      @version = SemanticVersion.parse version
    end

    def name : String
      @name
    end

    def version : SemanticVersion
      @version
    end
  end
end
