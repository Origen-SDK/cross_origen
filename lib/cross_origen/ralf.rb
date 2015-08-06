module CrossOrigen
  class Ralf
    # Returns the object that included the CrossOrigen module
    attr_reader :owner

    def initialize(owner)
      @owner = owner
    end

    # Returns a string representing the owner object in RALF format
    def owner_to_ralf(options = {})
      Origen.compile("#{Origen.root!}/templates/ralf/default.ralf.erb", options.merge(scope: owner))
    end
  end
end
