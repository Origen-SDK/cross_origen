//---------------------------------------------------------------------------------------------
// dut Registers Memory Map
//---------------------------------------------------------------------------------------------
#define DUT_TOP_LEVEL_REG                                  (REG32(0x0))
#define DUT_TOP_LEVEL_REG_NUMBER_TWO                       (REG32(0x10))

//---------------------------------------------------------------------------------------------
// dut Registers Bit Definition
//---------------------------------------------------------------------------------------------
// DUT_TOP_LEVEL_REG
#define DUT_TOP_LEVEL_REG_SECOND_BIT           (BIT14)
#define DUT_TOP_LEVEL_REG_PLS_WORK             (BIT15)

// DUT_TOP_LEVEL_REG_NUMBER_TWO
#define DUT_TOP_LEVEL_REG_NUMBER_TWO_SECOND_BIT         (BIT1)
#define DUT_TOP_LEVEL_REG_NUMBER_TWO_PLS_WORK         (BIT0)
