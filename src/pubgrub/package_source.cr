module PubGrub::PackageSource
  abstract def versions_for(package : Package, constraint : Version::Constraint) : Array(Version)
  abstract def dependencies_for(package : Package, version : Version) : Hash(String, String)
  abstract def incompatibilities_for(package : Package, version : Version) : Array(Incompatibility)
end
