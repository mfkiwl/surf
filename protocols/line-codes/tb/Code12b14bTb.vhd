-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Testbench for design "Encoder12b14b"
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
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.Code12b14bPkg.all;
use surf.TextUtilPkg.all;

entity Code12b14bTb is
end entity Code12b14bTb;

architecture sim of Code12b14bTb is

   -- component generics
   constant TPD_G          : time    := 1 ns;
   constant RST_POLARITY_G : sl      := '1';
   constant RST_ASYNC_G    : boolean := false;

   -- component ports
   signal clk         : sl;                                      -- [in]
   signal clkEn       : sl               := '1';                 -- [in]
   signal rst         : sl               := not RST_POLARITY_G;  -- [in]
   signal encDispIn   : slv(1 downto 0);
   signal encDataIn   : slv(11 downto 0) := (others => '0');     -- [in]
   signal encDataKIn  : sl               := '0';                 -- [in]
   signal encDataOut  : slv(13 downto 0);                        -- [out]
   signal encDispOut  : slv(1 downto 0);
   signal encInvalidK : sl;                                      -- [out]

   signal started         : boolean := false;
   shared variable runVar : integer := 0;
   signal run             : integer := 0;
   signal lastEncDataOut  : slv(13 downto 0);

   signal encDispInInt    : BlockDisparityType;
   signal encDispOutInt   : BlockDisparityType;
   signal encDataInString : string(1 to 8);

--   signal startSet : sl := '0';

   -------------------------------------------------------------------------------------------------

   signal decDataIn    : slv(13 downto 0);         -- [in]
   signal decDispIn    : slv(1 downto 0) := "01";  -- [in]
   signal decDataOut   : slv(11 downto 0);         -- [out]
   signal decDataKOut  : sl;                       -- [out]
   signal decDispOut   : slv(1 downto 0);          -- [out]
   signal decCodeError : sl;                       -- [out]
   signal decDispError : sl;                       -- [out]

   signal dlyDataOut  : slv(11 downto 0);
   signal dlyDataKOut : sl;

begin

   encDispInInt  <= toBlockDisparityType(encDispIn);
   encDispOutInt <= toBlockDisparityType(encDispOut);

   encDataInString <= toString(encDataIn, encDataKIn);

   -- component instantiation
   U_Encoder12b14b : entity surf.Encoder12b14b
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         DEBUG_DISP_G   => true)
      port map (
         clk     => clk,                -- [in]
         clkEn   => clkEn,              -- [in]
         rst     => rst,                -- [in]
         dataIn  => encDataIn,          -- [in]
         dispIn  => encDispIn,
         dataKIn => encDataKIn,         -- [in]
         dataOut => encDataOut,         -- [out]
         dispOut => encDispOut);
--          invalidK => invalidK);         -- [out]


   U_ClkRst_1 : entity surf.ClkRst
      generic map (
         CLK_PERIOD_G      => 4 ns,
         CLK_DELAY_G       => 1 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 5 us,
         SYNC_RESET_G      => true)
      port map (
         clkP => clk,
         rst  => rst);



   main : process is
      variable a : slv(11 downto 0);
      variable b : slv(11 downto 0);

      procedure doComb (
         a  : in slv(11 downto 0);
         ak : in sl;
         b  : in slv(11 downto 0);
         bk : in sl)
      is
         variable disparity : BlockDisparityType;
      begin
         disparity        := -2;
         while (disparity <= 4) loop
            wait until clk = '0';
            encDispIn  <= toSlv(disparity);
            encDataIn  <= a;
            encDataKIn <= ak;
            decDispIn  <= decDispOut;
            wait until clk = '1';
            started    <= true;
--            startSet <= ite(disparity = -2, '1', '0') after 1 ns;
--            first := '0';
--            runVar  := 0;
            wait until clk = '0';
            encDispIn  <= encDispOut;
            encDataIn  <= b;
            encDataKIn <= bk;
            decDispIn  <= toSlv(disparity);
            wait until clk = '1';
--            startSet <= '0' after 1 ns;
            disparity  := disparity + 2;
         end loop;

      end procedure doComb;

      impure function isKCode (
         d : slv(11 downto 0))
         return boolean is
      begin
         for i in K_CODE_TABLE_C'range loop
            if (K_CODE_TABLE_C(i) = d) then
--                 d /= K_120_3_C and
--                 d /= K_120_11_C and
--                 d /= K_120_19_C) then
--               print("Sending K Code: " & str(K_CODE_TABLE_C(i).k12));
               return true;
            end if;
         end loop;
         return false;
      end function isKCode;

   begin

      wait until clk = '1';
      wait until clk = '1';
      wait until rst = '0';
      wait until clk = '1';

      encDataIn  <= K_120_3_C;
      encDataKIn <= '1';

      wait for 1 us;
      wait until clk = '1';

      for i in 0 to 2**12-1 loop
         print("i: " & toString(conv_std_logic_vector(i, 12), '0'));
         for j in 0 to 2**12-1 loop
            a := conv_std_logic_vector(i, 12);
            b := conv_std_logic_vector(j, 12);

            doComb(a, '0', b, '0');

            if (isKCode(a)) then
               doComb(a, '1', b, '0');
            end if;

            if (isKCode(b)) then
               doComb(a, '0', b, '1');
            end if;

            if (isKCode(a) and isKCode(b)) then
               doComb(a, '1', b, '1');
            end if;

         end loop;

      end loop;

--      stop(0);

   end process;



   monitor : process is
   begin
      wait until clk = '0';
      if (started) then
         for i in 0 to 13 loop
            if (runVar = 0) then
               if (encDataOut(i) = '1') then
                  runVar := runVar + 1;
               else
                  runVar := runVar - 1;
               end if;
            elsif (runVar > 0) then
               if (encDataOut(i) = '1') then
                  runVar := runVar + 1;
               else
                  runVar := -1;
               end if;
            elsif (runVar < 0) then
               if (encDataOut(i) = '0') then
                  runVar := runVar - 1;
               else
                  runVar := 1;
               end if;
            end if;

            assert ((runVar < 7 and runVar > -7) or
                    (encDataOut = K_120_3_CODE_C) or
                    (encDataOut = K_120_11_CODE_C) or
                    (encDataOut = K_120_19_CODE_C))
               report "Run length violation: " &
               "encDataOut: " & str(encDataOut) &
               " runVar: " & str(runVar) &
               " lastEncDataOut: " & str(lastEncDataOut)
               severity failure;

         end loop;
         lastEncDataOut <= encDataOut;

         assert (decDispError = '0') report "Disparity Error" severity failure;
         assert (decCodeError = '0') report "Code Error" severity failure;
         assert (decDataOut = dlyDataOut and decDataKOut = dlyDataKOut) report "Encode/Decode mismatch" severity error;
      end if;

      run <= runVar;

   end process monitor;


   -------------------------------------------------------------------------------------------------
   -- Decoder
   -------------------------------------------------------------------------------------------------
   decDataIn <= encDataOut;
   U_Decoder12b14b_1 : entity surf.Decoder12b14b
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         DEBUG_DISP_G   => true)
      port map (
         clk       => clk,              -- [in]
         clkEn     => clkEn,            -- [in]
         rst       => rst,              -- [in]
         dataIn    => decDataIn,        -- [in]
         dispIn    => decDispIn,        -- [in]
         dataOut   => decDataOut,       -- [out]
         dataKOut  => decDataKOut,      -- [out]
         dispOut   => decDispOut,       -- [out]
         codeError => decCodeError,     -- [out]
         dispError => decDispError);    -- [out]

   -------------------------------------------------------------------------------------------------
   -- Delay encDataIn in parallel to compare against output of decoder
   -------------------------------------------------------------------------------------------------
   U_SynchronizerVector_1 : entity surf.SynchronizerVector
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => RST_POLARITY_G,
         RST_ASYNC_G    => RST_ASYNC_G,
         STAGES_G       => 2,
         WIDTH_G        => 13)
      port map (
         clk                  => clk,           -- [in]
         rst                  => rst,           -- [in]
         dataIn(11 downto 0)  => encDataIn,     -- [in]
         dataIn(12)           => encDataKIn,    -- [in]
         dataOut(11 downto 0) => dlyDataOut,    -- [out]
         dataOut(12)          => dlyDataKOut);  -- [out]

end architecture sim;
