# English Test Language :: Runtime
#   ETL::Runtime
#   ETL::Scope
#   ETL::Number
#   ETL::Text

module ETL
  def self.number(base=0, trail=0)
    "#{base.to_i}.#{trail.to_i}".to_f
  end
  def self.text(t)
    t.to_s
  end
end

class ETL::Runtime
  def initialize
    @global_scope = ETL::Scope.new
    @global_scope.verbs.define('write', :text) do |t|
      puts t
    end
  end
  def run string
    ETL::GrammarParser.new.parse(string).eval(@global_scope)
  end
end

class ETL::Scope
  # unfinished
  def initialize(parents=[])
    @parents = parents
    @verbs = ETL::Table::Verb.new
    @nouns = ETL::Table::Noun.new
  end

  # check if we have a verb.
  def has_verb?(var)
    if @verbs.has?(var)
      return true
    elsif pa = @parents.find{ |pr| pr.has_verb?(var)}
      return pa
    else
      return false
    end
  end

  def has_noun?(var)
    if @nouns.has?(var)
      return true
    elsif pa = @parents.find{ |pr| pr.has_noun?(var)}
      return pa
    else
      return false
    end
  end

  def verbs
    vbs = Object.new
    vbs.instance_variable_set(:@scope, self)
    class << vbs
      def [](v)
        case x = @scope.has_verb?(v)
        when true
          return @scope.instance_variable_get(:@verbs)[v]
        when false
          return ETL::None
        else
          return x.verbs[v]
        end
      end
    end
    return vbs
  end

  def nouns
    nos = Object.new
    nos.instance_variable_set(:@scope, self)
    class << nos
      def [](n)
        case x = @scope.has_noun?(n)
        when true
          return @scope.instance_variable_get(:@nouns)[n]
        when false
          return ETL::None
        else
          return x.nouns[n]
        end
      end
    end
    return nos
  end
end
