module RosettaStone
  class OrigenFormat
    require 'nokogiri'

    SUB_BLOCK_ATTRS = {
      base_address:    'IP base address',
      byte_order:      'Describes endianness of the IP.  Values possible are :big_endian and :little_endian',
      lau:             'IP Least Addressable Unit: Values possible are (1..32)',
      version:         'IP version',
      instance:        'IP instance',
      instance_module: 'IP module',
      class_name:      'Class name',
      instance:        'IP instance',
      instance_module: 'IP module',
      addr_block_name: 'Address block name',
      space:           'Address block space'
    }

    FILE_COMMENTS = {
      class: "\# This file is created by RGen via RosettaStone::OrigenFormat#models_to_rb, and is read-only.\n\# If you need to make changes, re-open the class\n",
      incl:  "\# This file is created by RGen via RosettaStone::OrigenFormat#models_to_rb, and is read-only"
    }

    attr_reader :obj, :top_level_class, :top_level_hierarchy, :output_dir, :top_level_path, :incl_path, :incl_dir, :file_content

    def initialize(options = {})
      options = {
        obj:  $dut,
        path: "#{RGen.root!}/output"
      }.update(options)
      @obj = options[:obj]
      @output_dir = options[:path]
      @top_level_path = "#{output_dir}/top_level.rb"
      @incl_path = "#{output_dir}/sub_blocks.rb"
      @incl_dir = "#{output_dir}/import"
      @top_level_hierarchy = get_namespace(options)
      @top_level_class = @top_level_hierarchy.keys.last

      # first key is file type (:bom or :incl) and second is object name
      @file_content = Hash.new do |h, k|
        h[k] = {}
      end
    end

    def export
      # Delete any previous files
      FileUtils.rm_rf(@incl_dir) if File.exist?(@incl_dir)
      FileUtils.mkdir_p(@incl_dir)

      # Check if previous version of top-level files exist and delete them
      File.delete(@top_level_path) if File.exist?(@top_level_path)
      File.delete(@incl_path) if File.exist?(@incl_path)

      # Create the sub_block objects in the top_level.rb file
      # This method will create each required class file recursively (indirectly)
      # and will gather all of the information required to create the include file.
      # In essence it does it all
      create_bom
    end

    private

    # Creates the BoM file that creates the sub_blocks from the meta-modelled sub_blocks
    def create_bom
      indent = ''
      file_content = {}
      full_class = @top_level_hierarchy.keys.last
      klass = @top_level_class.demodulize
      RGen.log.info 'Exporting to Origen format...'
      File.open(@top_level_path, 'w') do |bom_file|
        # bom_file.chmod(0555)
        bom_file.puts(FILE_COMMENTS[:incl])
        bom_file.puts("require_relative 'sub_blocks'")
        @top_level_hierarchy.each do |name, obj|
          bom_file.puts("#{indent}#{obj} #{name.split('::').last}")
          indent += '  '
        end
        bom_file.puts("#{indent}include RGen::Model")
        bom_file.puts('')
        bom_file.puts("#{indent}def initialize")
        indent += '  '
        # This method is recursive (indirectly) so file_content should find all BoM and include file strings
        create_file_content(@obj, indent)
        @file_content.each do |file_type, str_hash|
          if file_type == :bom
            str_hash.each do |_obj, str|
              bom_file.puts(str)
            end
          elsif file_type == :incl
            # Create the include file
            File.open(@incl_path, 'w') do |incl_file|
              str_hash.each do |_obj, str|
                incl_file.puts(str)
              end
            end
          else
            RGen.log.error 'Incorrect key for @file_content instance variable Hash, must be :incl or :bom'
          end
        end
        if @obj.owns_registers?
          @obj.regs.each do |_reg_name, r|
            reg_path = r.path.gsub(/#{klass}./i, '')
            reg_path.chop! if reg_path[-1] == '.'
            r.description.each do |line|
              bom_file.puts("#{indent}# #{line}")
            end
            reg_string = "#{indent}reg :#{r.name}, #{r.address.to_hex}, size: #{r.size}"
            if r.respond_to? :bit_order
              if r.bit_order.is_a?(String)
                reg_string += ", bit_order: '#{r.bit_order}'"
              elsif r.bit_order.is_a?(Symbol)
                reg_string += ", bit_order: :#{r.bit_order}"
              elsif r.bit_order.is_a?(NilClass)
              # do not add bitorder if it is not available
              else
                reg_string += ", bit_order: #{r.bit_order}"
              end
            end
            if r.respond_to? :space
              if r.space.is_a?(String)
                reg_string += ", space: '#{r.space}'"
              elsif r.space.is_a?(Symbol)
                reg_string += ", space: :#{r.space}"
              else
                reg_string += ", space: #{r.space}"
              end
            end
            bom_file.puts("#{reg_string} do |reg|")
            indent += '  '
            r.named_bits do |field, bits|
              if bits.size > 1
                bit_index = "#{bits.position}..#{bits.position + bits.size - 1}"
              else
                bit_index = bits.position.to_s
              end
              bits.description.each do |line|
                bom_file.puts("#{indent}# #{line}")
              end
              bom_file.puts("#{indent}reg.bit #{bit_index}, :#{field}, reset: 0b#{bits.reset_val.to_s(2)}, access: :#{bits.access}")
            end
            indent = indent[0..-3]
            bom_file.puts("#{indent}end")
          end
        end
        indent = indent[0..-3]
        bom_file.puts("#{indent}end")
        @top_level_hierarchy.each do |_name, _obj|
          indent = indent[0..-3]
          bom_file.puts("#{indent}end")
        end
      end
      # Give a newline on console to sepearate out the '.' used for progress indicator
      puts
    end

    # Create the bom string for the current object.  Recursive method until no more sub_blocks are found for the current object
    def create_file_content(obj, indent)
      unless obj.respond_to?(:sub_blocks) && obj.send(:sub_blocks)
        RGen.log.warn 'Object argument does not have sub_blocks, ignoring it...'
        return
      end
      obj.sub_blocks.each do |name, sb|
        @file_content[:bom][name] = "#{indent}sub_block :#{name}"
        instance_vars_with_content(sb).each do |attr, value|
          if value.is_a?(String)
            @file_content[:bom][name] += ", #{attr}: '#{value}'"
          elsif value.is_a?(Symbol)
            @file_content[:bom][name] += ", #{attr} = :#{value}"
          else
            if attr == :base_address
              @file_content[:bom][name] += ", #{attr}: #{value.to_hex}"
            else
              @file_content[:bom][name] += ", #{attr}: #{value}"
            end
          end
        end
        @file_content[:bom][name] += ", abs_path: '#{sb.path}'"
        # Add on the class_name attr as this is not part of the sub_block meta_model
        class_name = sb.class.to_s.demodulize
        if class_name == 'SubBlock'
          file_content[:bom][name] += ", class_name: '#{sb.name.upcase}'"
        else
          file_content[:bom][name] += ", class_name: '#{class_name}'"
        end
        # Create the class file for this object
        create_class_file(sb)
      end
    end

    def create_class_file(obj)
      ivars_content = {}
      ivars_content = instance_vars_with_content(obj)
      indent = ''
      klass = get_full_class(obj)
      class_path_addition = (klass.split('::') - @top_level_class.split('::')).join('/').downcase
      @file_content[:incl][klass] = "require_relative 'import/#{class_path_addition}'"
      class_file_name = Pathname.new("#{@incl_dir}/#{class_path_addition}.rb")
      class_file_dir = class_file_name.dirname
      unless class_file_dir.exist?
        RGen.log.debug "app: Directory #{class_file_dir} does not exist, creating it..."
        FileUtils.mkdir_p(class_file_dir)
      end
      File.open(class_file_name, 'w') do |file|
        # file.chmod(0555)
        file.puts('# -*- encoding : utf-8 -*-') if RUBY_VERSION < '2.0.0'
        file.puts(FILE_COMMENTS[:class])
        # print out the top level object hierarchy
        @top_level_hierarchy.each do |name, o|
          file.puts("#{indent}#{o} #{name.split('::').last}")
          indent += '  '
        end
        # print out the current object's sub-hierarchy
        sub_array = klass.split('::') - @top_level_class.split('::')
        object_type_array = %w(class) * sub_array.size
        sub_hierarchy = Hash[sub_array.zip object_type_array]
        sub_hierarchy.each do |name, o|
          if o == sub_hierarchy.values.last
            file.puts("#{indent}#{o} #{name.split('::').last} # rubocop:disable ClassLength")
          else
            file.puts("#{indent}#{o} #{name.split('::').last}")
          end
          indent += '  '
        end
        file.puts("#{indent}include RGen::Model")
        file.puts('')
        instance_vars_with_content(obj).each do |attr, _value|
          file.puts("#{indent}# #{SUB_BLOCK_ATTRS[attr]}")
          file.puts("#{indent}attr_reader :#{attr}")
          file.puts('')
        end
        file.puts("#{indent}def initialize(options = {})")
        indent += '  '
        instance_vars_with_content(obj).each do |attr, value|
          if value.is_a?(String)
            file.puts("#{indent}\@#{attr} = '#{value}'")
          elsif value.is_a?(Symbol)
            file.puts("#{indent}\@#{attr} = :#{value}")
          else
            if attr == :base_address
              file.puts("#{indent}\@#{attr} = #{value.to_hex}")
            else
              file.puts("#{indent}\@#{attr} = #{value}")
            end
          end
        end
        # If the current object has sub_block they need to be instantiated in the init
        if obj.respond_to?(:sub_blocks)
          obj.sub_blocks.each do |n, block|
            bom_string = "#{indent}sub_block :#{n}"
            instance_vars_with_content(block).each do |attr, value|
              if value.is_a?(String)
                bom_string += ", #{attr}: '#{value}'"
              elsif value.is_a?(Symbol)
                bom_string += ", #{attr}: :#{value}"
              else
                if attr == :base_address
                  bom_string += ", #{attr}: #{value.to_hex}"
                else
                  bom_string += ", #{attr}: #{value}"
                end
              end
            end
            bom_string += ", abs_path: '#{block.path}'"
            # Add on the class_name attr as this is not part of the sub_block meta_model
            class_name = block.class.to_s.split('::').last
            if class_name == 'SubBlock'
              bom_string += ", class_name: '#{block.name.upcase}'"
            else
              bom_string += ", class_name: '#{class_name}'"
            end
            file.puts(bom_string)
          end
        end
        file.puts("#{indent}instantiate_registers(options)") if obj.owns_registers?
        indent = indent[0..-3]
        file.puts("#{indent}end")
        if obj.owns_registers?
          file.puts('')
          file.puts("#{indent}# rubocop:disable LineLength")
          # Need the register and bit_field descriptions to use double quotes
          file.puts("#{indent}# rubocop:disable StringLiterals")
          file.puts("#{indent}def instantiate_registers(options = {}) # rubocop:disable MethodLength")
          indent += '  '
          obj.regs.each do |_reg_name, r|
            reg_addr_offset = (r.address - obj.base_address).to_hex
            reg_path = r.path.gsub(/#{klass}./i, '')
            reg_path.chop! if reg_path[-1] == '.'
            r.description.each do |line|
              file.puts("#{indent}# #{line}")
            end
            reg_string = "#{indent}reg :#{r.name}, #{reg_addr_offset}, size: #{r.size}"
            if r.respond_to? :bit_order
              if r.bit_order.is_a?(String)
                reg_string += ", bit_order: '#{r.bit_order}'"
              elsif r.bit_order.is_a?(Symbol)
                reg_string += ", bit_order: :#{r.bit_order}"
              elsif r.bit_order.is_a?(NilClass)
              # do not add bitorder if it is not available
              else
                reg_string += ", bit_order: #{r.bit_order}"
              end
            end
            if r.respond_to? :space
              if r.space.is_a?(String)
                reg_string += ", space: '#{r.space}'"
              elsif r.space.is_a?(Symbol)
                reg_string += ", space: :#{r.space}"
              else
                reg_string += ", space: #{r.space}"
              end
            end
            file.puts("#{reg_string} do |reg|")
            indent += '  '
            r.named_bits do |field, bits|
              plain_bit_description = Nokogiri::HTML(bits.description.join(' ').to_s).text
              plain_bit_description.gsub!(/"/, "'")
              if bits.size > 1
                bit_index = "#{bits.position + bits.size - 1}..#{bits.position}"
              else
                bit_index = bits.position.to_s
              end
              bits.description.each do |line|
                file.puts("#{indent}# #{line}")
              end
              file.puts("#{indent}reg.bit #{bit_index}, :#{field}, reset: 0b#{bits.reset_val.to_s(2)}, access: :#{bits.access}")
            end
            indent = indent[0..-3]
            file.puts("#{indent}end")
          end
          indent = indent[0..-3]
          file.puts("#{indent}end")
        end
        @top_level_hierarchy.each do |_name, _obj|
          indent = indent[0..-3]
          file.puts("#{indent}end")
        end
        sub_hierarchy.each do |_name, _obj|
          indent = indent[0..-3]
          file.puts("#{indent}end")
        end
      end
      # Place a '.' to the console to indicate file write progress to the user
      print '.'
      # If the current obj has sub_blocks then write those class files
      if obj.respond_to?(:sub_blocks) && obj.send(:sub_blocks)
        obj.sub_blocks.each do |_name, sb|
          create_class_file(sb)
        end
      end
    end

    # Creates the class files for the sub_blocks instantiated in the BoM
    def create_class_files
      indent = ''
      object_hierarchy = get_namespace(@obj)
      klass = @obj.class.to_s.split('::').last
      File.open(@incl_path, 'w') do |incl_file|
        incl_file.chmod(0555)
        incl_file.puts(FILE_COMMENTS[:incl])
        @obj.sub_blocks.each do |_name, sb|
          current_bist = nil
          bypass_addr = 0
          incl_file.puts("require_relative 'import/#{sb.name}.rb'")
          File.open("#{@incl_dir}/#{sb.name}.rb", 'w') do |file|
            file.chmod(0555)
            file.puts('# -*- encoding : utf-8 -*-') if RUBY_VERSION < '2.0.0'
            file.puts(FILE_COMMENTS[:class])
            object_hierarchy.each do |name, obj|
              file.puts("#{indent}#{obj} #{name.split('::').last}")
              indent += '  '
            end
            file.puts("#{indent}class #{sb.name.upcase} # rubocop:disable ClassLength")
            indent += '  '
            file.puts("#{indent}include RGen::Model")
            file.puts('')
            SUB_BLOCK_ATTRS.each do |attr, comment|
              attr_sym = ":#{attr}"
              # First check that the attribute has content
              if sb.respond_to?(attr)
                next if sb.send(eval(attr_sym)).nil?
                file.puts("#{indent}# #{comment}")
                file.puts("#{indent}attr_reader :#{attr}")
                file.puts('')
              end
            end
            file.puts("#{indent}def initialize(options = {})")
            indent += '  '
            SUB_BLOCK_ATTRS.keys.each do |attr|
              case attr
                when /base_address/
                  attr_var = ":@reg_#{attr}"
                  file.puts("#{indent}\@#{attr} = #{sb.instance_variable_get(eval(attr_var)).to_hex}")
                else
                  attr_var = ":@#{attr}"
                  attr_sym = ":#{attr}"
                  # First check that the attribute has content
                  if sb.respond_to?(attr)
                    next if sb.send(eval(attr_sym)).nil?
                    if sb.instance_variable_get(eval(attr_var)).is_a?(String)
                      file.puts("#{indent}\@#{attr} = '#{sb.instance_variable_get(eval(attr_var))}'")
                    elsif sb.instance_variable_get(eval(attr_var)).is_a?(Symbol)
                      file.puts("#{indent}\@#{attr} = :#{sb.instance_variable_get(eval(attr_var))}")
                    else
                      file.puts("#{indent}\@#{attr} = #{sb.instance_variable_get(eval(attr_var))}")
                    end
                  end
              end
            end
            file.puts("#{indent}instantiate_registers(options)")
            indent = indent[0..-3]
            file.puts("#{indent}end")
            file.puts('')
            file.puts("#{indent}# rubocop:disable LineLength")
            # Need the register and bit_field descriptions to use double quotes
            file.puts("#{indent}# rubocop:disable StringLiterals")
            file.puts("#{indent}def instantiate_registers(options = {}) # rubocop:disable MethodLength")
            indent += '  '
            sb.regs.each do |_reg_name, r|
              reg_addr_offset = (r.address - sb.base_address).to_hex
              reg_path = r.path.gsub(/#{klass}./i, '')
              reg_path.chop! if reg_path[-1] == '.'
              r.description.each do |line|
                file.puts("#{indent}# #{line}")
              end
              reg_string = "#{indent}reg :#{r.name}, #{reg_addr_offset}, size: #{r.size}"
              if r.respond_to? :bit_order
                if r.bit_order.is_a?(String)
                  reg_string += ", bit_order: '#{r.bit_order}'"
                elsif r.bit_order.is_a?(Symbol)
                  reg_string += ", bit_order: :#{r.bit_order}"
                elsif r.bit_order.is_a?(NilClass)
                  # do not add bitorder if it is not available
                else
                  reg_string += ", bit_order: #{r.bit_order}"
                end
              end
              if r.respond_to? :space
                if r.space.is_a?(String)
                  reg_string += ", space: '#{r.space}'"
                elsif r.space.is_a?(Symbol)
                  reg_string += ", space: :#{r.space}"
                else
                  reg_string += ", space: #{r.space}"
                end
              end
              file.puts("#{reg_string} do |reg|")
              indent += '  '
              r.named_bits do |field, bits|
                plain_bit_description = Nokogiri::HTML(bits.description.join(' ').to_s).text
                plain_bit_description.gsub!(/"/, "'")
                if bits.size > 1
                  bit_index = "#{bits.position + bits.size - 1}..#{bits.position}"
                else
                  bit_index = bits.position.to_s
                end
                bits.description.each do |line|
                  file.puts("#{indent}# #{line}")
                end
                file.puts("#{indent}reg.bit #{bit_index}, :#{field}, reset: 0b#{bits.reset_val.to_s(2)}, access: :#{bits.access}")
              end
              indent = indent[0..-3]
              file.puts("#{indent}end")
            end
            indent = indent[0..-3]
            file.puts("#{indent}end")
            indent = indent[0..-3]
            file.puts("#{indent}end")
            object_hierarchy.each do |_name, _obj|
              indent = indent[0..-3]
              file.puts("#{indent}end")
            end
          end
        end
      end
    end

    # Returns a hash (key == scope, value is 'module' or 'class') needed to
    # reconstruct the application hierarchy
    def get_namespace(options)
      obj = options[:obj]
      namespace = []
      object_hierarchy = {}
      namespace =  obj.class.to_s.split('::')
      namespace.pop if options[:class_name]
      curr_eval = nil
      scope = nil
      namespace.each_with_index do |e, _i|
        scope.nil? ? scope = e : scope += "::#{e}"
        curr_eval = "#{scope}.class"
        object_hierarchy["#{scope}"] = eval(curr_eval).to_s.downcase
      end
      if options[:class_name]
        if object_hierarchy.empty?
          object_hierarchy[options[:class_name]] = "class"
        else
          object_hierarchy["#{object_hierarchy.keys.last}::#{options[:class_name]}"] = "class"
        end
      end
      object_hierarchy
    end

    # Returns a hash of all of the non-nil instance_variables for an instance
    def instance_vars_with_content(obj)
      ivars_content = {}
      obj.instance_variables.each do |ivar|
        ivar_sym = ivar.to_s.gsub('@', '').to_sym
        # Check for reg_base_address as method base_address refers to this instance variable
        # Could use reg_base_address but all docs show to use base_address in the sub_block calls
        # If not reg_base_address the ivar must be included in SUB_BLOCK_ATTRS
        next unless ivar_sym == :reg_base_address || SUB_BLOCK_ATTRS.include?(ivar_sym)
        # Skip the instance variable if it is nil
        next if obj.send(ivar_sym).nil?
        if ivar_sym == :reg_base_address
          ivars_content[:base_address] = obj.send(ivar_sym)
        else
          ivars_content[ivar_sym] = obj.send(ivar_sym)
        end
      end
      ivars_content
    end

    # Recursively work through the object hierarchy and return the full class string
    def get_full_class(obj)
      class_str = ''
      until obj.nil?
        if obj == RGen.top_level
          class_str.prepend @top_level_hierarchy.keys.last
        else
          # If the class method produces "SubBlock" then use the object name instead
          if obj.class.to_s.split('::').last == 'SubBlock'
            class_str.prepend "::#{obj.name.upcase}"
          else
            class_str.prepend "::#{obj.class.to_s.split('::').last}"
          end
        end
        obj = obj.parent
      end
      class_str
    end
  end
end
