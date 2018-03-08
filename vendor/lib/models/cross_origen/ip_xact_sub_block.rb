# This file was generated by Origen, any hand edits will likely get overwritten
# Created at 14 Feb 2018 09:24AM by Stephen McGinty
# rubocop:disable all
module CrossOrigen
  module IPXactSubBlock
    def self.extended(model)
      # MGATE Clock Divider Register
      model.add_reg :mclkdiv, 0x0, size: 16 do |reg|
        # Oscillator (Hi)
        # 
        # 0 | FMU clock is the externally supplied bus clock ipg_clk
        # 1 | FMU clock is the internal oscillator from the TFS hardblock
        reg.bit 15, :osch, reset: 0x1
      end
    end
  end
end
# rubocop:enable all
