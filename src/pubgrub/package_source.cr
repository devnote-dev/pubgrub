module PubGrub::PackageSource
  abstract def versions_for(package : Package, constraint : VersionConstraint) : Array(Version)
  abstract def dependencies_for(package : Package, version : VersionConstraint) : Hash(String, String)
  abstract def incompatibilities_for(package : Package, version : VersionConstraint) : Array(Incompatibility)
end
