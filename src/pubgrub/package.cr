module PubGrub
  class Package
    getter name : String
    getter version : Version
    getter dependencies : Hash(String, Range)
    getter dev_dependencies : Hash(String, Range)
    getter overrides : Hash(String, Range)

    def initialize(@name, @version, dependencies = nil, dev_dependencies = nil, overrides = nil)
      @dependencies = dependencies || {} of String => Range
      @dev_dependencies = dev_dependencies || {} of String => Range
      @overrides = overrides || {} of String => Range
    end

    def immediate_dependencies : Hash(String, Range)
      @dependencies.merge(@dev_dependencies).merge(@overrides)
    end

    @[Flags]
    enum Detail
      Version
      Source
      Description
    end

    class Reference
      getter name : String
      getter description : Description
      getter? root : Bool
      getter source : Source

      def self.root(package : Package)
        new package.name, RootDescription.new(package)
      end

      def self.with_constraint(constriaint : Version::Constraint)
        Range.new self, constriaint
      end

      def initialize(@name, @description)
        @root = description.is_a? RootDescription
        @source = description.source
      end

      def to_s(detail : Detail = :none) : String
        return @name if @root

        String.build do |io|
          io << @name
          if detail.version? || !@root
            io << ' ' << @version
          end

          if !@root && (detail.source? || !@description.is_a? ResolvedHostedDescription)
            io << " from " << @description.description.source
            if detail.description?
              io << ' '
              @description.to_s io
            end
          end
        end
      end
    end

    class ID
      getter name : String
      getter version : Version
      getter description : ResolvedDescription
      getter? root : Bool
      getter source : Source

      def self.root(package : Package)
        new package.name, package.version, ResolvedRootDescription.new(RootDescription.new(package))
      end

      def initialize(@name, @version, @description)
        @root = description.is_a? ResolvedRootDescription
        @source = description.description.source
      end

      def to_range : Range
        Range.new to_reference, @version
      end

      def to_reference : Reference
        Reference.new @name, @description.description
      end

      def to_s(detail : Detail = :none) : String
        return @name if @root

        String.build do |io|
          io << @name
          if detail.version? || !@root
            io << ' ' << @version
          end

          if !@root && (detail.source? || !@description.is_a? ResolvedHostedDescription)
            io << " from " << @description.description.source
            if detail.description?
              io << ' '
              @description.to_s io
            end
          end
        end
      end

      def ==(other : ID) : Bool
        @name == other.name && @version == other.version && @description == other.description
      end
    end

    class Range
      getter constriaint : Version::Constraint
      @reference : Reference

      delegate :name, :version, :root?, :source, to: @reference

      def self.root(package : Package)
        new Reference.root(package), package.version
      end

      def initialize(@package, @constriaint)
      end

      def to_reference : Reference
        @reference
      end

      def with_terse_constraint : Range
        return self unless @constriaint.is_a? Version::Range
        return self if @constriaint.to_s.starts_with? '^'

        range = @constriaint.as(Version::Range)
        return self unless range.include_min?
        return self if range.include_max?
        return self unless min = range.min

        if range.max == min.next_major.first_prerelease
          Range.new @reference, Version::Constraint.compatible_with(min)
        else
          self
        end
      end

      def allows?(id : ID) : Bool
        name == id.name && description == id.description.description && constriaint.allows?(id.version)
      end

      def to_s(detail : Detail = :none) : String
        String.build do |io|
          io << name
          if detail.version? || show_version_constraint?
            io << ' ' << @constriaint
          end

          if !@root && (detail.source? || !@description.is_a? HostedDescription)
            io << " from " << @description.source.name
            if detail.description?
              io << ' '
              description.to_s io
            end
          end
        end
      end

      def ==(other : Range) : Bool
        @reference == other.@reference && @constriaint == other.constraint
      end

      private def show_version_constraint? : Bool
        return false if root?
        return true if !@constriaint.any?

        description.source.has_multiple_versions?
      end
    end
  end
end
