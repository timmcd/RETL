require 'rubygems'
require 'treetop'
require 'etl_grammar'

puts ETLGrammarParser.new.parse(gets.chomp).inspect
