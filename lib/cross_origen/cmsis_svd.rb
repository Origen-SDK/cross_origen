module CrossOrigen
  class CMSISSVD < XMLDoc
    def import(file, options = {}) # rubocop:disable CyclomaticComplexity
      with_output_file(options) do |f|
        doc(file, options) do |doc|
          f.puts '# This file was automatically generated from a CMSIS-SVD input file'
          f.puts '# Name:    ' + (fetch(doc.xpath('device/name'), get_text: true) || '')
          f.puts '# Version: ' + (fetch(doc.xpath('device/version'), get_text: true) || '')
          f.puts "# Created at #{Time.now.strftime('%e %b %Y %H:%M%p')} by #{User.current.name}"
          f.puts '# rubocop:disable all'
          f.puts 'module ImportedCMSISSVD'
          f.puts '  def initialize(*args)'
          f.puts '    instantiate_imported_cmsis_svd_data'
          f.puts '  end'
          f.puts ''
          f.puts '  def instantiate_imported_cmsis_svd_data'

          # Create sub-blocks
          indexes = {}
          doc.xpath('device/peripherals/peripheral').each do |p|
            name = fetch(p.xpath('groupName'), get_text: true)
            name = name.to_s.downcase.symbolize
            ba = extract(p, 'baseAddress', format: :integer, hex: true)
            if j = peripheral_groups(doc)[name] > 1
              indexes[name] ||= 0
              f.puts "    sub_block :#{name}#{indexes[name]}, base_address: #{ba.to_hex}"
              indexes[name] += 1
            else
              f.puts "    sub_block :#{name}, base_address: #{ba.to_hex}"
            end
          end
          f.puts ''

          # Add registers to each sub-block
          indexes = {}
          doc.xpath('device/peripherals/peripheral').each do |p|
            sb = fetch(p.xpath('groupName'), get_text: true)
            sb = sb.to_s.downcase.symbolize
            if j = peripheral_groups(doc)[sb] > 1
              indexes[sb] ||= 0
              ix = indexes[sb]
              indexes[sb] += 1
              sb = "#{sb}#{ix}"
            end

            p.xpath('registers/register').each do |r|
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
                f.puts "    #{sb}.add_reg :#{n.downcase.symbolize}, #{addr.to_hex}, size: #{size}#{reset ? ', reset: ' + reset.to_hex : ''}, description: '#{desc}' do |reg|"
                r.xpath('fields/field').each do |b|
                  bn = extract(b, 'name')
                  unless bn == 'RESERVED'
                    bn = bn.to_s.downcase.symbolize
                    lsb = extract(b, 'lsb', format: :integer)
                    msb = extract(b, 'msb', format: :integer)
                    access = extract(b, 'access')
                    desc = (extract(r, 'description') || '').gsub("'", %q(\\\'))
                    case access
                    when 'read-only'
                      ac = :ro
                    else
                      ac = :rw
                    end
                    if lsb == msb
                      f.puts "      reg.bit #{lsb}, :#{bn}, access: :#{ac}, description: '#{desc}'"
                    else
                      f.puts "      reg.bit #{msb}..#{lsb}, :#{bn}, access: :#{ac}, description: '#{desc}'"
                    end
                  end
                end
                f.puts '    end'
              end
            end
          end

          f.puts '  end'

          # Create accessor methods to return an array of peripherals in the case
          # where there are many in a group
          peripheral_groups(doc).each do |name, size|
            name = name.to_s.downcase.symbolize
            if size > 1
              f.puts ''
              f.puts "  def #{name}"
              f.print '    ['
              size.times do |i|
                if i == 0
                  f.print "#{name}0"
                else
                  f.print ", #{name}#{i}"
                end
              end
              f.puts ']'
              f.puts '  end'
            end
          end

          f.puts 'end'
          f.puts '# rubocop:enable all'
        end
      end
    end

    def peripheral_groups(doc)
      @peripheral_groups ||= begin
        g = {}
        doc.xpath('device/peripherals/peripheral').each do |p|
          group = fetch(p.xpath('groupName'), get_text: true)
          group = group.to_s.downcase.symbolize
          g[group] ||= 0
          g[group] += 1
        end
        g
      end
    end

    def with_output_file(options = {})
      path = options[:output] || 'imported_cmsis_svd.rb'
      File.open(path, 'w') { |f| yield f }
      puts "Successfully imported to #{path}"
    end
  end
end
