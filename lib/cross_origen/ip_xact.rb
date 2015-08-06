module CrossOrigen
  class IpXact < XMLDoc
    AddressSpace = Struct.new(:name, :range, :width)

    MemoryMaps = Struct.new(:name, :address_blocks)

    AddressBlock = Struct.new(:name, :base_address, :range, :width)

    # Import/reader that currently only supports creating registers and bit fields
    def import(file, options = {}) # rubocop:disable CyclomaticComplexity
      require 'kramdown'

      address_spaces = {}

      doc(file, options) do |doc|
        doc.xpath('//spirit:addressSpaces/spirit:addressSpace').each do |addr_space|
          name = fetch addr_space.at_xpath('spirit:name'), downcase: true, to_sym: true, get_text: true
          range = fetch addr_space.at_xpath('spirit:range'), get_text: true, to_dec: true
          width = fetch addr_space.at_xpath('spirit:width'), get_text: true, to_i: true
          address_spaces[name] = AddressSpace.new(name, range, width)
        end
        doc.xpath('//spirit:memoryMaps/spirit:memoryMap').each do |mem_map|
          mem_map_name = fetch mem_map.at_xpath('spirit:name'), downcase: true, to_sym: true, get_text: true
          owner.sub_block mem_map_name
          mem_map_obj = owner.send(mem_map_name)
          mem_map.xpath('spirit:addressBlock').each do |addr_block|
            name = fetch addr_block.at_xpath('spirit:name'), downcase: true, to_sym: true, get_text: true
            base_address = fetch addr_block.at_xpath('spirit:baseAddress'), get_text: true, to_dec: true
            range = fetch addr_block.at_xpath('spirit:range'), get_text: true, to_dec: true
            width = fetch addr_block.at_xpath('spirit:width'), get_text: true, to_i: true
            mem_map_obj.sub_block name, base_address: base_address, range: range, lau: width
            addr_block_obj = mem_map_obj.send(name)
            addr_block.xpath('spirit:register').each do |register|
              name = fetch register.at_xpath('spirit:name'), downcase: true, to_sym: true, get_text: true
              size = fetch register.at_xpath('spirit:size'), get_text: true, to_i: true
              addr_offset = fetch register.at_xpath('spirit:addressOffset'), get_text: true, to_dec: true
              access = fetch register.at_xpath('spirit:access'), get_text: true
              reset_value = fetch register.at_xpath('spirit:reset/spirit:value'), get_text: true, to_dec: true
              reset_mask = fetch register.at_xpath('spirit:reset/spirit:mask'), get_text: true, to_dec: true
              if [reset_value, reset_mask].include? nil
                # Set default values for some register attributes
                reset_value, reset_mask = 0, 0
              else
                # Do a logical bitwise AND with the reset value and mask
                reset_value = reset_value & reset_mask
              end
              addr_block_obj.reg name, addr_offset, size: size, access: access do |reg|
                register.xpath('spirit:field').each do |field|
                  name = fetch field.at_xpath('spirit:name'), downcase: true, to_sym: true, get_text: true
                  bit_offset = fetch field.at_xpath('spirit:bitOffset'), get_text: true, to_i: true
                  bit_width = fetch field.at_xpath('spirit:bitWidth'), get_text: true, to_i: true
                  access = fetch field.at_xpath('spirit:access'), get_text: true
                  if access =~ /\S+\-\S+/
                    access = access[/^(\S)/, 1] + access[/\-(\S)\S+$/, 1]
                    access = access.downcase.to_sym
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
                  reg.bit range, name, reset: reset_value[range], access: access
                end
              end
            end
          end
        end
      end
    end

    # Returns a string representing the owner object in IP-XACT XML
    def owner_to_xml(options = {})
      require 'builder'

      options = {
        include_bit_field_values: true
      }.merge(options)

      @format = options[:format]

      xml = Builder::XmlMarkup.new(indent: 2, margin: 0)

      xml.instruct!

      schemas = [
        'http://www.spiritconsortium.org/XMLSchema/SPIRIT/1.4',
        'http://www.spiritconsortium.org/XMLSchema/SPIRIT/1.4/index.xsd'
      ]
      if uvm?
        schemas << '$IREG_GEN/XMLSchema/SPIRIT/VendorExtensions.xsd'
      end

      headers = {
        'xmlns:spirit'       => 'http://www.spiritconsortium.org/XMLSchema/SPIRIT/1.4',
        'xmlns:xsi'          => 'http://www.w3.org/2001/XMLSchema-instance',
        'xsi:schemaLocation' => schemas.join(' ')
      }
      if uvm?
        headers['xmlns:vendorExtensions'] = '$IREG_GEN/XMLSchema/SPIRIT'
      end

      xml.tag!('spirit:component', headers) do
        xml.spirit :vendor, options[:vendor] || 'Freescale'
        xml.spirit :library, options[:library] || 'Freescale'
        # I guess this should really be the register owner's owner's name?
        xml.spirit :name, try(:ip_name, :pdm_part_name) || owner.class.to_s.split('::').last
        xml.spirit :version, try(:ip_version, :pdm_version, :pdm_cm_version, :version, :revision)
        xml.spirit :memoryMaps do
          memory_maps.each do |map_name, _map|
            xml.spirit :memoryMap do
              xml.spirit :name, map_name
              address_blocks do |domain_name, _domain, sub_block|
                xml.spirit :addressBlock do
                  xml.spirit :name, address_block_name(domain_name, sub_block)
                  xml.spirit :baseAddress, sub_block.base_address.to_hex
                  xml.spirit :range, range(sub_block)
                  xml.spirit :width, width(sub_block)
                  sub_block.regs.each do |name, reg|
                    # Required for now to ensure that the current value is the reset value
                    reg.reset
                    xml.spirit :register do
                      xml.spirit :name, name
                      xml.spirit :description, try(reg, :name_full, :full_name)
                      xml.spirit :addressOffset, reg.offset.to_hex
                      xml.spirit :size, reg.size
                      if reg.bits.any?(&:writable?)
                        xml.spirit :access, 'read-write'
                      else
                        xml.spirit :access, 'read-only'
                      end
                      xml.spirit :reset do
                        xml.spirit :value, reg.data.to_hex
                        xml.spirit :mask, mask(reg).to_hex
                      end
                      reg.named_bits do |name, bits|
                        xml.spirit :field do
                          xml.spirit :name, name
                          xml.spirit :description, try(bits, :brief_description, :name_full, :full_name)
                          xml.spirit :bitOffset, bits.position
                          xml.spirit :bitWidth, bits.size
                          xml.spirit :access, bits.access
                          if options[:include_bit_field_values]
                            if bits.bit_value_descriptions[0]
                              bits.bit_value_descriptions.each do |val, desc|
                                xml.spirit :values do
                                  xml.spirit :value, val.to_hex
                                  xml.spirit :name, "val_#{val.to_hex}"
                                  xml.spirit :description, desc
                                end
                              end
                            end
                          end
                          if uvm?
                            xml.spirit :vendorExtensions do
                              xml.vendorExtensions :hdl_path, bits.path(relative_to: sub_block)
                            end
                          end
                        end
                      end
                    end
                  end
                  if uvm?
                    xml.spirit :vendorExtensions do
                      xml.vendorExtensions :hdl_path, sub_block.path(relative_to: owner)
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    private

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
      { owner.name => {} }
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
