require 'treetop'

module ETL
  # rule script
  #   one or more sentences.
  class ScriptNode < Treetop::Runtime::SyntaxNode
    def eval(scope=nil)
      scope ||= ETL::Scope.new
      elements.map do |s|
        s.eval(scope)
      end.last
    end
  end

  # rule sentence
  #   one or more statements,
  #   delimited by "and",
  #   ended with a period.
  class SentenceNode < Treetop::Runtime::SyntaxNode
    def eval(scope)
      statement.eval(scope)
      opt.elements.map{|st|st.eval(scope)}.last
    end
  end

  # rule statement
  #   a verb followed by any number of arguments,
  #   delimited by a comma.
  class StatementNode < Treetop::Runtime::SyntaxNode
    def eval(scope)
      verb.eval(scope).call(*arguments.elements.map{|a|a.a.eval(scope)})
    end
  end

  # rule space
  #   any whitespace.
  class SpaceNode < Treetop::Runtime::SyntaxNode
    def eval(scope)
      # do nothing
    end
  end

  # rule verbcalled
  #   a statement surrounded by
  #   square brackets.
  class VerbCalledNode < Treetop::Runtime::SyntaxNode
    def eval(scope)
      s.eval(scope)
    end
  end

  # rule verb
  #   a word made of:
  #   - any letter [A-Za-z]
  #   - a hyphen [-]
  class VerbNode < Treetop::Runtime::SyntaxNode
    def eval(scope)
      scope.verbs[text_value]
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
  class ArgumentNode < Treetop::Runtime::SyntaxNode
    def eval(scope)
      elements[0].elements[0].eval(scope)
    end
  end

  # rule noun
  #   any of [A-Za-z-] or "it",
  #   prefixed optionally by 'the',
  #   or type and optionally 'of',
  #   followed by s or 's optionally
  #     and another noun, to designate
  #     a property.
  class NounNode < Treetop::Runtime::SyntaxNode
    def eval(scope)
      n = scope.nouns[name.text_value,type.eval(scope)]
      property ? property.eval(n.scope) : n
    end
  end

  # rule it
  #   "it" - the last object used.
  class ItNode < Treetop::Runtime::SyntaxNode
    def eval(scope)
      scope.it
    end
  end

  # rule math
  #   any sequence of number & mathoperator,
  #   surrounded by parentheses.
  class MathNode < Treetop::Runtime::SyntaxNode
    def eval(scope)
      ETL.number(Kernel.eval("#{base.eval(scope)} #{operations.elements.map{|o|"#{o.op.eval(scope)} #{o.n.eval(scope)}"}.join(' ')}"))
    end
  end

  # rule mathoperator
  #   plus, minus, divide, exponent, multiply
  #      +,     -,      /,        ^,        *
  class MathOperatorNode < Treetop::Runtime::SyntaxNode
    def eval(scope)
      case text_value
      when '^'
        return "**"
      else
        return text_value
      end
    end
  end

  # rule struct
  #   any of [A-Za-z-],
  #   the name of a struct
  class StructNode < Treetop::Runtime::SyntaxNode
    def eval(scope)
      scope.structs[text_value]
    end
  end

  # rule type / 1
  #   designates a built in type,
  #   which is one of:
  #   - number
  #   - text
  #   - struct
  #   - verb
  class BuiltinTypeNode < Treetop::Runtime::SyntaxNode
    def eval(scope)
      return text_value.to_sym
    end
  end

  # rule type / 2
  #   designates a Struct Type,
  #   for use like so:
  #       create the struct game.
  #       create the game zuuup and
  #         set its description to "some random weird game".
  class StructTypeNode < Treetop::Runtime::SyntaxNode
    def eval(scope)
      return struct.eval(scope)
    end
  end

  # rule number
  #   any sequence of decimal digits [0-9],
  #   optionally followed by a point [.]
  #     and more decimal digits.
  class NumberNode < Treetop::Runtime::SyntaxNode
    def eval(scope)
      self.to_i
    end
    def to_i
      return ETL.number(base.text_value.to_i, point.n.text_value.to_i)
    end
  end

  # rule text
  #   any string of text
  #     not containing a double quotation mark [fixme]
  #     surrounded by double quotation marks ["].
  class TextNode < Treetop::Runtime::SyntaxNode
    def eval(scope)
      return ETL.text(str.text_value)
    end
  end
end
