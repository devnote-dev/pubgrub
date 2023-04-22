module PubGrub
  class SolveFailure < Exception
    getter incompatibility : Incompatibility
    getter explanation : String?

    def initialize(@incompatibility : Incompatibility, @explanation : String? = nil)
    end

    def to_s : String
      "could not find compatible versions\n\n#{explanation}"
    end

    def explanation : String
      @explanation ||= FailureWriter.new(@incompatibility).write
    end
  end

  class FailureWriter
    getter root : Incompatibility
    getter derivations : Hash(Incompatibility, Int32)
    getter lines : Array(String | Int32 | Nil)
    getter line_numbers : Hash(Incompatibility, Int32)

    def initialize(@root : Incompatibility)
      @derivations = {} of Incompatibility => Int32
      @lines = Array(String | Int32 | Nil).new
      @line_numbers = {} of Incompatibility => Int32

      count_derivations root
    end

    def write : String
      return @root.to_s unless @root.conflict?

      visit @root
      padding = @line_numbers.empty? ? 0 : "(#{@line_numbers.values.last}) ".size

      @lines.map do |message, number|
        next "" if message.empty?

        lead = number ? "(#{number}) " : ""
        lead = lead.ljust padding
        message = message.gsub("\n", "\n" + " " * (padding + 2))

        "#{lead}#{message}"
      end.join '\n'
    end

    private def write_line(incomp : Incompatibility, message : String, numbered : Bool) : Nil
      if numbered
        number = @line_numbers.size + 1
        @line_numbers[incomp] = number
      end

      @lines << [message, number]
    end

    private def visit(incomp : Incompatibility) : Nil
      raise "" unless incomp.conflict?

      numbered = conclusion || derivations[incomp] > 1
      conjunction = conclusion || incomp == @root ? "So, " : "And"
      cause = incomp.cause

      if cause.conflict.conflict? && cause.other.conflict?
        conflict_line = @line_numbers[cause.conflict]?
        other_line = @line_numbers[cause.other]?

        if conflict_line && other_line
          write_line(
            incomp,
            "Because #{cause.conflict} (#{conflict_line})\nand #{cause.other} (#{other_line}),\n#{incomp}",
            numbered
          )
        elsif conflict_line || other_line
          with_line = conflict_line ? cause.conflict : cause.other
          without_line = conflict_line ? cause.other : cause.conflict
          line = @line_numbers[with_line]

          visit without_line
          write_line(
            incomp,
            "#{conjunction} because #{with_line} (#{line}),\n#{incomp}",
            numbered
          )
        else
          single_line_conflict = single_line? cause.conflict.cause
          single_line_other = single_line? cause.other.cause

          if single_line_conflict || single_line_other
            first = single_line_other ? cause.conflict : cause.other
            second = single_line_other ? cause.other : cause.conflict

            visit first
            visit second
            write_line(
              incomp,
              "Thus, #{incomp}",
              numbered
            )
          else
            visit cause.conflict, true
            @lines << ["", nil]
            visit cause.other

            write_line(
              incomp,
              "#{conjunction} because #{cause.conflict} (#{@line_numbers[cause.conflict]}),\n#{incomp}",
              numbered
            )
          end
        end
      elsif cause.conflict.conflict? || cause.other.conflict?
        derived = cause.conflict.conflict? ? cause.conflict : cause.other
        ext = cause.conflict.conflict? ? cause.other : cause.conflict
        derived_line = @line_numbers[derived]?

        if derived_line
          write_line(
            incomp,
            "Because #{ext}\nand #{derived} (#{derived_line}),\n#{incomp}",
            numbered
          )
        elsif collapsible? derived
          derived_cause = derived.cause
          if derived_cause.conflict.conflict?
            collapsed_derived = derived_cause.conflict
            collapsed_ext = derived_cause.other
          else
            collapsed_derived = derived_cause.other
            collapsed_ext = derived_cause.conflict
          end

          visit collapsed_derived
          write_line(
            incomp,
            "#{conjunction} because #{collapsed_ext}\nand #{ext},\n#{incomp}",
            numbered
          )
        else
          visit derived
          write_line(
            incomp,
            "#{conjunction} because #{ext},\n#{incomp}",
            numbered
          )
        end
      else
        write_line(
          incomp,
          "Because #{cause.conflict}\nand #{cause.other},\n#{incomp}",
          numbered
        )
      end
    end

    private def single_line?(cause : Cause) : Bool
      !cause.conflict.conflict? && !cause.other.conflict?
    end

    private def collapsible?(incomp : Incompatibility) : Bool
      return false if @derivations[incomp] > 1

      cause = incomp.cause
      return false if single_line? cause
      return false unless cause.conflict.conflict? || cause.other.conflict?

      complex = cause.conflict.conflict? ? cause.conflict : cause.other

      !@line_numbers.has_key? complex
    end

    private def count_derivations(incomp : Incompatibility) : Nil
      if @derivations.has_key? incomp
        @derivations[incomp] += 1
      else
        @derivations[incomp] = 1
        if incomp.conflict?
          cause = incomp.cause
          count_derivations cause.conflict
          count_derivations cause.other
        end
      end
    end
  end
end
