# This file should be used to extend the origen command line tool with tasks 
# specific to your application.
# The comments below should help to get started and you can also refer to
# lib/origen/commands.rb in your Origen core workspace for more examples and 
# inspiration.
#
# Also see the official docs on adding commands:
#   http://origen.freescale.net/origen/latest/guides/custom/commands/

# Map any command aliases here, for example to allow origen -x to refer to a 
# command called execute you would add a reference as shown below: 
aliases ={
#  "-x" => "execute",
}

# The requested command is passed in here as @command, this checks it against
# the above alias table and should not be removed.
@command = aliases[@command] || @command

# Smome helper methods to enable test coverage, these will eventually be
# added to Origen Core, but they need to be here for now
def path_to_coverage_report
  require 'pathname'
  Pathname.new("#{Origen.root}/coverage/index.html").relative_path_from(Pathname.pwd)
end

def enable_coverage(name, merge=true)
  if ARGV.delete("-c") || ARGV.delete("--coverage")
    require 'simplecov'
    SimpleCov.start do
      command_name name
      add_filter "DO_NOT_HAND_MODIFY"  # Exclude all imports

      at_exit do
        SimpleCov.result.format!
        puts ""
        puts "To view coverage report:"
        puts "  firefox #{path_to_coverage_report} &"
        puts ""
      end
    end
    yield
  else
    yield
  end
end

# Now branch to the specific task code
case @command

# Run the unit tests  
when "specs"
  enable_coverage("specs") do 
    ARGV.unshift "spec"
    require "rspec"
    # For some unidentified reason Rspec does not autorun on this version
    if RSpec::Core::Version::STRING && RSpec::Core::Version::STRING == "2.11.1"
      RSpec::Core::Runner.run ARGV
    else
      require "rspec/autorun"
    end
  end
  exit 0 # This will never be hit on a fail, RSpec will automatically exit 1

# Run the example-based (diff) tests
when "examples"  
  Origen.load_application
  status = 0
  enable_coverage("examples") do 

    # Compiler tests
    ARGV = %w(templates/test -t debug -r approved)
    load "origen/commands/compile.rb"
    # Pattern generator tests
    #ARGV = %w(some_pattern -t debug -r approved)
    #load "#{Origen.top}/lib/origen/commands/generate.rb"

    if Origen.app.stats.changed_files == 0 &&
       Origen.app.stats.new_files == 0 &&
       Origen.app.stats.changed_patterns == 0 &&
       Origen.app.stats.new_patterns == 0

      Origen.app.stats.report_pass
    else
      Origen.app.stats.report_fail
      status = 1
    end
    puts ""
  end
  exit status  # Exit with a 1 on the event of a failure per std unix result codes

# Always leave an else clause to allow control to fall back through to the
# Origen command handler.
# You probably want to also add the command details to the help shown via
# origen -h, you can do this be assigning the required text to @application_commands
# before handing control back to Origen. Un-comment the example below to get started.
else
  @application_commands = <<-EOT
 specs        Run the specs (tests), -c will enable coverage
 examples     Run the examples (tests), -c will enable coverage
  EOT

end 
