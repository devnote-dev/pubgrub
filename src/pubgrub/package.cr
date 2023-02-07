module PubGrub
  class Package
    ROOT = Package.new "root"
    ROOT_VERSION = 0

    getter name : String

    def self.root?(package : Package) : Bool
      if package.responds_to? :root
        package.root?
      else
        ROOT == package
      end
    end

    def initialize(@name : String)
    end

    def to_s : String
      @name
    end
  end
end
