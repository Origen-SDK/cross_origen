module RosettaStone
  module Test
    # Simple DUT class used for testing
    class DUT
      include Origen::TopLevel
      include RosettaStone

      def initialize
        @path = :hidden
        # Register defined solely to test out the top level register export
        reg :dut_top_level_reg, 0x0, size: 32, bit_order: :msb0, lau: 8 do
          bit 15, :pls_work, reset: 1, access: :rw
          bit 14, :second_bit, reset: 0, access: :rw
        end
        # Register defined solely to test out the top level register export
        reg :dut_top_level_reg_number_two, 0x10, size: 32, bit_order: :lsb0, lau: 16 do
          bit 0, :pls_work, reset: 0, access: :ro
          bit 1, :second_bit, reset: 1, access: :rw
        end
        # Import some data from IP-XACT
        rs_import(path: "#{Origen.root}/imports/ipxact.xml")
      end

      class D_IP_ANA_TEST_ANNEX_SYN # rubocop:disable ClassAndModuleCamelCase
        include Origen::Model
        include RosettaStone

        def initialize
          # http://ssds.freescale.net:8080/docato-composer/getXMLResourceView.do?id=336182&xml=true&versionId=37
          rs_import(path: "#{Origen.root}/imports/test-annex-Block-registers.xml")
          # A manually defined register for testing the conversion of any specific attributes

          # ** MGATE Clock Divider Register **
          # The MCLKDIV register is used to divide down the frequency of the HBOSCCLK input. If the MCLKDIV
          # register is set to value "N", then the output (beat) frequency of the clock divider is OSCCLK / (N+1). The
          # resulting beats are, in turn, counted by the PTIMER module to control the duration of Flash high-voltage
          # operations.
          # This is a test of potentially problematic characters ' " \' \" < >
          reg :mclkdiv, 0x0, size: 16, bit_order: 'decrement' do
            # **Oscillator (Hi)** - Firmware FMU clk source selection. (Note that in addition to this firmware-controlled bit, the
            # FMU clock source is also dependent on test and power control discretes).
            #
            # 0 | FMU clock is the externally supplied bus clock ipg_clk
            # 1 | FMU clock is the internal oscillator from the TFS hardblock
            bit 15, :osch, reset: 1, access: :rw
          end
        end
      end
    end
  end
end
