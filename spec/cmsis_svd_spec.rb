require 'spec_helper'

describe 'CMSIS-SVD' do
  describe 'Import from XML' do

    class CMSISDut
      include Origen::Model
      include CrossOrigen

      def initialize(options = {})
        cr_import(path: "#{Origen.root}/imports/cmsis.svd", refresh: true, include_timestamp: false)
      end
    end

    it "is alive" do
      d = CMSISDut.new
      d.timer.children.size.should == 3
    end

    it "has 4 reload registers (dimensioned register import)" do
      d = CMSISDut.new
      3.times do |i|
        4.times do |j|
          d.timer.send("timer#{i}").send("reload#{j}").should be
        end
      end
    end
  end
end
