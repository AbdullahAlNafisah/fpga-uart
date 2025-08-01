# ==========================================================
# Description: Cocotb testbench for verifying UART TX/RX
# Author: Abdullah Alnafisah
# ==========================================================

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
import logging

# DUT configuration
CLK_FREQ_HZ = 50_000_000  # 50 MHz
BAUD_RATE = 9600
CLK_PERIOD_NS = 1e9 / CLK_FREQ_HZ  # ~20 ns
# BIT_TIME_NS = 1e9 / BAUD_RATE  # ~104166 ns
BIT_TIME_NS = int(round(1e9 / BAUD_RATE))


async def reset_dut(rst_n):
    """Generate an active-low reset pulse."""
    rst_n.value = 0
    await Timer(5 * CLK_PERIOD_NS, units="ns")
    rst_n.value = 1
    await Timer(5 * CLK_PERIOD_NS, units="ns")


async def uart_send_byte(dut, byte):
    """Send a byte serially via RX line (LSB first)."""

    # Idle line high
    dut.rx.value = 1
    await Timer(BIT_TIME_NS, units="ns")

    # Start bit (low)
    dut.rx.value = 0
    await Timer(BIT_TIME_NS, units="ns")

    # Data bits (LSB first)
    for i in range(8):
        dut.rx.value = (byte >> i) & 1
        await Timer(BIT_TIME_NS, units="ns")

    # # Data bits (MSB first)
    # for i in reversed(range(8)):
    #     dut.rx.value = (byte >> i) & 1
    #     await Timer(BIT_TIME_NS, units="ns")

    # Stop bit (high)
    dut.rx.value = 1
    await Timer(BIT_TIME_NS, units="ns")


@cocotb.test()
async def test_uart_tx_rx(dut):
    """Test UART RX and TX functionality."""
    logger = logging.getLogger("uart_tb")

    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units="ns").start())

    # Initialize inputs
    dut.rx.value = 1
    dut.tx_start.value = 0
    dut.tx_data.value = 0
    dut.rst_n.value = 1

    # Apply reset
    await reset_dut(dut.rst_n)

    # ------------------------------------------------------
    # UART RX Test
    # ------------------------------------------------------
    test_byte_rx = 0x5A
    logger.info(f"Sending byte 0x{test_byte_rx:02X} to DUT via RX line...")

    # Idle period before transmission
    await Timer(BIT_TIME_NS * 3, units="ns")

    await uart_send_byte(dut, test_byte_rx)

    # Wait enough time for entire frame (start + 8 bits + stop)
    await Timer(BIT_TIME_NS * 12, units="ns")

    assert (
        dut.rx_data.value == test_byte_rx
    ), f"Expected 0x{test_byte_rx:02X}, got 0x{dut.rx_data.value.integer:02X}"

    # ------------------------------------------------------
    # UART TX Test
    # ------------------------------------------------------
    test_byte_tx = 0x5A
    logger.info(f"Sending byte 0x{test_byte_tx:02X} via TX module...")

    dut.tx_data.value = test_byte_tx
    dut.tx_start.value = 1
    await RisingEdge(dut.clk)
    dut.tx_start.value = 0

    # Wait until TX completes
    while dut.tx_busy.value == 1:
        await RisingEdge(dut.clk)

    logger.info("TX Test Completed. Verify 'tx' waveform for correctness.")

    # Extra wait to capture full TX waveform
    await Timer(BIT_TIME_NS * 12, units="ns")

    logger.info("UART TX/RX test finished successfully.")
