module PubGrub
  class Version
    include Constraint

    VERSION_REGEX = /^(\d+)\.(\d+)\.(\d+)(-([0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*))?(\+([0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*))?/
    STRICT_REGEX = MATCH_REGEX + /$/
    CONSTRAINT_REGEX = /^[<>]=?/
  end
end

require "./versions/*"