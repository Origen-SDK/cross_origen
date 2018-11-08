module CrossOrigenDev
  # Simple DUT class used for testing
  class DUT
    include Origen::TopLevel
    include CrossOrigen

    def initialize
      @path = :hidden
      sub_block :atx, class_name: 'D_IP_ANA_TEST_ANNEX_SYN', base_address: 0x4000_0000

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
      cr_import(path: "#{Origen.root}/imports/ipxact.xml")
    end

    # Import Spirit 1.4 version of ATX
    def add_atx2
      sub_block :atx2, class_name: 'ATX2', base_address: 0x6000_0000
    end

    class ATX2
      include Origen::Model
      include CrossOrigen

      def initialize
        cr_import(path: "#{Origen.root}/approved/ip_xact_sub_block.xml", refresh: true)
      end
    end

    # Import 1685-2009 version of ATX
    def add_atx3
      sub_block :atx3, class_name: 'ATX3', base_address: 0x7000_0000
    end

    class ATX3
      include Origen::Model
      include CrossOrigen

      def initialize
        cr_import(path: "#{Origen.root}/approved/ip_xact_sub_block_1685.xml", refresh: true)
      end
    end

    class D_IP_ANA_TEST_ANNEX_SYN # rubocop:disable ClassAndModuleCamelCase
      include Origen::Model
      include CrossOrigen

      def initialize
        # A manually defined set of registers for testing the conversion of any specific attributes

        # ** MPU Clock Divider Register **
        #
        # The MCLKDIV register is used to divide down the frequency of the OSCCLK input. If the MCLKDIV
        # register is set to value "N", then the output (beat) frequency of the clock divider is OSCCLK / (N+1). The
        # resulting beats are, in turn, counted by the TIMER module to control the duration of operations.
        # This is a test of potentially problematic characters ' " \' \" < >
        reg :mclkdiv, 0x0, size: 16, bit_order: 'decrement' do
          # **Oscillator (Hi)** - Clock source selection. (Note that in addition to this firmware-controlled bit, the
          # clock source is also dependent on test and power control discretes).
          #
          # 0 | Clock is the externally supplied bus clock bus_clk
          # 1 | Clock is the internal oscillator from the hardblock
          bit 15, :osch, reset: 1, access: :rw
        end

        # **Access Type Test Register**
        #
        # This register tests the IP-XACT export of various bit access types, such as write-one-to-clear,
        # read-only, etc.
        reg :access_types, 0x4, size: 32 do
          # Test read-only access.
          bit 31, :readonly, access: :ro
          # Test read-write access.
          bit 30, :readwrite, access: :rw
          # Test read-clear access, where a read clears the value afterwards.
          bit 29, :readclear, access: :rc
          # Test read-set access, where a read sets the bit afterwards.
          bit 28, :readset, access: :rs
          # Test writable, clear-on-read access, etc...
          bit 27, :writablereadclear, access: :wrc
          bit 26, :writablereadset, access: :wrs
          bit 25, :writeclear, access: :wc
          bit 24, :writeset, access: :ws
          bit 23, :writesetreadclear, access: :wsrc
          bit 22, :writeclearreadset, access: :wcrs
          bit 21, :write1toclear, access: :w1c
          bit 20, :write1toset, access: :w1s
          bit 19, :write1totoggle, access: :w1t
          bit 18, :write0toclear, access: :w0c
          bit 17, :write0toset, access: :w0s
          bit 16, :write0totoggle, access: :w0t
          bit 15, :write1tosetreadclear, access: :w1src
          bit 14, :write1toclearreadset, access: :w1crs
          bit 13, :write0tosetreadclear, access: :w0src
          bit 12, :write0toclearreadset, access: :w0crs
          bit 11, :writeonly, access: :wo
          bit 10, :writeonlyclear, access: :woc
          bit 9, :writeonlyreadzero, access: :worz
          bit 8, :writeonlyset, access: :wos
          bit 7, :writeonce, access: :w1
          bit 6, :writeonlyonce, access: :wo1
          bit 5, :readwritenocheck, access: :dc
          bit 4, :readonlyclearafter, access: :rowz
        end
      end
    end
  end
end
