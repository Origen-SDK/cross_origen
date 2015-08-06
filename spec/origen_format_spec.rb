require 'spec_helper'

describe "Export to Ruby .rb files" do

  before :all do
    Origen.load_target('debug')
    $dut.to_origen(path: "#{Origen.root}/output/exported", class_name: "ExportedDUT")
    load "#{Origen.root}/output/exported/top_level.rb"
    $dut = RosettaStone::Test::ExportedDUT.new
  end

  describe 'Query the static ruby files created' do
    it "Queries the top level registers based on the loaded Ruby files" do
      $dut.class.should == RosettaStone::Test::ExportedDUT
      $dut.regs.size.should == 2
      $dut.dut_top_level_reg.size.should == 32
      $dut.dut_top_level_reg.bits(:pls_work).access.should == :rw
      $dut.dut_top_level_reg.bits(:pls_work).reset_val.should == 1
    end

    it "Queries the AM0 sub_block based on the loaded Ruby files" do
      $dut.class.should == RosettaStone::Test::ExportedDUT
      $dut.sub_blocks.size.should == 1
      $dut.am0.regs.empty?.should == true
      $dut.am0.sub_blocks.size.should == 2
    end

    it "Queries some of the attributes from the lowest level sub-blocks" do
      $dut.class.should == RosettaStone::Test::ExportedDUT
      # These have all just been copied from the IP-XACT spec, to verify that
      # what we have exported out and back in again is the same
      $dut.am0.sub_blocks.size.should == 2 # These are memory maps
      $dut.am0.rf1.path.should == 'am0.rf1'
      $dut.am0.rf1.base_address.should == 0x1000
      $dut.am0.rf1.lau.should == 8
      # Not currently exported, probably should be
      #$dut.am0.rf1.range.should == 256
      #$dut.am0.rf1.byte_order.nil?.should == true # Not available in XML source
      $dut.am0.rf1.regs.size.should == 7
      $dut.am0.rf2.regs.size.should == 1
      $dut.am0.rf1.reg4.address.should == 0x1004
      $dut.am0.rf1.reg4.size.should == 8
      $dut.am0.rf1.reg6.rsv.position.should == 2
      $dut.am0.rf1.reg6.rsv.size.should == 6
      $dut.am0.rf1.reg4.rsv.data.should == 3
      $dut.am0.rf1.reg4.f1.data.should == 1
      $dut.am0.rf1.reg4.f0.data.should == 0
      $dut.am0.rf1.reg4.more_dirs.writable?.should == false
      $dut.am0.rf1.reg4.more_dirs.access.should == :ro
      $dut.am0.rf1.reg4.rsv.access.should == :rw
      $dut.am0.rf1.reg4.dirs.path.should == 'am0.rf1.reg4[3:2]'
    end
  end
end
