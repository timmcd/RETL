
desc "build the file of treetop."
task :treetop do
  sh "tt lib/etl/grammar.tt" if !File.exists?("lib/etl/grammar.rb") || File.stat("lib/etl/grammar.tt").mtime > File.stat("lib/etl/grammar.rb").mtime
end

desc "create the documentation."
task :doc => [:treetop] do
  sh "rdoc"
end

desc "clean the directory current."
task :clean do
  rm_f "lib/etl/grammar.rb"
end

desc "build all."
task :default => [:treetop, :doc]
