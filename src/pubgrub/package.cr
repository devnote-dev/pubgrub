module PubGrub
  class Package
    getter name : String

    def initialize(@name)
    end

    def ==(other : Package) : Bool
      @name == other.name
    end
  end
end
