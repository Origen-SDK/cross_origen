require 'rgen'
require_relative '../config/application.rb'
require_relative '../config/environment.rb'

module RosettaStone
  if RUBY_VERSION < '2.0.0'
    require 'scrub_rb'
  end
  extend ActiveSupport::Concern

  included do
    include RGen::Model
  end

  def instance_respond_to?(method_name)
    public_methods.include?(method_name)
  end

  def rs_import(options = {})
    file = rs_file(options)
    rs_translator(file, options).import(file, options)
  end

  def to_ralf(options = {})
    rs_ralf.owner_to_ralf(options)
  end

  def to_ip_xact(options = {})
    rs_ip_xact.owner_to_xml(options)
  end
  alias_method :to_ipxact, :to_ip_xact

  def to_rgen(options = {})
    options[:obj] = self
    rs_to_rgen(options)
  end

  def to_header(options = {})
    rs_headers.owner_to_header(options)
  end

  # Tries the given methods and returns the first one to return a value,
  # ultimately returns nil if no value is found.
  def rs_try(*methods)
    methods.each do |method|
      if self.respond_to?(method)
        val = send(method)
        return val if val
      end
    end
    nil
  end

  # Returns an instance of the DesignSync interface
  def rs_design_sync
    @rs_design_sync ||= DesignSync.new(self)
  end

  def rs_headers
    @rs_headers ||= Headers.new(self)
  end

  # Creates Ruby files necessary to model all sub_blocks and registers found (recursively) owned by options[:obj]
  # The Ruby files are created at options[:path] (app output directory by default)
  def rs_to_rgen(options = {})
    options = {
      obj:  $dut,
      path: RGen.app.config.output_directory
    }.update(options)
    # This method assumes and checks for $self to contain RGen::Model
    error "ERROR: #{options[:obj].class} does not contain RGen::Model as required" unless options[:obj].class < RGen::Model
    # Check to make sure there are sub_blocks or regs directly under $dut
    error "ERROR: options[:obj]ect #{options[:obj].object_id} of class #{options[:obj].class} does not contain registers or sub_blocks" unless options[:obj].owns_registers? || options[:obj].instance_respond_to?(:sub_blocks)
    OrigenFormat.new(options).export
  end

  def rs_ralf
    @rs_ralf ||= Ralf.new(self)
  end

  def rs_ip_xact
    @rs_ip_xact ||= IpXact.new(self)
  end

  private

  # Returns an instance of the translator for the format of the given file
  def rs_translator(file, _options = {})
    snippet = IO.read(file, 2000)  # Read first 2000 characters
    case snippet
    when /spiritconsortium/
      rs_ip_xact
    else
      fail "Unknown file format for file: #{file}"
    end
  end

  # Returns a local path to the given file defined by the options.
  def rs_file(options = {})
    if options[:path]
      options[:path]
    elsif options[:vault]
      rs_design_sync.fetch(options)
    else
      fail 'You must supply a :path or :vault option pointing to the import file!'
    end
  end
end
