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
  def initialize(parents=[nil])
    @parents = parents
    @verbs = ETL::Table::Verb.new
    @nouns = ETL::Table::Noun.new
  end

  def has_verb?(var)
    n = nil
    if @verbs.has?(var)
      return @verbs[var]
    elsif @parents.find{ |pr| n=pr[var]}
      return n
    else
      return ETL::None
    end
  end

  def has_noun?(var)
    n = nil
    if @nouns.has?(var)
      return @nouns[var]
    elsif @parents.find{ |pr| n=pr[var]}
      return n
    else
      return ETL::None
    end
  end

end
