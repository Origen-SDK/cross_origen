module CrossOrigen
  class Headers
    # Returns the object that included the CrossOrigen module
    attr_reader :owner

    def initialize(owner)
      @owner = owner
    end

    # Returns a string representing the owner as a C header
    def owner_to_header(_options = {})
      Origen.compile("#{path_to_templates}/headers/default.h.erb", scope: owner)
    end

    private

    def path_to_templates
      "#{File.expand_path(File.dirname(__FILE__))}/../../templates"
    end
  end
end
