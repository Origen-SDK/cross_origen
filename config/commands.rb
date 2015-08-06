# This file should be used to extend origen with application specific tasks

aliases ={

}

@command = aliases[@command] || @command

case @command

when "specs"
  require "rspec"
  exit RSpec::Core::Runner.run(['spec'])

when "examples", "test"  
  status = 0

  ARGV = %w(templates/test -t debug -r approved)
  load "origen/commands/compile.rb"
  
  if Origen.app.stats.changed_files == 0 &&
     Origen.app.stats.new_files == 0 &&
     Origen.app.stats.changed_patterns == 0 &&
     Origen.app.stats.new_patterns == 0

    Origen.app.stats.report_pass
  else
    Origen.app.stats.report_fail
    status = 1
  end
  puts
  if @command == "test"
    Origen.app.unload_target!
    require "rspec"
    result = RSpec::Core::Runner.run(['spec'])
    status = status == 1 ? 1 : result
  end
  exit status

else
  @application_commands = <<-EOT
 specs        Run the specs (unit tests), -c will enable coverage
 examples     Run the examples (acceptance tests), -c will enable coverage
 test         Run both specs and examples, -c will enable coverage
  EOT

end
