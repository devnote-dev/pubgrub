module PubGrub::PackageSource
  abstract def root_version : Version
  abstract def versions_for(package : Package) : Array(Version)
  abstract def dependencies_for(package : Package, version : Version)
end
