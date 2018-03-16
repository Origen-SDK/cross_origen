module CrossOrigen
  class CMSISSVD < XMLDoc
    def import(file, options = {}) # rubocop:disable CyclomaticComplexity
      filename = Pathname.new(file).basename('.*').to_s

      unless options[:refresh] || CrossOrigen.refresh?
        return if owner.import(filename, allow_missing: true)
      end

      model = CrossOrigen::Model.new

      doc(file, options) do |doc|
        peripherals = peripherals(doc)
        groups = peripherals.values.map { |v| v[:group] }.uniq

        groups.each { |group| model.sub_block group }

        peripherals.each do |name, attrs|
          base = attrs[:group] ? model.send(attrs[:group]) : model
          block = base.sub_block name, base_address: attrs[:base_address]

          if attrs[:parent]
            add_registers(block, find_peripheral_by_name(doc, attrs[:parent]))
          end
          add_registers(block, find_peripheral_by_name(doc, name))
        end
      end
      model.export(filename, include_timestamp: CrossOrigen.include_timestamp?)
      owner.import(filename)
    end

    private

    def add_registers(model, peripheral)
      peripheral.xpath('registers/register').each do |r|
        name = extract(r, 'name')
        di = extract(r, 'dim', format: :integer)
        dim = !!di
        if dim
          dinc = extract(r, 'dimIncrement', format: :integer)
          dvals = extract(r, 'dimIndex').split(',')
        else
          di = 1
        end
        offset = extract(r, 'addressOffset', format: :integer, hex: true)
        size = extract(r, 'size', format: :integer)
        reset = extract(r, 'resetValue', format: :integer, hex: true)
        desc = (extract(r, 'description') || '').gsub("'", %q(\\\'))

        di.times do |i|
          if dim
            n = name.sub('[%s]', dvals[i])
            addr = offset + (i * dinc)
          else
            n = name
            addr = offset
          end
          opts = {
            size:        size,
            description: desc
          }
          opts[:reset] = reset if reset
          reg_name = n.downcase.symbolize
          # The register could already exist if it was added by a parent peripheral definition and now it
          # is redefined/overridden by a descendent peripheral
          model.del_reg(reg_name) if model.has_reg?(reg_name)
          model.reg reg_name, addr, opts do |reg|
            r.xpath('fields/field').each do |b|
              bn = extract(b, 'name')
              unless bn == 'RESERVED'
                bn = bn.to_s.downcase.symbolize
                lsb = extract(b, 'lsb', format: :integer)
                msb = extract(b, 'msb', format: :integer)
                unless lsb
                  lsb = extract(b, 'bitOffset', format: :integer)
                  if lsb
                    msb = lsb + extract(b, 'msb', format: :integer) - 1
                  end
                end
                unless lsb
                  range = extract(b, 'bitRange')
                  range =~ /\[(\d+):(\d+)\]/
                  lsb = Regexp.last_match(2).to_i
                  msb = Regexp.last_match(1).to_i
                end
                access = extract(b, 'access')
                desc = (extract(r, 'description') || '').gsub("'", %q(\\\'))
                case access
                when 'read-only'
                  ac = :ro
                else
                  ac = :rw
                end
                if lsb == msb
                  reg.bit lsb, bn, access: ac, description: desc
                else
                  reg.bit msb..lsb, bn, access: ac, description: desc
                end
              end
            end
          end
        end
      end
    end

    def find_peripheral_by_name(doc, pname)
      doc.xpath('device/peripherals/peripheral').find do |peripheral|
        pname == name(peripheral)
      end
    end

    def clean_name(name)
      name = name.to_s
      unless name.empty?
        name.downcase.symbolize
      end
    end

    def name(peripheral)
      clean_name(fetch(peripheral.xpath('name'), get_text: true))
    end

    def group_name(peripheral)
      clean_name(fetch(peripheral.xpath('groupName'), get_text: true))
    end

    def parent(peripheral)
      a = peripheral.attributes['derivedFrom']
      a ? clean_name(a.value) : nil
    end

    def base_address(peripheral)
      extract(peripheral, 'baseAddress', format: :integer, hex: true)
    end

    def peripherals(doc)
      peripherals = {}
      doc.xpath('device/peripherals/peripheral').each do |peripheral|
        peripherals[name(peripheral)] = {
          group:        group_name(peripheral),
          parent:       parent(peripheral),
          base_address: base_address(peripheral)
        }
      end
      # Inherit missing values from parents...
      p = {}
      peripherals.each do |k, v|
        v[:group] ||= peripherals[v[:parent]][:group]
        v[:base_address] ||= peripherals[v[:parent]][:base_address]
        p[k] = v
      end
      p
    end
  end
end
