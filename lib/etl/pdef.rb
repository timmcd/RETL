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
    def eval(scope=nil)
      scope ||= ETL::Scope.new
      elements.map do |s|
        s.eval(scope)
      end.last
    end
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
    def eval(scope)
      statement.eval(scope)
      opt.elements.map{|st|st.eval(scope)}.last
    end
    def compile
      IL[statement.compile, *opt.elements.map{|st|st.compile}]
    end
  end

  # rule statement
  #   a verb followed by any number of arguments,
  #   delimited by a comma.
  module StatementNode 
    def eval(scope)
      verb.eval(scope).call(*arguments.elements.map{|a|a.a.eval(scope)})
    end
    def compile
      IL[verb.compile, *arguments.elements.map{|a|a.a.compile}]
    end
  end

  # rule space
  #   any whitespace.
  module SpaceNode 
    def eval(scope)
      # do nothing
    end
    def compile
      nil
    end
  end

  # rule verbcalled
  #   a statement surrounded by
  #   square brackets.
  module VerbCalledNode 
    def eval(scope)
      s.eval(scope)
    end
    def compile
      SP[:iexpr => s.compile]
    end
  end

  # rule verb
  #   a word made of:
  #   - any letter [A-Za-z]
  #   - a hyphen [-]
  module VerbNode 
    def eval(scope)
      scope.verbs[text_value]
    end
    def compile
      SP[:verb => text_value]
    end
  end

  # rule argument
  #   one of:
  #   - verbcalled
  #   - noun
  #   - math
  #   - type
  #   - number
  #   - text
  module ArgumentNode
  end

  # rule noun
  #   any of [A-Za-z-] or "it",
  #   prefixed optionally by 'the',
  #   or type and optionally 'of',
  #   followed by s or 's optionally
  #     and another noun, to designate
  #     a property.
  module NounNode 
    def eval(scope)
      n = scope.nouns[name.text_value,type.eval(scope)]
      property ? property.eval(n.scope) : n
    end
    def compile
      if q.respond_to?(:property)
        SP[:noun => name.text_value, :type => (r.nt.compile rescue nil), :prop => property.compile]
      else
        SP[:noun => name.text_value, :type => (r.nt.compile rescue nil)]
      end
    end
  end

  # rule it
  #   "it" - the last object used.
  module ItNode 
    def eval(scope)
      scope.it
    end
    def compile
      SP[:noun => :it]
    end
  end

  # rule math
  #   any sequence of number & mathoperator,
  #   surrounded by parentheses.
  module MathNode 
    def eval(scope)
      ETL.number(Kernel.eval("#{base.eval(scope)} #{operations.elements.map{|o|"#{o.op.eval(scope)} #{o.n.eval(scope)}"}.join(' ')}"))
    end
    def compile
      SP[:math => "#{base.eval(scope)} #{operations.elements.map{|o|"#{o.op.eval(scope)} #{o.n.eval(scope)}"}.join(' ')}"]
    end
  end

  # rule mathoperator
  #   plus, minus, divide, exponent, multiply
  #      +,     -,      /,        ^,        *
  module MathOperatorNode 
    def eval(scope)
      case text_value
      when '^'
        return "**"
      else
        return text_value
      end
    end
    def compile
      return text_value
    end
  end

  # rule struct
  #   any of [A-Za-z-],
  #   the name of a struct
  module StructNode 
    def eval(scope)
      scope.structs[text_value]
    end
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
    def eval(scope)
      return text_value.to_sym
    end
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
    def eval(scope)
      return struct.eval(scope)
    end
    def compile
      SP[:srt => struct.compile]
    end
  end

  # rule number
  #   any sequence of decimal digits [0-9],
  #   optionally followed by a point [.]
  #     and more decimal digits.
  module NumberNode 
    def eval(scope)
      self.to_i
    end
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
    def eval(scope)
      self.to_s
    end
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
    def eval(scope)
      # do nothing
    end
    def compile
      SP[:comment => self.comment]
    end
  end
end
