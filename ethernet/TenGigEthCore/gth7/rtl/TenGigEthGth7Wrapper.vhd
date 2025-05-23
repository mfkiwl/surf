-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Gth7 Wrapper for 10GBASE-R Ethernet
-- Note: This module supports up to a MGT QUAD of 10GigE interfaces
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;
use surf.EthMacPkg.all;
use surf.TenGigEthPkg.all;

entity TenGigEthGth7Wrapper is
   generic (
      TPD_G             : time                             := 1 ns;
      NUM_LANE_G        : natural range 1 to 4             := 1;
      JUMBO_G           : boolean                          := true;
      PAUSE_EN_G        : boolean                          := true;
      ROCEV2_EN_G       : boolean                          := false;
      -- QUAD PLL Configurations
      USE_GTREFCLK_G    : boolean                          := false;  --  FALSE: gtClkP/N,  TRUE: gtRefClk
      REFCLK_DIV2_G     : boolean                          := false;  --  FALSE: gtClkP/N = 156.25 MHz,  TRUE: gtClkP/N = 312.5 MHz
      QPLL_REFCLK_SEL_G : bit_vector                       := "001";
      -- AXI-Lite Configurations
      EN_AXI_REG_G      : boolean                          := false;
      -- AXI Streaming Configurations
      AXIS_CONFIG_G     : AxiStreamConfigArray(3 downto 0) := (others => EMAC_AXIS_CONFIG_C));
   port (
      -- Local Configurations
      localMac            : in  Slv48Array(NUM_LANE_G-1 downto 0)              := (others => MAC_ADDR_INIT_C);
      -- Streaming DMA Interface
      dmaClk              : in  slv(NUM_LANE_G-1 downto 0);
      dmaRst              : in  slv(NUM_LANE_G-1 downto 0);
      dmaIbMasters        : out AxiStreamMasterArray(NUM_LANE_G-1 downto 0);
      dmaIbSlaves         : in  AxiStreamSlaveArray(NUM_LANE_G-1 downto 0);
      dmaObMasters        : in  AxiStreamMasterArray(NUM_LANE_G-1 downto 0);
      dmaObSlaves         : out AxiStreamSlaveArray(NUM_LANE_G-1 downto 0);
      -- Slave AXI-Lite Interface
      axiLiteClk          : in  slv(NUM_LANE_G-1 downto 0)                     := (others => '0');
      axiLiteRst          : in  slv(NUM_LANE_G-1 downto 0)                     := (others => '0');
      axiLiteReadMasters  : in  AxiLiteReadMasterArray(NUM_LANE_G-1 downto 0)  := (others => AXI_LITE_READ_MASTER_INIT_C);
      axiLiteReadSlaves   : out AxiLiteReadSlaveArray(NUM_LANE_G-1 downto 0);
      axiLiteWriteMasters : in  AxiLiteWriteMasterArray(NUM_LANE_G-1 downto 0) := (others => AXI_LITE_WRITE_MASTER_INIT_C);
      axiLiteWriteSlaves  : out AxiLiteWriteSlaveArray(NUM_LANE_G-1 downto 0);
      -- SFP+ Ports
      sigDet              : in  slv(NUM_LANE_G-1 downto 0)                     := (others => '1');
      txFault             : in  slv(NUM_LANE_G-1 downto 0)                     := (others => '0');
      txDisable           : out slv(NUM_LANE_G-1 downto 0);
      -- Misc. Signals
      extRst              : in  sl                                             := '0';
      phyClk              : out sl;
      phyRst              : out sl;
      phyReady            : out slv(NUM_LANE_G-1 downto 0);
      -- MGT Clock Port (156.25 MHz or 312.5 MHz)
      gtRefClk            : in  sl                                             := '0';  -- 156.25 MHz only
      gtClkP              : in  sl                                             := '1';
      gtClkN              : in  sl                                             := '0';
      -- MGT Ports
      gtTxP               : out slv(NUM_LANE_G-1 downto 0);
      gtTxN               : out slv(NUM_LANE_G-1 downto 0);
      gtRxP               : in  slv(NUM_LANE_G-1 downto 0);
      gtRxN               : in  slv(NUM_LANE_G-1 downto 0));
end TenGigEthGth7Wrapper;

architecture mapping of TenGigEthGth7Wrapper is

   signal phyClock : sl;
   signal phyReset : sl;

   signal qplllock      : sl;
   signal qplloutclk    : sl;
   signal qplloutrefclk : sl;

   signal qpllRst   : slv(NUM_LANE_G-1 downto 0);
   signal qpllReset : sl;

begin

   phyClk <= phyClock;
   phyRst <= phyReset;

   ----------------------
   -- Common Clock Module
   ----------------------
   TenGigEthGth7Clk_Inst : entity surf.TenGigEthGth7Clk
      generic map (
         TPD_G             => TPD_G,
         USE_GTREFCLK_G    => USE_GTREFCLK_G,
         REFCLK_DIV2_G     => REFCLK_DIV2_G,
         QPLL_REFCLK_SEL_G => QPLL_REFCLK_SEL_G)
      port map (
         -- Clocks and Resets
         extRst        => extRst,
         phyClk        => phyClock,
         phyRst        => phyReset,
         -- MGT Clock Port (156.25 MHz or 312.5 MHz)
         gtRefClk      => gtRefClk,
         gtClkP        => gtClkP,
         gtClkN        => gtClkN,
         -- Quad PLL Ports
         qplllock      => qplllock,
         qplloutclk    => qplloutclk,
         qplloutrefclk => qplloutrefclk,
         qpllRst       => qpllReset);

   qpllReset <= uOr(qpllRst) and not(qPllLock);

   ----------------
   -- 10GigE Module
   ----------------
   GEN_LANE :
   for i in 0 to NUM_LANE_G-1 generate

      TenGigEthGth7_Inst : entity surf.TenGigEthGth7
         generic map (
            TPD_G         => TPD_G,
            JUMBO_G       => JUMBO_G,
            PAUSE_EN_G    => PAUSE_EN_G,
            ROCEV2_EN_G   => ROCEV2_EN_G,
            -- AXI-Lite Configurations
            EN_AXI_REG_G  => EN_AXI_REG_G,
            -- AXI Streaming Configurations
            AXIS_CONFIG_G => AXIS_CONFIG_G(i))
         port map (
            -- Local Configurations
            localMac           => localMac(i),
            -- Streaming DMA Interface
            dmaClk             => dmaClk(i),
            dmaRst             => dmaRst(i),
            dmaIbMaster        => dmaIbMasters(i),
            dmaIbSlave         => dmaIbSlaves(i),
            dmaObMaster        => dmaObMasters(i),
            dmaObSlave         => dmaObSlaves(i),
            -- Slave AXI-Lite Interface
            axiLiteClk         => axiLiteClk(i),
            axiLiteRst         => axiLiteRst(i),
            axiLiteReadMaster  => axiLiteReadMasters(i),
            axiLiteReadSlave   => axiLiteReadSlaves(i),
            axiLiteWriteMaster => axiLiteWriteMasters(i),
            axiLiteWriteSlave  => axiLiteWriteSlaves(i),
            -- SFP+ Ports
            sigDet             => sigDet(i),
            txFault            => txFault(i),
            txDisable          => txDisable(i),
            -- Misc. Signals
            extRst             => extRst,
            phyClk             => phyClock,
            phyRst             => phyReset,
            phyReady           => phyReady(i),
            -- Quad PLL Ports
            qplllock           => qplllock,
            qplloutclk         => qplloutclk,
            qplloutrefclk      => qplloutrefclk,
            -- MGT Ports
            gtTxP              => gtTxP(i),
            gtTxN              => gtTxN(i),
            gtRxP              => gtRxP(i),
            gtRxN              => gtRxN(i));

   end generate GEN_LANE;

end mapping;
