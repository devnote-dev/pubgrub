module PubGrub
  abstract class Source
    getter name : String
    getter? has_multiple_versions : Bool

    abstract def parse(name : String, version : Version) : Package
    abstract def get_versions(package : Package) : Array(Package)
    abstract def get_directory(package : Package) : String

    def to_s : String
      @name
    end
  end
end
