module PubGrub
  class Package
    getter name : String

    def self.root
      new "root"
    end

    def initialize(@name)
    end

    def root? : Bool
      @name == "root"
    end

    def ==(other : Package) : Bool
      @name == other.name
    end
  end
end
