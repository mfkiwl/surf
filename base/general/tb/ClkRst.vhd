-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Provides a clocks and reset signal to UUT in simulation.
--              Assumes active high reset.
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'SLAC Firmware Standard Library', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library surf;
use surf.StdRtlPkg.all;

entity ClkRst is
   generic (
      CLK_PERIOD_G      : time    := 10 ns;
      CLK_DELAY_G       : time    := 0 ns;
      RST_START_DELAY_G : time    := 1 ns;  -- Wait this long into simulation before asserting reset
      RST_HOLD_TIME_G   : time    := 6 us;  -- Hold reset for this long
      SYNC_RESET_G      : boolean := false);
   port (
      hold : in  sl := '0';
      halt : in  sl := '0';
      clkP : out sl := '0';
      clkN : out sl := '1';             -- Inverted clock
      rst  : out sl := '1';
      rstL : out sl := '0');

end entity ClkRst;

architecture ClkRst of ClkRst is

   constant CLK_HIGH_C : time := CLK_PERIOD_G/2.0;
   constant CLK_LOW_C  : time := CLK_PERIOD_G-CLK_HIGH_C;

   signal clkFb : sl := '0';
   signal rstFb : sl := '0';

begin

   assert (CLK_HIGH_C = CLK_LOW_C)
      -- report "ClkRst: CLK_HIGH_C (" & str(CLK_HIGH_C) & ") does not match CLK_LOW_C (" & str(CLK_LOW_C) & "). \n\
      report "ClkRst: CLK_HIGH_C does not match CLK_LOW_C. \n if you need 50 percent duty cycle for this clock, you will need to increase the simulator time resolution."
      severity warning;

   process is
   begin
      wait for CLK_DELAY_G;
      while (true) loop
         if (halt = '0') then
            if (hold = '1') then
               clkFb <= clkFb;
            else
               clkFb <= not clkFb;
            end if;
            if (clkFb = '0') then
               wait for CLK_LOW_C;
            else
               wait for CLK_HIGH_C;
            end if;
         else
            wait;
         end if;
      end loop;
   end process;

   process is
   begin
      rstFb <= '0';
      wait for RST_START_DELAY_G;
      if (SYNC_RESET_G) then
         wait until clkFb = '1';
      end if;
      rstFb <= '1';
      wait for RST_HOLD_TIME_G;
      if (SYNC_RESET_G) then
         wait until clkFb = '1';
      end if;
      rstFb <= '0';
      wait;
   end process;

   clkP <= clkFb;
   clkN <= not clkFb;
   rst  <= rstFb;
   rstL <= not rstFb;

end architecture ClkRst;
