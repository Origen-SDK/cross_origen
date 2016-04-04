require 'spec_helper'

describe 'IP-XACT' do

  before :all do
    Origen.load_target('debug')
  end

  describe 'Import from XML' do

    it 'imports all memory map sub_blocks' do
      $dut.am0.sub_blocks.size.should == 2 # These are memory maps
    end

    it 'pulls sub_block info' do
      $dut.am0.rf1.path.should == 'am0.rf1'
      $dut.am0.rf1.base_address.should == 0x1000
      $dut.am0.rf1.lau.should == 8
      $dut.am0.rf1.range.should == 256
      $dut.am0.rf1.byte_order.nil?.should == true # Not available in XML source
    end

    it 'imports all registers' do
      $dut.am0.rf1.regs.size.should == 7
      $dut.am0.rf2.regs.size.should == 1
    end

    it 'pulls the register address' do
      $dut.am0.rf1.reg4.address.should == 0x1004
    end

    it 'pulls the register size' do
      $dut.am0.rf1.reg4.size.should == 8
    end

    it 'pulls the correct bit size and positions' do
      $dut.am0.rf1.reg6.rsv.position.should == 2
      $dut.am0.rf1.reg6.rsv.size.should == 6
    end

    it 'assigns the correct bit reset values' do
      $dut.am0.rf1.reg4.rsv.data.should == 3
      $dut.am0.rf1.reg4.f1.data.should == 1
      $dut.am0.rf1.reg4.f0.data.should == 0
    end

    it 'assigns read only bits correctly' do
      $dut.am0.rf1.reg4.more_dirs.writable?.should == false
      $dut.am0.rf1.reg4.more_dirs.access.should == :ro
    end

    it 'extracts bit field access value correctly' do
      $dut.am0.rf1.reg4.rsv.access.should == :rw
    end

    it 'extracts register path correctly' do
      $dut.am0.rf1.reg4.dirs.path.should == 'am0.rf1.reg4[3:2]'
    end

    it 'extracts an IP-level file correctly' do
      $dut.add_atx2
      $dut.atx2.regs.size.should == 1
      $dut.atx2.mclkdiv.address.should == 0x6000_0000
      $dut.atx2.mclkdiv.osch.data.should == 1
      $dut.atx2.mclkdiv.description.should == ["MGATE Clock Divider Register"]
      $dut.atx2.mclkdiv.osch.description.first.should == "Oscillator (Hi)"
      $dut.atx2.mclkdiv.osch.bit_value_descriptions[0].should == "FMU clock is the externally supplied bus clock ipg_clk"
      $dut.atx2.mclkdiv.osch.bit_value_descriptions[1].should == "FMU clock is the internal oscillator from the TFS hardblock"
    end
  end
end
