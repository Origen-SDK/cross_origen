# This file was automatically generated from a CMSIS-SVD input file
# Name:    ARM_Example
# Version: 1.2
# Created at  8 May 2017 14:26PM by Stephen McGinty
# rubocop:disable all
module ImportedCMSISSVD
  def initialize(*args)
    instantiate_imported_cmsis_svd_data
  end

  def instantiate_imported_cmsis_svd_data
    sub_block :timer, base_address: 0x40010000
    sub_block :0, base_address: 0x40010100
    sub_block :1, base_address: 0x40010200

    timer.add_reg :cr, 0x0, size: 32, reset: 0x0, description: 'Control Register' do |reg|
      reg.bit , :en, access: :rw, description: 'Control Register'
      reg.bit , :rst, access: :rw, description: 'Control Register'
      reg.bit , :cnt, access: :rw, description: 'Control Register'
      reg.bit , :mode, access: :rw, description: 'Control Register'
      reg.bit , :psc, access: :rw, description: 'Control Register'
      reg.bit , :cntsrc, access: :rw, description: 'Control Register'
      reg.bit , :capsrc, access: :rw, description: 'Control Register'
      reg.bit , :capedge, access: :rw, description: 'Control Register'
      reg.bit , :trgext, access: :rw, description: 'Control Register'
      reg.bit , :reload, access: :rw, description: 'Control Register'
      reg.bit , :idr, access: :rw, description: 'Control Register'
      reg.bit , :s, access: :rw, description: 'Control Register'
    end
    timer.add_reg :sr, 0x4, size: 16, reset: 0x0, description: 'Status Register' do |reg|
      reg.bit , :run, access: :ro, description: 'Status Register'
      reg.bit , :match, access: :rw, description: 'Status Register'
      reg.bit , :un, access: :rw, description: 'Status Register'
      reg.bit , :ov, access: :rw, description: 'Status Register'
      reg.bit , :rst, access: :ro, description: 'Status Register'
      reg.bit , :reload, access: :ro, description: 'Status Register'
    end
    timer.add_reg :int, 0x10, size: 16, reset: 0x0, description: 'Interrupt Register' do |reg|
      reg.bit , :en, access: :rw, description: 'Interrupt Register'
      reg.bit , :mode, access: :rw, description: 'Interrupt Register'
    end
    timer.add_reg :count, 0x20, size: 32, reset: 0x0, description: 'The Counter Register reflects the actual Value of the Timer/Counter' do |reg|
    end
    timer.add_reg :match, 0x24, size: 32, reset: 0x0, description: 'The Match Register stores the compare Value for the MATCH condition' do |reg|
    end
    timer.add_reg :prescale_rd, 0x28, size: 32, reset: 0x0, description: 'The Prescale Register stores the Value for the prescaler. The cont event gets divided by this value' do |reg|
    end
    timer.add_reg :prescale_wr, 0x28, size: 32, reset: 0x0, description: 'The Prescale Register stores the Value for the prescaler. The cont event gets divided by this value' do |reg|
    end
    timer.add_reg :reload0, 0x50, size: 32, reset: 0x0, description: 'The Reload Register stores the Value the COUNT Register gets reloaded on a when a condition was met.' do |reg|
    end
    timer.add_reg :reload1, 0x54, size: 32, reset: 0x0, description: 'The Reload Register stores the Value the COUNT Register gets reloaded on a when a condition was met.' do |reg|
    end
    timer.add_reg :reload2, 0x58, size: 32, reset: 0x0, description: 'The Reload Register stores the Value the COUNT Register gets reloaded on a when a condition was met.' do |reg|
    end
    timer.add_reg :reload3, 0x5C, size: 32, reset: 0x0, description: 'The Reload Register stores the Value the COUNT Register gets reloaded on a when a condition was met.' do |reg|
    end
  end

  def 
    [0, 1]
  end
end
# rubocop:enable all
