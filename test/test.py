# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    
    dut.user_project.vgad_0.clk.value = 0
    dut.user_project.vgad_0.vgad_0.vgatim_0.hsc_0.vids_0.state.value = 0
    dut.user_project.vgad_0.vgad_0.vgatim_0.vsc_0.vids_0.state.value = 0
    dut.user_project.vgad_0.vgad_0.vgatim_0.hsc_0.scnt_0.cnt.value = 0
    dut.user_project.vgad_0.vgad_0.vgatim_0.vsc_0.scnt_0.cnt.value = 0
    
    dut._log.info("Test project behavior")

    # Set the input values you want to test
    #dut.ui_in.value = 20
    #dut.uio_in.value = 30

    # Wait for one clock cycle to see the output values
    await ClockCycles(dut.clk, 194) # to pass syn

    # The following assersion is just an example of how to check the output values.
    # Change it to match the actual expected output of your module:
    assert dut.uo_out.value == 128
    #LogicArray('10000000', Range(7, 'downto', 0))

    # Keep testing the module by changing the input values, waiting for
    # one or more clock cycles, and asserting the expected output values.
