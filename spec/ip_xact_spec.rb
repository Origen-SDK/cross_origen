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
      $dut.add_atx3
      $dut.atx2.registermap.regs.size.should == 2
      $dut.atx2.registermap.mclkdiv.address.should == 0x6000_0000
      $dut.atx2.registermap.mclkdiv.osch.data.should == 1
      $dut.atx2.registermap.mclkdiv.description.should == ["MPU Clock Divider Register"]
      $dut.atx2.registermap.mclkdiv.osch.description.first.should == "Oscillator (Hi)"
      $dut.atx2.registermap.mclkdiv.osch.bit_value_descriptions[0].should == "Clock is the externally supplied bus clock bus_clk"
      # Extensive checks of access types, given how many are possible
      $dut.atx2.registermap.mclkdiv.osch.bit_value_descriptions[1].should == "Clock is the internal oscillator from the hardblock"
      $dut.atx2.registermap.access_types.readonly.access.should == :ro
      $dut.atx2.registermap.access_types.readwrite.access.should == :rw
      $dut.atx2.registermap.access_types.readclear.access.should == :rc
      $dut.atx2.registermap.access_types.readset.access.should == :rs
      $dut.atx2.registermap.access_types.writablereadclear.access.should == :wrc
      $dut.atx2.registermap.access_types.writeclear.access.should == :wc
      $dut.atx2.registermap.access_types.writeset.access.should == :ws
      $dut.atx2.registermap.access_types.writesetreadclear.access.should == :wsrc
      $dut.atx2.registermap.access_types.writeclearreadset.access.should == :wcrs
      $dut.atx2.registermap.access_types.write1toclear.access.should == :w1c
      $dut.atx2.registermap.access_types.write1toset.access.should == :w1s
      $dut.atx2.registermap.access_types.write0toclear.access.should == :w0c
      $dut.atx2.registermap.access_types.write0toset.access.should == :w0s
      $dut.atx2.registermap.access_types.write0totoggle.access.should == :w0t
      $dut.atx2.registermap.access_types.write1tosetreadclear.access.should == :w1src
      $dut.atx2.registermap.access_types.write1toclearreadset.access.should == :w1crs
      $dut.atx2.registermap.access_types.write0tosetreadclear.access.should == :w0src
      $dut.atx2.registermap.access_types.writeonly.access.should == :wo
      $dut.atx2.registermap.access_types.writeonlyclear.access.should == :woc
      $dut.atx2.registermap.access_types.writeonlyreadzero.access.should == :worz
      $dut.atx2.registermap.access_types.writeonlyset.access.should == :wos
      $dut.atx2.registermap.access_types.writeonce.access.should == :w1
      $dut.atx2.registermap.access_types.writeonlyonce.access.should == :wo1
      $dut.atx2.registermap.access_types.readwritenocheck.access.should == :dc
      $dut.atx2.registermap.access_types.readonlyclearafter.access.should == :rowz
      $dut.atx3.registermap.regs.size.should == 2
      $dut.atx3.registermap.mclkdiv.address.should == 0x7000_0000
      $dut.atx3.registermap.mclkdiv.osch.data.should == 1
      $dut.atx3.registermap.mclkdiv.description.should == ["MPU Clock Divider Register"]
      $dut.atx3.registermap.mclkdiv.osch.description.first.should == "Oscillator (Hi)"
      $dut.atx3.registermap.mclkdiv.osch.bit_value_descriptions[0].should == "Clock is the externally supplied bus clock bus_clk"
      $dut.atx3.registermap.mclkdiv.osch.bit_value_descriptions[1].should == "Clock is the internal oscillator from the hardblock"
      # Extensive checks of access types, given how many are possible
      $dut.atx3.registermap.mclkdiv.osch.bit_value_descriptions[1].should == "Clock is the internal oscillator from the hardblock"
      $dut.atx3.registermap.access_types.readonly.access.should == :ro
      $dut.atx3.registermap.access_types.readwrite.access.should == :rw
      $dut.atx3.registermap.access_types.readclear.access.should == :rc
      $dut.atx3.registermap.access_types.readset.access.should == :rs
      $dut.atx3.registermap.access_types.writablereadclear.access.should == :wrc
      $dut.atx3.registermap.access_types.writeclear.access.should == :wc
      $dut.atx3.registermap.access_types.writeset.access.should == :ws
      $dut.atx3.registermap.access_types.writesetreadclear.access.should == :wsrc
      $dut.atx3.registermap.access_types.writeclearreadset.access.should == :wcrs
      $dut.atx3.registermap.access_types.write1toclear.access.should == :w1c
      $dut.atx3.registermap.access_types.write1toset.access.should == :w1s
      $dut.atx3.registermap.access_types.write0toclear.access.should == :w0c
      $dut.atx3.registermap.access_types.write0toset.access.should == :w0s
      $dut.atx3.registermap.access_types.write0totoggle.access.should == :w0t
      $dut.atx3.registermap.access_types.write1tosetreadclear.access.should == :w1src
      $dut.atx3.registermap.access_types.write1toclearreadset.access.should == :w1crs
      $dut.atx3.registermap.access_types.write0tosetreadclear.access.should == :w0src
      $dut.atx3.registermap.access_types.writeonly.access.should == :wo
      $dut.atx3.registermap.access_types.writeonlyclear.access.should == :woc
      # This cannot be differentiated from :wo, so skip checking it on import
      # $dut.atx3.registermap.access_types.writeonlyreadzero.access.should == :worz
      $dut.atx3.registermap.access_types.writeonlyset.access.should == :wos
      $dut.atx3.registermap.access_types.writeonce.access.should == :w1
      $dut.atx3.registermap.access_types.writeonlyonce.access.should == :wo1
      # This cannot be differentiated from :rw, so skip checking it in import.
      # $dut.atx3.registermap.access_types.readwritenocheck.access.should == :dc
      # $dut.atx3.registermap.access_types.readonlyclearafter.access.should == :rowz
    end
  end
end
