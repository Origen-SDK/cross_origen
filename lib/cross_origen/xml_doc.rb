require 'kramdown'
require 'sanitize'

module CrossOrigen
  # This is the base class of all doc formats that are
  # XML based
  class XMLDoc
    CreationInfo = Struct.new(:author, :date, :revision, :source)

    ImportInfo = Struct.new(:name, :date)

    attr_accessor :creation_info, :import_info

    # These (in many cases illegal) tags will be forced to their valid equivalents
    # These will be executed in the defined order, so for later xfrms you can for example
    # assume that all 'rows' have already been converted to 'tr'
    # valid equivalents
    HTML_TRANSFORMS = {
      'table/title'  => 'caption',
      'table//row'   => 'tr',
      'thead//entry' => 'th',
      'table//entry' => 'td',
      'td/p'         => 'span',
      'th/p'         => 'span'
    }

    # This can be used to perform additional by-node transformation if required, normally
    # this should be used if transform of a node attribute is required
    HTML_TRANSFORMER = lambda do |env|
      if env[:node_name] == 'td' || env[:node_name] == 'th'
        if env[:node].attr('nameend')
          first = env[:node].attr('namest').sub('col', '').to_i
          last = env[:node].attr('nameend').sub('col', '').to_i
          env[:node].set_attribute('colspan', (last - first + 1).to_s)
        end
      end
    end

    # Defines the rules for sanitization of any HTML strings that will be converted
    # to markdown for representation within Origen
    HTML_SANITIZATION_CONFIG = {
      # Only these tags will be allowed through, everything else will be stripped
      # Note that this is applied after the transforms listed above
      elements:     %w(b em i strong u p ul ol li table tr td th tbody thead),
      attributes:   {
        'td' => ['colspan'],
        'th' => ['colspan']
      },
      # Not planning to allow any of these right now, but keeping around
      # as an example of how to do so
      #:protocols => {
      #  'a' => {'href' => ['http', 'https', 'mailto']}
      # }
      transformers: HTML_TRANSFORMER
    }

    # Returns the object that included the CrossOrigen module
    attr_reader :owner

    def initialize(owner)
      @owner = owner
      @creation_info = CreationInfo.new
      @import_info = ImportInfo.new
    end

    # Tries the given methods on the owner and returns the first one to return a value,
    # ultimately returns nil if no value is found.
    #
    # To test an object other than the owner pass it as the first argument.
    def try(*methods)
      if methods.first.is_a?(Symbol)
        obj = owner
      else
        obj = methods.shift
      end
      methods.each do |method|
        if obj.respond_to?(method)
          val = obj.send(method)
          return val if val
        end
      end
      nil
    end

    # This returns the doc wrapped by a Nokogiri doc
    def doc(path, _options = {})
      require 'nokogiri'

      File.open(path) do |f|
        yield Nokogiri::XML(f)
      end
    end

    def extract(element, path, options = {})
      options = {
        format:   :string,
        hex:      false,
        default:  nil,
        downcase: false,
        return:   :text,
        # A value or array or values which are considered to be nil, if this is the value
        # to be returned then nil will be returned instead
        nil_on:   false
      }.merge(options)
      node = element.at_xpath(path)
      if node
        if options[:format] == :string
          str = node.send(options[:return]).strip
          str = str.downcase if options[:downcase]
          if options[:nil_on] && [options[:nil_on]].flatten.include?(str)
            nil
          else
            str
          end
        elsif options[:format] == :integer
          val = node.send(options[:return])
          if val =~ /^0x(.*)/
            Regexp.last_match[1].to_i(16)
          elsif options[:hex]
            val.to_i(16)
          else
            val.to_i(10)
          end
        else
          fail "Unknown format: #{options[:format]}"
        end
      else
        options[:default]
      end
    end

    # Freescale register descriptions are like the wild west, need to do some pre-screening
    # to approach valid HTML before handing off to other off the shelf sanitizers
    def pre_sanitize(html)
      html = Nokogiri::HTML.fragment(html)
      HTML_TRANSFORMS.each do |orig, new|
        html.xpath(".//#{orig}").each { |node| node.name = new }
      end
      html.to_html
    end

    # Does its best to convert the given html fragment to markdown
    #
    # The final markdown may still contain some HTML tags, but any weird
    # markup which may break a future markdown -> html conversion will
    # be removed
    def to_markdown(html, _options = {})
      cleaned = html.scrub
      cleaned = pre_sanitize(cleaned)
      cleaned = Sanitize.fragment(cleaned, HTML_SANITIZATION_CONFIG)
      Kramdown::Document.new(cleaned, input: :html).to_kramdown.strip
    rescue
      'The description could not be imported, the most likely cause of this is that it contained illegal HTML markup'
    end

    # Convert the given markdown string to HTML
    def to_html(string, _options = {})
      # Escape any " that are not already escaped
      string.gsub!(/([^\\])"/, '\1\"')
      # Escape any ' that are not already escaped
      string.gsub!(/([^\\])'/, %q(\1\\\'))
      html = Kramdown::Document.new(string, input: :kramdown).to_html
    end

    # fetch an XML snippet passed and extract and format the data
    def fetch(xml, options = {})
      options = {
        type:          String,
        downcase:      false,
        symbolize:     false,
        strip:         false,
        squeeze:       false,
        squeeze_lines: false,
        rm_specials:   false,
        whitespace:    false,
        get_text:      false,
        to_i:          false,
        to_html:       false,
        to_bool:       false,
        children:      false,
        to_dec:        false,
        to_f:          false,
        underscore:    false
      }.update(options)
      options[:symbolize] = options[:to_sym] if options[:to_sym]
      # Check for incompatible options
      xml_orig = xml
      numeric_methods = [:to_i, :to_f, :to_dec]
      if options[:get_text] == true && options[:to_html] == true
        fail 'Cannot use :get_text and :to_html options at the same time, exiting...'
      end
      if options[:symbolize] == true
        fail 'Cannot convert to a number of any type and symbolize at the same time' if numeric_methods.reject { |arg| options[arg] == true }.size < 3
      end
      fail 'Cannot select multiple numeric conversion args at the same time' if numeric_methods.reject { |arg| options[arg] == true }.size < 2
      if xml.nil?
        Origen.log.debug 'XML data is nil!'
        return nil
      end
      xml = xml.text if options[:get_text] == true
      # Sometimes XML snippets get sent as nodes or as Strings
      # Must skip this code if a String as it is designed to change
      # the XML node into a string
      unless xml.is_a? String
        if options[:to_html] == true
          if xml.children
            # If there are children to this XMl node then grab the content there
            if xml.children.empty? || options[:children] == false
              xml = xml.to_html
            else
              xml = xml.children.to_html
            end
          end
        end
      end
      unless xml.is_a? options[:type]
        Origen.log.debug "XML data is not of correct type '#{options[:type]}'"
        Origen.log.debug "xml is \n#{xml}"
        return nil
      end
      if options[:type] == String
        if xml.match(/\s+/) && options[:whitespace] == false
          Origen.log.debug "XML data '#{xml}' cannot have white space"
          return nil
        end
        xml.downcase! if options[:downcase] == true
        xml = xml.underscore if options[:underscore] == true
        xml.strip! if options[:strip] == true
        xml.squeeze!(' ') if options[:squeeze] == true
        xml = xml.squeeze_lines if options[:squeeze_lines] == true
        xml.gsub!(/[^0-9A-Za-z]/, '_') if options[:rm_specials] == true
        if options[:symbolize] == true
          return xml.to_sym
        elsif options[:to_i] == true
          return xml.to_i
        elsif options[:to_dec] == true
          return xml.to_dec
        elsif options[:to_f] == true
          return xml.to_f
        elsif [true, false].include?(xml.to_bool) && options[:to_bool] == true
          # If the string can convert to Boolean then return TrueClass or FalseClass
          return xml.to_bool
        else
          return xml
        end
      else
        # No real examples yet of non-string content
        return xml
      end
    end
  end
end
