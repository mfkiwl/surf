-------------------------------------------------------------------------------
-- File       : PreAddComplexMult.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2021-03-16
-- Last update: 2021-03-16
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- This file is part of 'LCLS2 AMC Carrier Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.std_logicac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LCLS2 AMC Carrier Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.fixed_pkg.all;
use ieee.fixed_float_types.all;

library surf;
use surf.StdRtlPkg.all;
use surf.ComplexFixedPkg.all;

--  pre add complex multiply (A + D) * B 
--  inferres 4 DSP slices when using REG_IN_G = ture, delay is 5

entity PreAddComplexMult is
   generic (
      TPD_G            : time                 := 1 ns;
      REG_IN_G         : boolean              := true;
      REG_OUT_G        : boolean              := false;
      OUT_OVERFLOW_STYLE_G : fixed_overflow_style_type := fixed_wrap;
      OUT_ROUNDING_STYLE_G : fixed_round_style_type    := fixed_truncate);
   port (
      clk    : in  std_logic;
      ce     : in  std_logic := '1';
      a      : in  cfixed;
      avld   : in  std_logic := '1';
      d      : in  cfixed;
      dvld   : in  std_logic := '1';
      b      : in  cfixed;
      bvld   : in  std_logic := '1';
      y      : out cfixed;
      yvld   : out std_logic;
      s      : in  std_logic);
end PreAddComplexMult;

architecture rtl of PreAddComplexMult is

   constant DELAY_C      : integer := 4 + ite(REG_IN_G, 1, 0) + ite(REG_OUT_G, 1, 0);

   constant REG_DEPTH_C  : integer := 3;

   constant AD_W_C    : integer := 27; -- 27 x 18 multiplier for DSP48
   constant AD_LOW_C  : integer := minimum(a.re'low, d.re'low);
   constant AD_HIGH_C : integer := a.re'high + 1;
   constant AD_HIGH_CLIP_C : integer := minimum(AD_W_C + AD_LOW_C - 1, AD_HIGH_C);

   constant M_LOW_C  : integer := AD_LOW_C + b.re'low;
   constant M_HIGH_C : integer := AD_HIGH_CLIP_C + b.re'high + 1;

   constant P_W_C    : integer := 48;
   constant P_LOW_C  : integer := AD_LOW_C + b.re'low;
   constant P_HIGH_C : integer := P_W_C + P_LOW_C - 1;

   -- For resizing into preg:
   constant INT_OVERFLOW_STYLE_C : fixed_overflow_style_type := fixed_wrap;
   constant INT_ROUNDING_STYLE_C : fixed_round_style_type    := fixed_truncate;
   

   type RegType is record
      areg  : cfixedArray(REG_DEPTH_C - 1 downto 0)(re(a.re'range), im(a.im'range));
      breg  : cfixedArray(REG_DEPTH_C - 1 downto 0)(re(b.re'range), im(b.im'range));
      dreg  : cfixedArray(REG_DEPTH_C - 1 downto 0)(re(d.re'range), im(d.im'range)); -- add one extra element so we can index with CIN_REG_G
      adreg : cfixedArray(REG_DEPTH_C - 1 downto 0)(re(AD_HIGH_C downto AD_LOW_C), im(AD_HIGH_C downto AD_LOW_C)); -- add one extra element so we can index with CIN_REG_G
      sr, srr : std_logic; -- synthesis tool has trouble inferring DSP pre adder if using std_logic_vector and shift
      vld   : std_logic_vector(DELAY_C - 1 downto 0);
      p_rr, p_ii, p_ri, p_ir : sfixed(P_HIGH_C downto P_LOW_C);
      m_rr, m_ii, m_ri, m_ir : sfixed(M_HIGH_C downto M_LOW_C);
      y         : cfixed(re(y.re'range), im(y.im'range));
   end record RegType;

   constant REG_INIT_C : RegType := (
      areg  => (others => (others => (others => '0'))),
      breg  => (others => (others => (others => '0'))),
      dreg  => (others => (others => (others => '0'))),
      adreg => (others => (others => (others => '0'))),
      sr    => '0',
      srr   => '0',
      vld   => (others => '0'),
      m_rr  => (others => '0'),
      m_ii  => (others => '0'),
      m_ri  => (others => '0'),
      m_ir  => (others => '0'),
      p_rr  => (others => '0'),
      p_ii  => (others => '0'),
      p_ri  => (others => '0'),
      p_ir  => (others => '0'),
      y     => (others => (others => '0')));

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;
   
   --attribute USE_DSP      : string;
   --attribute USE_DSP of r : signal is "YES";

begin

   assert ((a.re'length < 28) and (b.re'length < 19)) or ((a.re'length < 19) and (b.re'length < 28))
       report "Input data should be less than 18x27 bits" severity failure;
       
       
   comb : process( a, b, d, s, avld, bvld, dvld, r ) is
      variable v : RegType;
   begin

      v := r;
      
      v.vld(0) := avld and bvld and dvld;
      for i in DELAY_C - 1 downto 1 loop
          v.vld(i) := r.vld(i-1);
      end loop;

      -- Input pipeline
      for i in REG_DEPTH_C - 1 downto 1 loop
          v.areg(i) := r.areg(i-1);
          v.breg(i) := r.breg(i-1);
          v.dreg(i) := r.dreg(i-1);
      end loop;

      if REG_IN_G then
          v.areg(0) := a;
          v.breg(0) := b;
          v.dreg(0) := d;
          v.sr      := s;
          v.srr     := r.sr;
      else
          -- Skip 1st pipeline stage
          v.areg(1) := a;
          v.breg(1) := b;
          v.dreg(1) := d;
          v.srr     := s;
      end if;

      if v.srr = '0' then
         v.adreg(1) := v.areg(1) - v.dreg(1);
      else
         v.adreg(1) := v.areg(1) + v.dreg(1);
      end if;
      
      if r.srr = '0' then
         v.adreg(2) := v.areg(2) - v.dreg(2);
      else
         v.adreg(2) := v.areg(2) + v.dreg(2);
      end if;

      -- Real part of cmultAdd
      v.m_ii := r.breg(1).im * resize(r.adreg(1).im, AD_HIGH_CLIP_C, AD_LOW_C, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
      v.p_ii := resize(r.m_ii, r.p_ii, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
      v.m_rr := r.breg(2).re * resize(r.adreg(2).re, AD_HIGH_CLIP_C, AD_LOW_C, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
      v.p_rr := resize(r.m_rr - r.p_ii, r.p_rr, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);

      -- Imag part of cmultAdd
      v.m_ir := r.breg(1).re * resize(r.adreg(1).im, AD_HIGH_CLIP_C, AD_LOW_C, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
      v.p_ir := resize(r.m_ir, r.p_ir, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
      v.m_ri := r.breg(2).im * resize(r.adreg(2).re, AD_HIGH_CLIP_C, AD_LOW_C, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
      v.p_ri := resize(r.m_ri + r.p_ir, r.p_ri, INT_OVERFLOW_STYLE_C, INT_ROUNDING_STYLE_C);
      
      -- resize for output
      v.y := to_cfixed(
                resize(r.p_rr, y.re, OUT_OVERFLOW_STYLE_G, OUT_ROUNDING_STYLE_G),
                resize(r.p_ri, y.im, OUT_OVERFLOW_STYLE_G, OUT_ROUNDING_STYLE_G));
      rin <= v;
      
      yvld <= r.vld(DELAY_C-1);
      -- Outputs
      if REG_OUT_G then
         y <= r.y;
      else
         y <= v.y;
      end if;
      
   end process comb;

   seq : process(clk) is
   begin
      if rising_edge(clk) then
         r <= rin after TPD_G;
      end if;
   end process seq;

end architecture rtl;
