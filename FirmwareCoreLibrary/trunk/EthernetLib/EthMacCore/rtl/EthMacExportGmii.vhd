-------------------------------------------------------------------------------
-- Title         : 1G MAC / Export Interface
-- Project       : RCE 1G-bit MAC
-------------------------------------------------------------------------------
-- File       : EthMacExportGmii.vhd
-- Author     : Jeff Olsen  <jjo@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-02-04
-- Last update: 2016-02-04
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-- PIC Export block for 1G MAC core for the RCE.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Ethernet Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Ethernet Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
-- Modification history:
-- 02/04/2016: created.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.AxiStreamPkg.all;
use work.StdRtlPkg.all;
use work.EthMacPkg.all;

entity EthMacExportGmii is
   generic (
      TPD_G : time := 1 ns);
   port (
      -- Clock and reset
      ethClk         : in  sl;
      ethClkRst      : in  sl;
      -- AXIS Interface   
      macObMaster    : in  AxiStreamMasterType;
      macObSlave     : out AxiStreamSlaveType;
      -- PHY Interface
      gmiiTxEn       : out sl;
      gmiiTxEr       : out sl;
      gmiiTxd        : out slv(7 downto 0);
      phyReady       : in  sl;
      -- Configuration
      interFrameGap  : in  slv(3 downto 0);
      macAddress     : in  slv(47 downto 0);
      -- Status
      txCountEn      : out sl;
      txUnderRun     : out sl;
      txLinkNotReady : out sl);
end EthMacExportGmii;

architecture rtl of EthMacExportGmii is

   type RegType is record
      gmiiTxEn       : sl;
      gmiiTxEr       : sl;
      gmiiTxd        : slv(7 downto 0);
      txCountEn      : sl;
      txUnderRun     : sl;
      txLinkNotReady : sl;
      macObSlave     : AxiStreamSlaveType;
   end record;

   constant REG_INIT_C : RegType := (
      gmiiTxEn       => '0',
      gmiiTxEr       => '0',
      gmiiTxd        => (others => '0'),
      txCountEn      => '0',
      txUnderRun     => '0',
      txLinkNotReady => '0',
      macObSlave     => AXI_STREAM_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   -- attribute dont_touch               : string;
   -- attribute dont_touch of r          : signal is "TRUE";   

begin

   comb : process (ethClkRst, r) is
      variable v : RegType;
   begin
      -- Latch the current value
      v := r;

      -- Reset the flags
      v.macObSlave := AXI_STREAM_SLAVE_INIT_C;

      ----------------------------------
      ----------------------------------
      ----------------------------------
      --- Place holder for code here ---
      ----------------------------------
      ----------------------------------
      ----------------------------------

      -- Reset
      if (ethClkRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;

      -- Outputs        
      macObSlave     <= v.macObSlave;   -- Flow control with non-registered signal
      txCountEn      <= r.txCountEn;
      txUnderRun     <= r.txUnderRun;
      txLinkNotReady <= r.txLinkNotReady;
      gmiiTxEn       <= r.gmiiTxEn;
      gmiiTxEr       <= r.gmiiTxEr;
      gmiiTxd        <= r.gmiiTxd;
      
   end process comb;

   seq : process (ethClk) is
   begin
      if rising_edge(ethClk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end rtl;