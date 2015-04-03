--////////////////////////////////////////////////////////////////////////////////
--//   ____  ____ 
--//  /   /\/   / 
--// /___/  \  /    Vendor: Xilinx 
--// \   \   \/     Version : 2.2
--//  \   \         Application : 7 Series FPGAs Transceivers Wizard 
--//  /   /         Filename :Gth7TxRst.vhd
--// /___/   /\     
--// \   \  /  \ 
--//  \___\/\___\ 
--//
--//
--  Description :     This module performs TX reset and initialization.
--                     
--
--
-- Module Gth7TxRst
-- Generated by Xilinx 7 Series FPGAs Transceivers Wizard
-- 
-- 
-- (c) Copyright 2010-2012 Xilinx, Inc. All rights reserved.
-- 
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
-- 
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
-- 
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
-- 
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 


--*****************************************************************************

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity Gth7TxRst is
   generic(
      TPD_G                  : time                  := 1 ns;
      GT_TYPE                : string                := "GTX";
      STABLE_CLOCK_PERIOD    : integer range 4 to 20 := 8;  --Period of the stable clock driving this state-machine, unit is [ns]
      RETRY_COUNTER_BITWIDTH : integer range 2 to 8  := 8
      );     
   port (
      STABLE_CLOCK      : in  std_logic;  --Stable Clock, either a stable clock from the PCB
                                          --or reference-clock present at startup.
      TXUSERCLK         : in  std_logic;  --TXUSERCLK as used in the design
      SOFT_RESET        : in  std_logic;  --User Reset, can be pulled any time
      PLLREFCLKLOST     : in  std_logic;  --PLL Reference-clock for the GT is lost
      PLLLOCK           : in  std_logic;  --Lock Detect from the PLL of the GT
      TXRESETDONE       : in  std_logic;
      MMCM_LOCK         : in  std_logic;
      GTTXRESET         : out std_logic := '0';
      MMCM_RESET        : out std_logic := '1';
      PLL_RESET         : out std_logic := '0';             --Reset PLL
      TX_FSM_RESET_DONE : out std_logic;  --Reset-sequence has sucessfully been finished.
      TXUSERRDY         : out std_logic := '0';
      RUN_PHALIGNMENT   : out std_logic := '0';
      RESET_PHALIGNMENT : out std_logic := '0';
      PHALIGNMENT_DONE  : in  std_logic;

      RETRY_COUNTER : out std_logic_vector (RETRY_COUNTER_BITWIDTH-1 downto 0) := (others => '0')  -- Number of 
                                        -- Retries it took to get the transceiver up and running
      );
end Gth7TxRst;

--Interdependencies:
-- * Timing depends on the frequency of the stable clock. Hence counters-sizes
--   are calculated at design-time based on the Generics
--   
-- * if either of PLLs is reset during TX-startup, it does not need to be reset again by RX
--   => signal which PLL has been reset
-- * 



architecture RTL of Gth7TxRst is

   type tx_rst_fsm_type is(
      INIT, ASSERT_ALL_RESETS, RELEASE_PLL_RESET,
      RELEASE_MMCM_RESET, WAIT_RESET_DONE, DO_PHASE_ALIGNMENT,
      RESET_FSM_DONE);

   signal tx_state : tx_rst_fsm_type := INIT;

   constant MMCM_LOCK_CNT_MAX : integer := 1024;
   constant STARTUP_DELAY     : integer := 500;  --AR43482: Transceiver needs to wait for 500 ns after configuration
   constant WAIT_CYCLES       : integer := STARTUP_DELAY / STABLE_CLOCK_PERIOD;  -- Number of Clock-Cycles to wait after configuration
   constant WAIT_MAX          : integer := WAIT_CYCLES + 10;  -- 500 ns plus some additional margin

   constant WAIT_TIMEOUT_2ms   : integer := 2000000 / STABLE_CLOCK_PERIOD;  --  2 ms time-out
   constant WAIT_TLOCK_MAX     : integer := 100000 / STABLE_CLOCK_PERIOD;   --100 us time-out
   constant WAIT_TIMEOUT_500us : integer := 500000 / STABLE_CLOCK_PERIOD;   --100 us time-out

   signal soft_reset_sync : std_logic;
   signal soft_reset_rise : std_logic;
   signal soft_reset_fall : std_logic;

   signal init_wait_count    : integer range 0 to WAIT_MAX := 0;
   signal init_wait_done     : std_logic                   := '0';
   signal pll_reset_asserted : std_logic                   := '0';

   signal tx_fsm_reset_done_int    : std_logic := '0';
   signal tx_fsm_reset_done_int_s3 : std_logic := '0';

   signal txresetdone_s3 : std_logic := '0';

   constant MAX_RETRIES     : integer                             := 2**RETRY_COUNTER_BITWIDTH-1;
   signal retry_counter_int : integer range 0 to MAX_RETRIES;
   signal time_out_counter  : integer range 0 to WAIT_TIMEOUT_2ms := 0;

   signal reset_time_out : std_logic := '0';
   signal time_out_2ms   : std_logic := '0';  --\Flags that the various time-out points 
   signal time_tlock_max : std_logic := '0';  --|have been reached.
   signal time_out_500us : std_logic := '0';  --/

   signal mmcm_lock_count     : integer range 0 to MMCM_LOCK_CNT_MAX-1 := 0;
   signal mmcm_lock_int       : std_logic                              := '0';
   signal mmcm_lock_reclocked : std_logic_vector(3 downto 0)           := (others => '0');

   signal run_phase_alignment_int    : std_logic := '0';
   signal run_phase_alignment_int_s3 : std_logic := '0';

   constant MAX_WAIT_BYPASS       : integer   := 110000;  --110000 TXUSRCLK cycles is the max time for Multi lane designs
   signal wait_bypass_count       : integer range 0 to MAX_WAIT_BYPASS-1;
   signal time_out_wait_bypass    : std_logic := '0';
   signal time_out_wait_bypass_s3 : std_logic := '0';
   signal refclk_lost             : std_logic;

   signal plllock_sync : std_logic := '0';
   
   attribute KEEP_HIERARCHY : string;
   attribute KEEP_HIERARCHY of 
      Synchronizer_run_phase_alignment,
      Synchronizer_fsm_reset_done,
      Synchronizer_SOFT_RESET,
      Synchronizer_TXRESETDONE,
      Synchronizer_time_out_wait_bypass,
      Synchronizer_mmcm_lock_reclocked,
      Synchronizer_PLLLOCK : label is "TRUE";
   
begin

   --Alias section, signals used within this module mapped to output ports:
   RETRY_COUNTER     <= std_logic_vector(TO_UNSIGNED(retry_counter_int, RETRY_COUNTER_BITWIDTH));
   RUN_PHALIGNMENT   <= run_phase_alignment_int;
   TX_FSM_RESET_DONE <= tx_fsm_reset_done_int;

   process(STABLE_CLOCK)
   begin
      if rising_edge(STABLE_CLOCK) then
         -- The counter starts running when configuration has finished and 
         -- the clock is stable. When its maximum count-value has been reached,
         -- the 500 ns from Answer Record 43482 have been passed.
         if init_wait_count = WAIT_MAX then
            init_wait_done <= '1';
         else
            init_wait_count <= init_wait_count + 1;
         end if;
      end if;
   end process;


   timeouts : process(STABLE_CLOCK)
   begin
      if rising_edge(STABLE_CLOCK) then
         -- One common large counter for generating three time-out signals.
         -- Intermediate time-outs are derived from calculated values, based
         -- on the period of the provided clock.
         if reset_time_out = '1' then
            time_out_counter <= 0;
            time_out_2ms     <= '0';
            time_tlock_max   <= '0';
            time_out_500us   <= '0';
         else
            if time_out_counter = WAIT_TIMEOUT_2ms then
               time_out_2ms <= '1';
            else
               time_out_counter <= time_out_counter + 1;
            end if;

            if time_out_counter = WAIT_TLOCK_MAX then
               time_tlock_max <= '1';
            end if;

            if time_out_counter = WAIT_TIMEOUT_500us then
               time_out_500us <= '1';
            end if;
         end if;
      end if;
   end process;

   mmcm_lock_wait : process(TXUSERCLK, MMCM_LOCK)
   begin
      if MMCM_LOCK = '0' then
         mmcm_lock_count <= 0;
         mmcm_lock_int   <= '0';
      elsif rising_edge(TXUSERCLK) then
         if mmcm_lock_count < MMCM_LOCK_CNT_MAX - 1 then
            mmcm_lock_count <= mmcm_lock_count + 1;
         else
            mmcm_lock_int <= '1';
         end if;
      end if;
   end process;

   
   -- Clock Domain Crossing
   Synchronizer_run_phase_alignment : entity work.Synchronizer
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 3,
         INIT_G   => "000")
      port map (
         clk     => TXUSERCLK,
         dataIn  => run_phase_alignment_int,
         dataOut => run_phase_alignment_int_s3);

   Synchronizer_fsm_reset_done : entity work.Synchronizer
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 3,
         INIT_G   => "000")
      port map (
         clk     => TXUSERCLK,
         dataIn  => tx_fsm_reset_done_int,
         dataOut => tx_fsm_reset_done_int_s3);

   Synchronizer_SOFT_RESET : entity work.SynchronizerEdge
      generic map (
         TPD_G    => TPD_G)
      port map (
         clk     => STABLE_CLOCK,
         dataIn  => SOFT_RESET,
         dataOut => soft_reset_sync,
         risingEdge => soft_reset_rise,
         fallingEdge => soft_reset_fall);

   Synchronizer_TXRESETDONE : entity work.Synchronizer
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 3,
         INIT_G   => "000")
      port map (
         clk     => STABLE_CLOCK,
         dataIn  => TXRESETDONE,
         dataOut => txresetdone_s3);

   Synchronizer_time_out_wait_bypass : entity work.Synchronizer
      generic map (
         TPD_G    => TPD_G,
         STAGES_G => 3,
         INIT_G   => "000")
      port map (
         clk     => STABLE_CLOCK,
         dataIn  => time_out_wait_bypass,
         dataOut => time_out_wait_bypass_s3);

   Synchronizer_mmcm_lock_reclocked : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => STABLE_CLOCK,
         dataIn  => mmcm_lock_int,
         dataOut => mmcm_lock_reclocked(0));

   Synchronizer_PLLLOCK : entity work.Synchronizer
      generic map (
         TPD_G => TPD_G)
      port map (
         clk     => STABLE_CLOCK,
         dataIn  => PLLLOCK,
         dataOut => plllock_sync);


   timeout_buffer_bypass : process(TXUSERCLK)
   begin
      if rising_edge(TXUSERCLK) then
         if run_phase_alignment_int_s3 = '0' then
            wait_bypass_count    <= 0;
            time_out_wait_bypass <= '0';
         elsif (run_phase_alignment_int_s3 = '1') and (tx_fsm_reset_done_int_s3 = '0') then
            if wait_bypass_count = MAX_WAIT_BYPASS - 1 then
               time_out_wait_bypass <= '1';
            else
               wait_bypass_count <= wait_bypass_count + 1;
            end if;
         end if;
      end if;
   end process;

   refclk_lost <= PLLREFCLKLOST;


   --FSM for resetting the GTX/GTH/GTP in the 7-series. 
   --~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   --
   -- Following steps are performed:
   -- 1) Only for GTX - After configuration wait for approximately 500 ns as specified in 
   --    answer-record 43482
   -- 2) Assert all resets on the GT and on an MMCM potentially connected. 
   --    After that wait until a reference-clock has been detected.
   -- 3) Release the reset to the GT and wait until the GT-PLL has locked.
   -- 4) Release the MMCM-reset and wait until the MMCM has signalled lock.
   --    Also signal to the RX-side which PLL has been reset.
   -- 5) Wait for the RESET_DONE-signal from the GT.
   -- 6) Signal to start the phase-alignment procedure and wait for it to 
   --    finish.
   -- 7) Reset-sequence has successfully run through. Signal this to the 
   --    rest of the design by asserting TX_FSM_RESET_DONE.

   reset_fsm : process(STABLE_CLOCK)
   begin
      if rising_edge(STABLE_CLOCK) then
         if(soft_reset_sync = '1' or
            (not(tx_state = INIT) and not(tx_state = ASSERT_ALL_RESETS) and refclk_lost = '1')) then
            tx_state                <= INIT;
            TXUSERRDY               <= '0';
            GTTXRESET               <= '0';
            MMCM_RESET              <= '1';
            tx_fsm_reset_done_int   <= '0';
            PLL_RESET               <= '0';
            pll_reset_asserted      <= '0';  -- Only assert after powerup?
            reset_time_out          <= '0';
            retry_counter_int       <= 0;
            run_phase_alignment_int <= '0';
            RESET_PHALIGNMENT       <= '1';
         else
            
            case tx_state is
               when INIT =>
                  --Initial state after configuration. This state will be left after
                  --approx. 500 ns and not be re-entered. 
                  if init_wait_done = '1' then
                     tx_state       <= ASSERT_ALL_RESETS;
                     reset_time_out <= '1';
                  end if;
                  
               when ASSERT_ALL_RESETS =>
                  --This is the state into which the FSM will always jump back if any
                  --time-outs will occur. 
                  --The number of retries is reported on the output RETRY_COUNTER. In 
                  --case the transceiver never comes up for some reason, this machine 
                  --will still continue its best and rerun until the FPGA is turned off
                  --or the transceivers come up correctly.

                  if pll_reset_asserted = '0' then
                     PLL_RESET          <= '1';
                     pll_reset_asserted <= '1';
                  else
                     PLL_RESET <= '0';
                  end if;

                  TXUSERRDY               <= '0';
                  GTTXRESET               <= '1';
                  MMCM_RESET              <= '1';
                  reset_time_out          <= '0';
                  run_phase_alignment_int <= '0';
                  RESET_PHALIGNMENT       <= '1';

                  if (PLLREFCLKLOST = '0' and pll_reset_asserted = '1') then
                     tx_state <= RELEASE_PLL_RESET;
                  end if;
                  
               when RELEASE_PLL_RESET =>
                  --PLL-Reset of the GTX gets released and the time-out counter
                  --starts running.
                  pll_reset_asserted <= '1';

                  if (plllock_sync = '1') then
                     tx_state       <= RELEASE_MMCM_RESET;
                     reset_time_out <= '1';
                  end if;

                  if time_out_2ms = '1' then
                     if retry_counter_int = MAX_RETRIES then
                        -- If too many retries are performed compared to what is specified in 
                        -- the generic, the counter simply wraps around.
                        retry_counter_int <= 0;
                     else
                        retry_counter_int <= retry_counter_int + 1;
                     end if;
                     tx_state <= ASSERT_ALL_RESETS;
                  end if;

               when RELEASE_MMCM_RESET =>
                  GTTXRESET      <= '0';
                  reset_time_out <= '0';
                  --Release of the MMCM-reset. Waiting for the MMCM to lock.
                  MMCM_RESET     <= '0';
                  if mmcm_lock_reclocked(0) = '1' then
                     tx_state       <= WAIT_RESET_DONE;
                     reset_time_out <= '1';
                  end if;

                  if time_tlock_max = '1' and mmcm_lock_reclocked(0) = '0' then
                     if retry_counter_int = MAX_RETRIES then
                        -- If too many retries are performed compared to what is specified in 
                        -- the generic, the counter simply wraps around.
                        retry_counter_int <= 0;
                     else
                        retry_counter_int <= retry_counter_int + 1;
                     end if;
                     tx_state <= ASSERT_ALL_RESETS;
                  end if;
                  
               when WAIT_RESET_DONE =>
                  TXUSERRDY      <= '1';
                  reset_time_out <= '0';
                  if txresetdone_s3 = '1' then
                     tx_state       <= DO_PHASE_ALIGNMENT;
                     reset_time_out <= '1';
                  end if;

                  if time_out_500us = '1' then
                     if retry_counter_int = MAX_RETRIES then
                        -- If too many retries are performed compared to what is specified in 
                        -- the generic, the counter simply wraps around.
                        retry_counter_int <= 0;
                     else
                        retry_counter_int <= retry_counter_int + 1;
                     end if;
                     tx_state <= ASSERT_ALL_RESETS;
                  end if;
                  
               when DO_PHASE_ALIGNMENT =>
                  --The direct handling of the signals for the Phase Alignment is done outside
                  --this state-machine. 
                  RESET_PHALIGNMENT       <= '0';
                  run_phase_alignment_int <= '1';
                  reset_time_out          <= '0';

                  if PHALIGNMENT_DONE = '1' then
                     tx_state <= RESET_FSM_DONE;
                  end if;

                  if time_out_wait_bypass_s3 = '1' then
                     if retry_counter_int = MAX_RETRIES then
                        -- If too many retries are performed compared to what is specified in 
                        -- the generic, the counter simply wraps around.
                        retry_counter_int <= 0;
                     else
                        retry_counter_int <= retry_counter_int + 1;
                     end if;
                     tx_state <= ASSERT_ALL_RESETS;
                  end if;
                  
               when RESET_FSM_DONE =>
                  reset_time_out        <= '1';
                  tx_fsm_reset_done_int <= '1';
                  
               when others =>
                  tx_state <= INIT;
                  
            end case;
         end if;
      end if;
   end process;

end RTL;
