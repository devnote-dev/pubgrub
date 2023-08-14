module PubGrub
  enum SolveType
    Get
    Upgrade
    Downgrade
  end

  class VersionSolver
    @incompatibilities : Hash(String, Array(Incompatibility))
    @solution : PartialSolution
    @listers : Hash(Package::Reference, PackageLister)
    @type : SolveType
    @root : Package
    @lock : Lockfile
    @overrides : Hash(String, Package::Range)
    @unlock : Set(String)

    def initialize(@type, @root, @lock, @unlock = Set(String).new, overrides = nil)
      @incompatibilities = Hash(String, Array(Incompatibility)).new do |hash, key|
        hash[key] = [] of Incompatibility
      end
      @solution = PartialSolution.new
      @overrides = overrides || {} of String => Package::Range
    end

    def solve : SolveResult
      add_incompatibility Incompatibility.new(
        [Term.new(Package::Range.root(@root), false)],
        Incompatibility::Cause::Root.new
      )

      time = Time.measure do
        next_package : String? = @root.name
        until next_package.nil?
          propagate next_package
          next_package = choose_package_version
        end
      end
      decisions = @solution.decisions

      SolveResult.new(decisions, get_available_versions(decisions), @attempted, time)
    ensure
      # TODO: change to logger
      puts "Version solving took #{time.total_seconds} seconds."
      puts "Tried #{@attempted} solutions."
    end

    private def propagate(package : String) : Nil
      changed = [package]

      until changed.empty?
        package = changed.first
        changed.delete package

        @incompatibilities[package].reverse_each do |incomp|
          case result = propagate incomp
          in String
            changed << result
          in Symbol
            next if result == :none

            root = resolve_conflict incomp
            changed.clear
            changed << propagate(root).as(String)
            break
          end
        end
      end
    end

    private def propagate(incomp : Incompatibility) : String | Symbol
      unsatisfied : Term? = nil

      incomp.terms.size.times do |i|
        term = incomp.terms[i]
        case @solution.relation term
        when .disjoint?
          return :none
        when .overlapping?
          return :none if unsatisfied.nil?
          unsatisfied = term
        end
      end

      return :conflict if unsatisfied.nil?
      @solution.derive unsatisfied.package, !unsatisfied.positive?, incomp

      unsatisfied.package.name
    end

    private def resolve_conflict(incomp : Incompatibility) : Incompatibility
      new_incomp = false

      until incomp.failure?
        most_recent_term : Term? = nil
        most_recent_satisfier : Assignment? = nil
        difference : Term? = nil
        previous_satisfier_level = 1

        incomp.terms.each do |term|
          satisfier = @solution.satisfier term
          if most_recent_satisfier.nil?
            most_recent_term = term
            most_recent_satisfier = satisfier
          elsif most_recent_satisfier.index < satisfier.index
            previous_satisfier_level = Math.max(previous_satisfier_level, most_recent_satisfier.decision_level)
            most_recent_term = term
            most_recent_satisfier = satisfier
            difference = nil
          else
            previous_satisfier_level = Math.max(previous_satisfier_level, satisfier.decision_level)
          end

          if most_recent_term == term
            difference = most_recent_satisfier.difference most_recent_term
            if difference
              previous_satisfier_level = Math.max(previous_satisfier_level, @solution.satisfier(difference.inverse).decision_level)
            end
          end
        end

        if previous_satisfier_level < most_recent_satisfier.try(&.decision_level) || most_recent_satisfier.cause.nil?
          @solution.backtrack previous_satisfier_level
          add_incompatibility incomp if new_incomp
          return incomp
        end

        new_terms = incomp.terms.reject { |t| t == most_recent_term }
        most_recent_satisfier.try do |satisfier|
          satisfier.cause.try do |terms|
            new_terms += terms.reject { |t| t.package == satisfier.package }
          end
        end

        new_terms << difference.inverse if difference
        incomp = Incompatibility.new(
          new_terms,
          Incompatibility::Cause::Conflict.new(incomp, most_recent_satisfier.cause)
        )
        new_incomp = true

        partially = difference ? " partially" : ""
        puts "! #{most_recent_term} is#{partially} satisfied by #{most_recent_satisfier}"
        puts "! which is caused by #{most_recent_satisfier.cause}"
        puts "! thus: #{incomp}"
      end

      # TODO: needs formatting
      # raise SolveFailure.new
      raise "SolveFailure"
    end

    private def choose_package_version : String?
      unsatisfied = @solution.unsatisfied
      return nil if unsatisfied.empty?

      unsatisfied.each do |candidate|
        next unless candidate.is_a? UnknownSource
        add_incompatibility Incompatibility.new(
          [Term.new(candidate.to_reference.with_constraint(Version::Constraint.any), true)],
          Incompatibility::Cause::UnknownSource.new
        )
        return candidate.name
      end

      package = unsatisfied.min_by do |package|
        package_lister(package).count_versions(package.constraint)
      end
      return nil if package.nil?

      version : Version? = nil
      begin
        version = package_lister(package).best_version(package.constraint)
      rescue ex : PackageLister::NotFoundError
        add_incompatibility Incompatibility.new(
          [Term.new(package.to_reference.with_constraint(Version::Constraint.any), true)],
          Incompatibility::Cause::NotFound.new(ex)
        )
        return package.name
      end

      if version.nil?
        if exclude_single_version? package.constraint
          version = package_lister(package).best_version(Version::Constraint.any)
        else
          add_incompatibility Incompatibility.new(
            [Term.new(package, true)],
            Incompatibility::Cause::NoVersions.new
          )
          return package.name
        end
      end

      conflict = false
      package_lister(package).incompatibilities_for(version).each do |incomp|
        add_incompatibility incomp
        conflict = conflict || incomp.terms.every? do |term|
          term.package.name == package.name || @solution.satisfies?(term)
        end
      end

      unless confict
        @solution.decide version
        puts "selecting #{version}"
      end

      package.name
    end

    private def add_incompatibility(incomp : Incompatibility) : Nil
      incomp.terms.each do |term|
        @incompatibilities[term.package.name] << incomp
      end
    end

    private def exclude_single_version?(constraint : Version::Constraint) : Bool
      Version::Constraint.any.difference(constraint).is_a? Version
    end

    private def get_available_versions(packages : Array(Package::ID)) : Hash(String, Array(Version))
      available = Hash(String, Array(Version)).new

      # TODO: this is not it
      packages.each do |package|
        ids = [package]
      end

      available
    end
  end

  class SolveResult
    getter packages : Array(Package::ID)
    getter versions : Hash(String, Array(Version))
    getter attempted : Int32
    getter resolution_time : Time
  end
end
