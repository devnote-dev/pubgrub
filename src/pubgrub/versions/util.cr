module Version
  private def allows_higher?(first : Version::Range, second : Version::Range) : Bool
    return !second.max.nil? if first.max.nil?
    return false if second.max.nil?

    case first.max.as(Int32) <=> second.max.as(Int32)
    when  1 then true
    when -1 then false
    else         first.include_max? && !second.include_max?
    end
  end

  private def allows_lower?(first : Version::Range, second : Version::Range) : Bool
    return !second.min.nil? if first.min.nil?
    return false if second.min.nil?

    case first.min.as(Int32) <=> second.min.as(Int32)
    when  1 then false
    when -1 then true
    else         first.include_min? && !second.include_min?
    end
  end

  private def strictly_higher?(first : Version::Range, second : Version::Range) : Bool
    strictly_lower?(second, first)
  end

  private def strictly_lower?(first : Version::Range, second : Version::Range) : Bool
    return false if first.max.nil? || second.max.nil?

    case first.max.as(Int32) <=> second.min.as(Int32)
    when  1 then false
    when -1 then true
    else         !first.include_max? || !second.include_min?
    end
  end
end
