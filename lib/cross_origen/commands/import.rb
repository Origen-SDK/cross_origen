options = {}
opt_parser = OptionParser.new do |opts|
  opts.banner = <<-END
Usage: origen cr:import FILE [options]

Import the given file into Origen format.
This will output a Ruby module that can then be included in an Origen model
to add the contained registers, sub-blocks, etc.

END
  opts.on('-o', '--output PATH', String, 'Override the default output file') { |t| options[:output] = t }
end
opt_parser.parse! ARGV

file = ARGV[0]
unless file
  puts 'You must supply a file to import!'
  exit
end

unless File.exist?(file)
  puts 'That file does not exist!'
  exit
end

snippet = IO.read(file, 2000)  # Read first 2000 characters
case snippet
when /CMSIS-SVD.xsd/
  CrossOrigen::CMSISSVD.new(nil).import(file, options)
else
  puts 'Unknown file format!'
end
