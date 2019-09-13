module CrossOrigen
  class IpXact < XMLDoc
    AddressSpace = Struct.new(:name, :range, :width)

    MemoryMaps = Struct.new(:name, :address_blocks)

    AddressBlock = Struct.new(:name, :base_address, :range, :width)

    # Create a shorthand way to reference Origen Core's Bit ACCESS_CODES
    @@access_hash = Origen::Registers::Bit.const_get(:ACCESS_CODES)

    # Import/reader that currently only supports creating registers and bit fields
    def import(file, options = {}) # rubocop:disable CyclomaticComplexity
      require 'kramdown'

      filename = Pathname.new(file).basename('.*').to_s

      unless options[:refresh] || CrossOrigen.refresh?
        return if owner.import(filename, allow_missing: true)
      end

      model = CrossOrigen::Model.new

      address_spaces = {}

      doc(file, options) do |doc|
        doc.xpath('//spirit:addressSpaces/spirit:addressSpace').each do |addr_space|
          name = fetch addr_space.at_xpath('spirit:name'), downcase: true, to_sym: true, get_text: true
          range = fetch addr_space.at_xpath('spirit:range'), get_text: true, to_dec: true
          width = fetch addr_space.at_xpath('spirit:width'), get_text: true, to_i: true
          address_spaces[name] = AddressSpace.new(name, range, width)
        end
        open_memory_map(doc) do |mem_map|
          if mem_map
            mem_map_name = fetch mem_map.at_xpath('spirit:name'), downcase: true, to_sym: true, get_text: true
            if mem_map_name.to_s.empty?
              mem_map_obj = model
            else
              model.sub_block mem_map_name
              mem_map_obj = model.send(mem_map_name)
            end
            addr_blocks = mem_map.xpath('spirit:addressBlock')
          else
            mem_map_obj = model
            addr_blocks = doc.xpath('//spirit:addressBlock')
          end
          addr_blocks.each do |addr_block|
            name = fetch addr_block.at_xpath('spirit:name'), downcase: true, to_sym: true, get_text: true
            base_address = fetch addr_block.at_xpath('spirit:baseAddress'), get_text: true, to_dec: true
            range = fetch addr_block.at_xpath('spirit:range'), get_text: true, to_dec: true
            width = fetch addr_block.at_xpath('spirit:width'), get_text: true, to_i: true
            if name.to_s.empty?
              addr_block_obj = mem_map_obj
            else
              mem_map_obj.sub_block name, base_address: base_address, range: range, lau: width
              addr_block_obj = mem_map_obj.send(name)
            end
            addr_block.xpath('spirit:register').each do |register|
              name = fetch register.at_xpath('spirit:name'), downcase: true, to_sym: true, get_text: true
              size = fetch register.at_xpath('spirit:size'), get_text: true, to_i: true
              addr_offset = fetch register.at_xpath('spirit:addressOffset'), get_text: true, to_dec: true
              access = fetch register.at_xpath('spirit:access'), get_text: true
              # Determine if a reset is defined for the register
              if register.at_xpath('spirit:reset').nil?
                # If a reset does not exist, need to set the reset_value to 0, as Origen does not (yet) have a concept
                # of a register without a reset.
                reset_value = 0
              else
                # If a reset exists, determine the reset_value (required) and reset_mask (if defined)
                reset_value = fetch register.at_xpath('spirit:reset/spirit:value'), get_text: true, to_dec: true
                reset_mask = fetch register.at_xpath('spirit:reset/spirit:mask'), get_text: true, to_dec: true
                # Issue #8 fix - reset_mask is optional, keep reset value as imported when a mask is not defined.
                # Only perform AND-ing if mask is defined.  Only zero-out the reset_value if reset_value was nil.
                if reset_value.nil?
                  # Set default for reset_value attribute if none was provided and issue a warning.
                  reset_value = 0
                  Origen.log.warning "Register #{name.upcase} was defined as having a reset, but did not have a defined reset value.  This is not compliant with IP-XACT standard."
                  Origen.log.warning "The reset value for #{name.upcase} has been defined as 0x0 as a result."
                elsif reset_mask.nil?
                  # If mask is undefined, leave reset_value alone.
                else
                  # Do a logical bitwise AND with the reset value and mask
                  reset_value = reset_value & reset_mask
                end
              end
              # Future expansion: pull in HDL path as abs_path in Origen.
              addr_block_obj.reg name, addr_offset, size: size, access: access, description: reg_description(register) do |reg|
                register.xpath('spirit:field').each do |field|
                  name = fetch field.at_xpath('spirit:name'), downcase: true, to_sym: true, get_text: true
                  bit_offset = fetch field.at_xpath('spirit:bitOffset'), get_text: true, to_i: true
                  bit_width = fetch field.at_xpath('spirit:bitWidth'), get_text: true, to_i: true
                  xml_access = fetch field.at_xpath('spirit:access'), get_text: true
                  # Newer IP-XACT standards list access as < read or write>-< descriptor >, such as
                  # "read-write", "read-only", or "read-writeOnce"
                  if xml_access =~ /\S+\-\S+/ || xml_access == 'writeOnce'
                    # This filter alone is not capable of interpreting the 1685-2009 (and 2014).  Therefore
                    # must reverse-interpret the content of access_hash (see top of file).
                    #
                    # First get the base access type, ie: read-write, read-only, etc.
                    # base_access = fetch field.at_xpath('spirit:access'), get_text: true
                    base_access = xml_access
                    # Next grab any modified write values or read actions
                    mod_write = fetch field.at_xpath('spirit:modifiedWriteValue'), get_text: true
                    read_action = fetch field.at_xpath('spirit:readAction'), get_text: true
                    # Using base_access, mod_write, and read_action, look up the corresponding access
                    # acronym from access_hash, noting it is not possible to differentiate write-only
                    # from write-only, read zero and read-write from dc.
                    #
                    # Matched needs to be tracked, as there is no way to differentiate :rw and :dc in IP-XACT.
                    # Everything imported will default to :rw, never :dc.
                    matched = false
                    @@access_hash.each_key do |key|
                      if @@access_hash[key][:base] == base_access && @@access_hash[key][:write] == mod_write && @@access_hash[key][:read] == read_action && !matched
                        access = key.to_sym
                        matched = true
                      end
                    end
                  # Older IP-XACT standards appear to also accept short acronyms like "ro", "w1c", "rw",
                  # etc.
                  elsif xml_access =~ /\S+/
                    access = xml_access.downcase.to_sym
                  else
                    # default to read-write if access is not specified
                    access = :rw
                  end
                  range = nil
                  if bit_width == 1
                    range = bit_offset
                  else
                    range = (bit_offset + bit_width - 1)..bit_offset
                  end
                  reg.bit range, name, reset: reset_value[range], access: access, description: bit_description(field)
                end
              end
            end
          end
        end
      end
      model.export(filename, include_timestamp: CrossOrigen.include_timestamp?)
      owner.import(filename)
    end

    def doc(path, options = {})
      # If a fragment of IP-XACT is given, then wrap it with a valid header and we will try our best
      if options[:fragment]
        require 'nokogiri'

        content = %(
<?xml version="1.0"?>
<spirit:component xmlns:spirit="http://www.spiritconsortium.org/XMLSchema/SPIRIT/1.4"
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xsi:schemaLocation="$REGMEM_HOME/builder/ipxact/schema/ipxact
          $REGMEM_HOME/builder/ipxact/schema/ipxact/index.xsd">
        #{File.read(path)}
</spirit:component>
        )
        yield Nokogiri::XML(content)
      else
        super
      end
    end

    # Returns a string representing the owner object in IP-XACT XML
    # Usable / Available options:
    #   :vendor             = Company name/web address, ex: 'nxp.com'
    #   :library            = IP Library
    #   :schema             = '1685-2009' or default of Spirit 1.4 (when no :schema option passed)
    #   :bus_interface      = only 'AMBA3' supported at this time
    #   :mmap_name          = Optionally set the memoryMap name to something other than the module name
    #   :mmap_ref           = memoryMapRef name, ex: 'UserMap'
    #   :addr_block_name    = addressBlock -> Name, ex: 'ATX'
    def owner_to_xml(options = {})
      require 'nokogiri'

      options = {
        include_bit_field_values: true
      }.merge(options)

      @format = options[:format]

      # Compatible schemas: Spirit 1.4, 1685-2009
      # Assume Spirit 1.4 if no schema provided
      if options[:schema] == '1685-2009' # Magillem tool uses alternate schema
        schemas = [
          'http://www.spiritconsortium.org/XMLSchema/SPIRIT/1685-2009',
          'http://www.spiritconsortium.org/XMLSchema/SPIRIT/1685-2009/index.xsd'
        ]
      else # Assume Spirit 1.4 if not
        schemas = [
          'http://www.spiritconsortium.org/XMLSchema/SPIRIT/1.4',
          'http://www.spiritconsortium.org/XMLSchema/SPIRIT/1.4/index.xsd'
        ]
      end

      if uvm? && !(options[:schema] == '1685-2009')
        schemas << '$IREG_GEN/XMLSchema/SPIRIT/VendorExtensions.xsd'
      end

      if options[:schema] == '1685-2009' # Magillem tool uses alternate schema
        headers = {
          'xmlns:spirit'       => 'http://www.spiritconsortium.org/XMLSchema/SPIRIT/1685-2009',
          'xmlns:xsi'          => 'http://www.w3.org/2001/XMLSchema-instance',
          'xsi:schemaLocation' => schemas.join(' ')
        }
      else # Assume Spirit 1.4 if not
        headers = {
          'xmlns:spirit'       => 'http://www.spiritconsortium.org/XMLSchema/SPIRIT/1.4',
          'xmlns:xsi'          => 'http://www.w3.org/2001/XMLSchema-instance',
          'xsi:schemaLocation' => schemas.join(' ')
        }
      end

      if uvm? && !(options[:schema] == '1685-2009')
        headers['xmlns:vendorExtensions'] = '$IREG_GEN/XMLSchema/SPIRIT'
        # Else:
        # Do nothing ?
        # headers['xmlns:vendorExtensions'] = '$UVM_RGM_HOME/builder/ipxact/schema'
      end

      builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        spirit = xml['spirit']
        spirit.component(headers) do
          spirit.vendor options[:vendor] || 'Origen'
          spirit.library options[:library] || 'Origen'
          # I guess this should really be the register owner's owner's name?
          spirit.name options[:name] || try(:ip_name) || owner.class.to_s.split('::').last
          spirit.version options[:version] || try(:ip_version, :version, :revision)
          # The 1685-2009 schema allows for a bus interface.  AMBA3 (slave) supported so far.
          if options[:schema] == '1685-2009'
            if options[:bus_interface] == 'AMBA3'
              spirit.busInterfaces do
                spirit.busInterface do
                  spirit.name 'Slave'
                  bustype_header = {
                    'spirit:vendor'  => options[:vendor] || 'Origen',
                    'spirit:library' => 'amba3',
                    'spirit:name'    => 'APB3',
                    'spirit:version' => '1.0'
                  }
                  xml['spirit'].busType bustype_header
                  spirit.slave do
                    mmapref_header = {
                      'spirit:memoryMapRef' => options[:mmap_ref] || 'APB'
                    }
                    xml['spirit'].memoryMapRef mmapref_header
                  end
                end
              end
            end
          end
          spirit.memoryMaps do
            memory_maps.each do |map_name, _map|
              spirit.memoryMap do
                # Optionally assign memory map name to something other than the module name in Ruby,
                # default to 'RegisterMap'
                spirit.name options[:mmap_name] || 'RegisterMap'
                address_blocks do |domain_name, _domain, sub_block|
                  spirit.addressBlock do
                    # When registers reside at the top level, do not assign an address block name
                    if sub_block == owner
                      spirit.name options[:addr_block_name]
                    else
                      spirit.name address_block_name(domain_name, sub_block)
                    end
                    spirit.baseAddress sub_block.base_address.to_hex
                    spirit.range range(sub_block)
                    spirit.width width(sub_block)
                    sub_block.regs.each do |name, reg|
                      # Required for now to ensure that the current value is the reset value
                      reg.reset
                      spirit.register do
                        spirit.name options[:upcase_reg_names] ? name.to_s.upcase : name
                        spirit.description try(reg, :name_full, :full_name)
                        spirit.addressOffset reg.offset.to_hex
                        spirit.size reg.size
                        if reg.bits.any?(&:writable?)
                          spirit.access 'read-write'
                        else
                          spirit.access 'read-only'
                        end
                        spirit.reset do
                          spirit.value reg.data.to_hex
                          spirit.mask mask(reg).to_hex
                        end
                        reg.named_bits do |name, bits|
                          spirit.field do
                            spirit.name options[:upcase_bit_names] ? name.to_s.upcase : name
                            spirit.description try(bits, :brief_description, :name_full, :full_name)
                            spirit.bitOffset bits.position
                            spirit.bitWidth bits.size
                            # When exporting to 1685-2009 schema, need to handle special cases (writeOnce),
                            # modifiedWriteValue, and readAction fields.
                            if options[:schema] == '1685-2009'
                              if bits.writable? && bits.readable?
                                if bits.access == :w1
                                  spirit.access 'read-writeOnce'
                                else
                                  spirit.access 'read-write'
                                end
                              elsif bits.writable?
                                if bits.access == :wo1
                                  spirit.access 'writeOnce'
                                else
                                  spirit.access 'write-only'
                                end
                              elsif bits.readable?
                                spirit.access 'read-only'
                              end
                              if bits.readable?
                                unless @@access_hash[bits.access][:read].nil?
                                  spirit.readAction @@access_hash[bits.access][:read]
                                end
                              end
                              if bits.writable?
                                unless @@access_hash[bits.access][:write].nil?
                                  spirit.modifiedWriteValue @@access_hash[bits.access][:write]
                                end
                              end
                            else # Assume Spirit 1.4 if not
                              spirit.access bits.access
                            end
                            # HDL paths provide hooks for a testbench to directly manipulate the
                            # registers without having to go through a bus interface or read/write
                            # protocol.  Because the hierarchical path to a register block can vary
                            # greatly between devices, allow the user to provide an abs_path value
                            # and define "full_reg_path" to assist.
                            #
                            # When registers reside at the top level without a specified path, use 'top'.
                            if reg.owner.path.nil? || reg.owner.path.empty?
                              regpath = 'top'
                            else
                              regpath = reg.owner.path
                            end
                            # If :full_reg_path is defined, the :abs_path metadata for a register will
                            # be used for regpath.  This can be assigned at an address block (sub-block)
                            # level.
                            unless options[:full_reg_path].nil? == true
                              regpath = reg.path
                            end
                            if options[:schema] == '1685-2009'
                              spirit.parameters do
                                spirit.parameter do
                                  spirit.name '_hdlPath_'
                                  # HDL path needs to be to the declared bit field name, NOT to the bus slice
                                  # that Origen's "abs_path" will yield.  Ex:
                                  #
                                  # ~~~ ruby
                                  # reg :myreg, 0x0, size: 32 do |reg|
                                  #   bits 7..4, :bits_high
                                  #   bits 3..0, :bits_low
                                  # end
                                  # ~~~
                                  #
                                  # The abs_path to ...regs(:myreg).bits(:bits_low).abs_path will yield
                                  # "myreg.myreg[3:0]", not "myreg.bits_low".  This is not an understood path
                                  # in Origen (myreg[3:0] does not exist in either myreg's RegCollection or BitCollection),
                                  # and does not sync with how RTL would create bits_low[3:0].
                                  # Therefore, use the path to "myreg"'s owner appended with bits.name (bits_low here).
                                  #
                                  # This can be done in a register or sub_blocks definition by defining register
                                  # metadata for "abs_path".  If the reg owner's path weren't used, but instead the
                                  # reg's path, that would imply each register was a separate hierarchical path in
                                  # RTL (ex: "top.myblock.regblock.myreg.myreg_bits"), which is normally not the case.
                                  # The most likely path would be "top.myblock.regblock.myreg_bits.
                                  spirit.value "#{regpath}.#{bits.name}"
                                end
                              end
                            end
                            # C. Hume - Unclear which vendorExtensions should be included by default, if any.
                            # Future improvment: Allow passing of vendorExtensions enable & value hash/string
                            # if options[:schema] == '1685-2009'
                            #   spirit.vendorExtensions do
                            #     vendorext = { 'xmlns:vendorExtensions' => '$UVM_RGM_HOME/builder/ipxact/schema' }
                            #     xml['vendorExtensions'].hdl_path vendorext, "#{reg.path}.#{bits.name}"
                            #   end
                            # end

                            # Allow optional inclusion of bit field values and descriptions
                            if options[:include_bit_field_values]
                              if bits.bit_value_descriptions[0]
                                bits.bit_value_descriptions.each do |val, desc|
                                  spirit.values do
                                    spirit.value val.to_hex
                                    spirit.name "val_#{val.to_hex}"
                                    spirit.description desc
                                  end
                                end
                              end
                            end
                            if uvm? && !(options[:schema] == '1685-2009')
                              spirit.vendorExtensions do
                                xml['vendorExtensions'].hdl_path "#{regpath}.#{bits.name}"
                              end
                            end
                          end
                        end
                      end
                    end
                    # Unclear whether addressBlock vendor extensions are supported in Spirit 1.4
                    # if uvm?
                    #  spirit.vendorExtensions do
                    #    xml['vendorExtensions'].hdl_path sub_block.path(relative_to: owner)
                    #  end
                    # end
                  end
                end
                # Assume byte addressing if not specified
                if owner.methods.include?(:lau) == false
                  if methods.include?(:lau) == true
                    spirit.addressUnitBits lau
                  else
                    spirit.addressUnitBits 8
                  end
                else
                  spirit.addressUnitBits owner.lau
                end
              end
            end
          end
        end
      end
      # When testing with 'origen examples', travis_ci (bash) will end up with empty tags -
      # '<spirit:description/>' that do not appear on some user's tshell environments.  To
      # prevent false errors for this issue, force Nokogiri to use self-closing tags
      # ('<spirit:description></spirit:description>'), but keep the XML formatted for readability.
      # All tags with no content will appear as '<spirit:tag_name></spirit:tag_name>'.
      #
      builder.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::NO_EMPTY_TAGS |
                                Nokogiri::XML::Node::SaveOptions::FORMAT)
    end

    private

    def open_memory_map(doc)
      maps = doc.xpath('//spirit:memoryMaps/spirit:memoryMap')
      maps = [nil] if maps.empty?
      maps.each do |mem_map|
        yield mem_map
      end
    end

    def reg_description(register)
      fetch register.at_xpath('spirit:description'), get_text: true, whitespace: true
    end

    def bit_description(bit)
      desc = fetch(bit.at_xpath('spirit:description'), get_text: true, whitespace: true) || ''
      bit_val_present = false
      bit.xpath('spirit:values').each do |val|
        unless bit_val_present
          desc += "\n"
          bit_val_present = true
        end
        value = extract(val, 'spirit:value', format: :integer, hex: true)
        value_desc = extract val, 'spirit:description'
        if value && value_desc
          desc += "\n#{value.to_s(2)} | #{value_desc}"
        end
      end
      desc
    end

    def mask(reg)
      m = 0
      reg.size.times do |i|
        unless reg[i].reset_val == :undefined
          m |= (1 << i)
        end
      end
      m
    end

    def uvm?
      @format == :uvm
    end

    def memory_maps
      { nil => {} }
    end

    def sub_blocks(domain_name)
      owner.all_sub_blocks.select do |sub_block|
        sub_block.owns_registers? &&
          (sub_block.domains[domain_name] || domain_name == :default)
      end
    end

    def address_blocks
      domains = owner.register_domains
      domains = { default: {} } if domains.empty?
      domains.each do |domain_name, domain|
        if owner.owns_registers?
          yield domain_name, domain, owner
        end
        sub_blocks(domain_name).each do |sub_block|
          yield domain_name, domain, sub_block
        end
      end
    end

    def address_block_name(domain_name, sub_block)
      if domain_name == :default
        sub_block.name.to_s
      else
        "#{domain_name}_#{sub_block.name}"
      end
    end

    def width(sub_block)
      sub_block.try(:width) || 32
    end

    def range(sub_block)
      range = sub_block.try(:range) || begin
        # This is to work around an Origen bug where max_address_reg_size is not updated in the case of
        # only one register being present
        # TODO: Fix in Origen
        max_address_reg_size = sub_block.max_address_reg_size || sub_block.regs.first[1].size
        (sub_block.max_reg_address + (max_address_reg_size / 8))
      end
      width_in_bytes = width(sub_block) / 8
      if range % width_in_bytes != 0
        range += (width_in_bytes - (range % width_in_bytes))
      end
      range
    end
  end
end
