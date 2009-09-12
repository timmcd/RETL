require 'treetop'
require 'etl/runtime'

module ETL
  class Special < Hash
    def etl_show
      if empty?
        "\e[1m\e[35m(\e[31m...\e[35m)\e[0m"
      else
        "\e[1m\e[35m(\e[0m\n#{self.map{|k,v| "  \e[32m\e[1m#{k}:\e[0m\n#{(v.respond_to?(:etl_show) ? v.etl_show : "\e[33m#{v.inspect}\e[0m").gsub(/^/, ' '*(k.to_s.size+6))}"}.join("\n")}\n\e[1m\e[35m)\e[0m"
      end
    end
  end

  class InstructionList < Array
    def etl_show
      if empty?
        "\e[1m\e[36m<\e[31m...\e[36m>\e[0m"
      else
        "\e[1m\e[36m<\e[0m\n#{self.map{|i|i.respond_to?(:etl_show) ? i.etl_show.gsub(/^/, '  ') : "  * \e[33m#{i.inspect}\e[0m"}.join("\n\n")}\n\e[1m\e[36m>\e[0m"
      end
    end
  end

  SP = Special
  IL = InstructionList

  # rule script
  #   one or more sentences.
  module ScriptNode
    def compile
      IL[
          *elements.map do |e|
            e.compile
          end
      ]
    end
  end

  # rule sentence
  #   one or more statements,
  #   delimited by "and",
  #   ended with a period.
  module SentenceNode
    def compile
      IL[chunk.compile, *opt.elements.map{|st|st.chunk.compile}]
    end
  end

  # rule statement
  #   a verb followed by any number of arguments,
  #   delimited by a comma.
  module StatementNode
    def compile
      IL[verb.compile, *arguments.elements.map{|a|a.a.compile}]
    end
  end

  # rule creation
  #   create typednoun [as value].
  module CreationNode
    def compile
      if as.respond_to?(:argument)
        SP[:create => typednoun.compile, :as => as.argument.compile]
      else
        SP[:create => typednoun.compile]
      end
    end
  end

  # rule typednoun
  #   ... TODO: update docs :D
  module TypedNounNode
    def compile
      if q.respond_to?(:property)
        SP[:type => type.compile, :noun => name.text_value, :prop => q.property.compile]
      else
        SP[:type => type.compile, :noun => name.text_value]
      end
    end
  end

  # rule space
  #   any whitespace [\s] or [ \n\t].
  module SpaceNode
    def compile
      nil
    end
  end

  # rule verbcalled
  #   a statement surrounded by
  #   square brackets.
  module VerbCalledNode
    def compile
      SP[:iexpr => s.compile]
    end
  end

  # rule verb
  #   a word made of:
  #   - any letter [A-Za-z]
  #   - a hyphen [-]
  module VerbNode
    def compile
      SP[:verb => text_value]
    end
  end

  # rule argument
  #   one of:
  #   - verbcalled
  #   - assignment
  #   - noun
  #   - math
  #   - number
  #   - text
  module ArgumentNode
  end

  module AssignmentNode
    def compile
      IL[verb.compile, SP[:from => noun.compile, :to => argument.compile]]
    end
  end

  # rule noun
  #   any of [A-Za-z-] or "it",
  #   prefixed optionally by 'the',
  #   or type and optionally 'of',
  #   followed by ' or 's optionally
  #     and another noun, to designate
  #     a property.
  module NounNode
    def compile
      if q.respond_to?(:property)
        SP[:noun => name.text_value, :prop => q.property.compile]
      else
        SP[:noun => name.text_value]
      end
    end
  end

  # rule it
  #   "it" - the last object used.
  module ItNode
    def compile
      if q.respond_to?(:property)
        SP[:noun => :it, :prop => q.property.compile]
      else
        SP[:noun => :it]
      end
    end
  end

  # rule math
  #   any sequence of number & mathoperator,
  #   surrounded by parentheses.
  module MathNode
    def compile
      SP[:math => "#{base.eval(scope)} #{operations.elements.map{|o|"#{o.op.eval(scope)} #{o.n.eval(scope)}"}.join(' ')}"]
    end
  end

  # rule mathoperator
  #   plus, minus, divide, exponent, multiply
  #      +,     -,      /,        ^,        *
  module MathOperatorNode
    def compile
      return text_value
    end
  end

  # rule struct
  #   any of [A-Za-z-],
  #   the name of a struct
  module StructNode
    def compile
      SP[:struct => text_value]
    end
  end

  # rule type / 1
  #   designates a built in type,
  #   which is one of:
  #   - number
  #   - text
  #   - struct
  #   - verb
  module BuiltinTypeNode
    def compile
      SP[:bit => text_value]
    end
  end

  # rule type / 2
  #   designates a Struct Type,
  #   for use like so:
  #       create the struct game.
  #       create the game zuuup and
  #         set its description to "some random weird game".
  module StructTypeNode
  end

  # rule number
  #   any sequence of decimal digits [0-9],
  #   optionally followed by a point [.]
  #     and more decimal digits.
  module NumberNode
    def to_i
      return ETL.number(base.text_value.to_i, point.respond_to?(:n) ? point.n.text_value.to_i : nil)
    end
    def compile
      self.to_i
    end
  end

  # rule text
  #   any string of text
  #     not containing a double quotation mark [unless escaped with a backslash],
  #     including escape characters \" ["], \n [LF], \e [escape], \r [CR],
  #     or hex/octal escape characters \274, \xBC
  #     surrounded by double quotation marks ["].
  module TextNode
    def to_s
      str.text_value.
        gsub('\"', '"').
        gsub('\n', "\n").
        gsub('\e', "\e").
        gsub('\r', "\r").
        gsub(/\\0([0-7]+)/){ $1.to_i(8).chr }.
        gsub(/\\x([0-9a-fA-F]+)/) { $1.to_i(16).chr }
    end
    def compile
      self.to_s
    end
  end

  # rule comment|blockcomment
  #   any string of text,
  #   comment:      start "--"  end [newline]
  #   blockcomment: start "--[" end "]--"
  #
  #   comment can come at the end of a sentence,
  #   blockcomment can come anywhere whitespace goes.
  module CommentNode
    def compile
      SP[:comment => self.comment.text_value]
    end
  end
end
