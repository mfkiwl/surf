#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue XauiReg
#-----------------------------------------------------------------------------
# File       : XauiReg.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue XauiReg
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the rogue software platform, including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class XauiReg(pr.Device):
    def __init__(   self,       
                    name        = "XauiReg",
                    description = "XauiReg",
                    memBase     =  None,
                    offset      =  0x00,
                    hidden      =  False,
                ):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden, )

        ##############################
        # Variables
        ##############################

        self.addVariables(  name         = "StatusCounters",
                            description  = "Status Counters",
                            offset       =  0x00,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                            number       =  25,
                            stride       =  4,
                        )

        self.addVariable(   name         = "StatusVector",
                            description  = "Status Vector",
                            offset       =  0x100,
                            bitSize      =  25,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "MacAddress",
                            description  = "MAC Address (big-Endian)",
                            offset       =  0x200,
                            bitSize      =  48,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "PauseTime",
                            description  = "PauseTime",
                            offset       =  0x21C,
                            bitSize      =  16,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "FilterEnable",
                            description  = "FilterEnable",
                            offset       =  0x228,
                            bitSize      =  1,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "PauseEnable",
                            description  = "PauseEnable",
                            offset       =  0x22C,
                            bitSize      =  1,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RO",
                        )

        self.addVariable(   name         = "ConfigVector",
                            description  = "ConfigVector",
                            offset       =  0x230,
                            bitSize      =  7,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "RollOverEn",
                            description  = "RollOverEn",
                            offset       =  0xF00,
                            bitSize      =  25,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "CounterReset",
                            description  = "CounterReset",
                            offset       =  0xFF4,
                            bitSize      =  1,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "WO",
                        )

        self.addVariable(   name         = "SoftReset",
                            description  = "SoftReset",
                            offset       =  0xFF8,
                            bitSize      =  1,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "WO",
                        )

        self.addVariable(   name         = "HardReset",
                            description  = "HardReset",
                            offset       =  0xFFC,
                            bitSize      =  1,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "WO",
                        )
