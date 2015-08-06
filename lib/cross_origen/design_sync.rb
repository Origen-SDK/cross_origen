module RosettaStone
  # Driver for talking to DesignSync
  class DesignSync
    require 'digest/sha1'

    # Returns the object that included the RosettaStone module
    attr_reader :owner

    def initialize(owner)
      @owner = owner
    end

    def driver
      @driver ||= Origen::Utility::DesignSync.new
    end

    # Returns a full path to the Design Sync import (cache) directory
    def import_dir
      return @import_dir if @import_dir
      @import_dir = "#{Origen.app.workspace_manager.imports_directory}/design_sync"
      FileUtils.mkdir_p(@import_dir) unless File.exist?(@import_dir)
      @import_dir
    end

    # This will be called if the user has supplied a :vault in the rs_import options. The corresponding
    # version of the file will be returned from the cache if it already exists locally, otherwise it
    # will be imported.
    #
    # This method returns a full path to the local cache copy of the file.
    def fetch(options = {})
      unless options[:version]
        puts 'You must supply a :version number (or tag) when importing data from Design Sync'
        exit 1
      end
      v = options[:vault]
      f = v.split('/').last
      vault = v.sub(/\/#{f}$/, '')
      # Consider that similarly named files could exist in different vaults, so attach
      # a representation of the vault to the filename
      vault_hash = Digest::SHA1.hexdigest(vault)
      dir = "#{import_dir}/#{vault_hash}-#{f}"
      file = "#{dir}/#{options[:version]}"
      if f =~ /.*\.(.*)/
        file += ".#{Regexp.last_match[1]}"
      end
      if !File.exist?(file) || options[:force]
        FileUtils.mkdir_p(dir) unless File.exist?(dir)
        driver.import(f, vault, options[:version], dir)
        FileUtils.mv("#{dir}/#{f}", file)
      end
      file
    end
  end
end
