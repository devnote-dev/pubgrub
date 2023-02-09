module PubGrub::Shards
  extend self

  def requirement_to_range(req) : VersionRange
    ranges = req.requiments.map do |(op, version)|
      case op
      when "~>"
        VersionRange.new(
          version,
          version.class.new(version.bump.to_s + ".A"),
          include_min: true,
          name: "~> #{version}"
        )
      when ">"
        VersionRange.new min: version
      when ">="
        VersionRange.new min: version, include_min: true
      when "<"
        VersionRange.new max: version
      when "<="
        VersionRange.new max: version, include_max: true
      when "="
        VersionRange.new min: version, max: version, include_min: true, include_max: true
      when "!="
        VersionRange.new(min: version, max: version, include_min: true, include_max: true).invert
      else
        raise "bad version specifier '#{op}'"
      end
    end

    ranges.reduce &.intersect
  end

  def requirement_to_constraint(package : Package, requirement)
    VersionConstraint.new package, requirement_to_range(requirement)
  end

  # def parse_range(dep)
  # def parse_constraint(package, dep)
end
