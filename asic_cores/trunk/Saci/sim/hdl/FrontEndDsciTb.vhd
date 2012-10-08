-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : FrontEndDsciTb.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-10-02
-- Last update: 2012-10-05
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Simple Dsci testbench with Dsci Master connected to the
-- standard Front End Register interface.
-------------------------------------------------------------------------------
-- Copyright (c) 2012 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.StdRtlPkg.all;
use work.FrontEndPkg.all;
use work.SaciMasterPkg.all;

entity FrontEndDsciTb is

end entity FrontEndDsciTb;

architecture testbench of FrontEndDsciTb is

  constant TPD_C : time := 1 ns;

  -- Clocks and resets
  signal gtpClk    : sl;
  signal fpgaRst   : sl;
  signal pgpClk : sl;
  signal pgpRst : sl;
  signal saciClkIn : sl;
  signal saciRst   : sl;

  -- Front End Register Interface
  signal frontEndRegCntlIn : FrontEndRegCntlInType;
  signal frontEndRegCntlOut : FrontEndRegCntlOutType;

  -- SACI Master Parallel Interface
  signal saciMasterIn  : SaciMasterInType;
  signal saciMasterOut : SaciMasterOutType;

  -- SACI serial interface
  signal saciClk  : sl;
  signal saciSelL : slv(SACI_NUM_SLAVES_C-1 downto 0);
  signal saciCmd  : sl;
  signal saciRsp  : sl;

  -- SACI Slave Parallel Interface
  signal asicRstL      : sl;
  signal saciSlaveRstL : sl;
  signal exec          : sl;
  signal ack           : sl;
  signal readL         : sl;
  signal cmd           : slv(6 downto 0);
  signal addr          : slv(11 downto 0);
  signal wrData        : slv(31 downto 0);
  signal rdData        : slv(31 downto 0);

  
begin

  -- Create 156.25 MHz system clock and main reset
  ClkRst_1 : entity work.ClkRst
    generic map (
      CLK_PERIOD_G   => 6.4 ns,
      RST_START_DELAY_G => 1 ns,
      RST_HOLD_TIME_G   => 6 us)
    port map (
      clkP => gtpClk,
      clkN => open,
      rst  => fpgaRst,
      rstL => open);

  -- Create 1 MHz SACI Serial Clock
  ClkRst_2 : entity work.ClkRst
    generic map (
      CLK_PERIOD_G => 1 us)
    port map (
      clkP => saciClkIn,
      clkN => open,
      rst  => open,
      rstL => open);

  -- Synchronize main reset to sysClk125
  RstSync_1 : entity work.RstSync
    generic map (
      DELAY_G => TPD_C)
    port map (
      clk      => pgpClk,
      asyncRst => fpgaRst,
      syncRst  => pgpRst);

  -- Synchronize main reset to SACI serial clock
  RstSync_2 : entity work.RstSync
    generic map (
      DELAY_G => TPD_C)
    port map (
      clk      => saciClkIn,
      asyncRst => fpgaRst,
      syncRst  => saciRst);

  --------------------------------------------------------------------------------------------------

  -- Front End register interface
  Pgp2FrontEnd_1: entity work.Pgp2FrontEnd
    port map (
      pgpRefClk    => gtpClk,
      pgpRefClkOut => pgpClk,
      pgpClk       => pgpClk,
      pgpClk2x     => '0',              -- Not used in sim variant
      pgpReset     => pgpRst,
      locClk       => pgpClk,
      locReset     => pgpRst,
      regReq       => frontEndRegCntlOut.regReq,
      regOp        => frontEndRegCntlOut.regOp,
      regInp       => frontEndRegCntlOut.regInp,
      regAck       => frontEndRegCntlIn.regAck,
      regFail      => frontEndRegCntlIn.regFail,
      regAddr      => frontEndRegCntlOut.regAddr,
      regDataOut   => frontEndRegCntlOut.regDataOut,
      regDataIn    => frontEndRegCntlIn.regDataIn,
      pgpRxN       => '0',
      pgpRxP       => '0',
      pgpTxN       => open,
      pgpTxP       => open);

  -- Register Decoder
  FrontEndRegDecoder_1: entity work.FrontEndRegDecoder
    generic map (
      DELAY_G => TPD_C)
    port map (
      sysClk             => pgpClk,
      sysRst             => pgpRst,
      frontEndRegCntlOut => frontEndRegCntlOut,
      frontEndRegCntlIn  => frontEndRegCntlIn,
      saciMasterIn       => saciMasterIn,
      saciMasterOut      => saciMasterOut);
  
  SaciMaster_1 : entity work.SaciMaster
    generic map (
      TPD_G                 => TPD_C,
      SYNCHRONIZE_CONTROL_G => true)
    port map (
      clk           => saciClkIn,
      rst           => saciRst,
      saciClk       => saciClk,
      saciSelL      => saciSelL,
      saciCmd       => saciCmd,
      saciRsp       => saciRsp,
      saciMasterIn  => saciMasterIn,
      saciMasterOut => saciMasterOut);

  -- End of FPGA Side
  --------------------------------------------------------------------------------------------------

  -- ASIC Side
  -- Create Asic Reset
  ClkRst_3 : entity work.ClkRst
    generic map (
      RST_START_DELAY_G => 1 ns,
      RST_HOLD_TIME_G   => 6 us)
    port map (
      clkP => open,
      clkN => open,
      rst  => open,
      rstL => asicRstL);

  SaciSlave_1 : entity work.SaciSlave
    generic map (
      TPD_G => TPD_C)
    port map (
      rstL     => asicRstL,
      saciClk  => saciClk,
      saciSelL => saciSelL(0),
      saciCmd  => saciCmd,
      saciRsp  => saciRsp,
      rstOutL  => saciSlaveRstL,
      rstInL   => saciSlaveRstL,
      exec     => exec,
      ack      => ack,
      readL    => readL,
      cmd      => cmd,
      addr     => addr,
      wrData   => wrData,
      rdData   => rdData);

  DsciSlaveRam_1 : entity work.DsciSlaveRam
    port map (
      dsciClkOut => saciClk,
      exec       => exec,
      ack        => ack,
      readL      => readL,
      cmd        => cmd,
      addr       => addr,
      wrData     => wrData,
      rdData     => rdData);

end architecture testbench;
