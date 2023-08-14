module PubGrub
  class PackageLister
    getter reference : Package::Reference
    getter overrides : Hash(String, Version)

    def self.root(package : Package)
      new Package::Reference.root(package)
    end

    def initialize(@reference, overrides = nil)
      @overrides = overrides || {} of String => Version
    end

    def count_versions(constraint : Version::Constraint) : Int32
      #
    end
  end
end
