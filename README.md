# Priority-Aware Multi-Clock Industrial Telemetry Concentrator

A SystemVerilog RTL design and functional verification project implementing a multi-channel industrial telemetry concentrator with asynchronous FIFO buffers, priority-aware packet scheduling, backpressure handling, and packet-level arbitration.

## Project Overview

Industrial monitoring systems collect data from multiple sensors operating at different clock frequencies. These data streams must be buffered, prioritized, and transferred reliably to a shared output interface.

This project implements a telemetry concentrator with three independent input channels:

- Vibration monitoring
- Temperature monitoring
- Emergency event monitoring

Each channel has an asynchronous FIFO buffer. A centralized packet scheduler arbitrates between the buffered channels and transfers packets through a shared ready/valid output interface.

The design focuses on asynchronous buffering, packet integrity, priority scheduling, fairness, backpressure, and reset recovery.

## Architecture

### High-Level Block Diagram

```text
       Vibration Input
             |
        Async FIFO
             |
             |
      Temperature Input
             |
        Async FIFO
             |
             |       +----------------------+
             +------>|                      |
                     |  Priority-Aware      |
      Emergency      |  Packet Scheduler    |----> Ready/Valid
        Input        |                      |      Output
             |       +----------------------+
        Async FIFO
```

The system contains:

1. **Asynchronous FIFO buffers:** Independently buffer packets arriving from different clock domains.
2. **Sensor packet buffers:** Interface between the input channels and the scheduler.
3. **Packet scheduler:** Selects packets according to priority and fairness rules.
4. **Output interface:** Transfers packets using a ready/valid handshake.

## Packet Format

The system uses a 44-bit packet format.

| Field | Bit Range | Width |
|---|---|---:|
| Channel ID | [43:42] | 2 bits |
| Packet Type | [41:40] | 2 bits |
| Sequence Number | [39:32] | 8 bits |
| Payload | [31:0] | 32 bits |

### Channel Encoding

| Channel | ID |
|---|---|
| Vibration | `2'b00` |
| Temperature | `2'b01` |
| Emergency | `2'b10` |
| Reserved | `2'b11` |

Four packet-type encodings are exercised for each of the three valid channels, resulting in 12 channel/type combinations.

## Scheduling Policy

The packet scheduler implements the following arbitration policy:

- Emergency packets receive priority over normal traffic.
- Emergency traffic is limited to a maximum burst of two consecutive packets when normal traffic is waiting.
- After the emergency burst limit, a waiting normal packet gets an opportunity to transmit.
- Vibration and temperature channels use round-robin arbitration.
- An active packet transfer is not interrupted by a newly arriving higher-priority request.
- Output packet data and valid status remain stable during backpressure.

The scheduler is configured with `MAX_EMERGENCY_BURST = 2` in the integration testbench.

## RTL Implementation

The design is organized into reusable RTL modules.

### Asynchronous FIFO

- Parameterized data width and address width.
- Binary and Gray-code pointer management.
- Two-stage pointer synchronization.
- Full and empty flag generation.
- Independent write and read clock domains.

### Sensor Packet Buffer

- Integrates an asynchronous FIFO with an output staging register.
- Implements ready/valid flow control.
- Handles FIFO read latency and output backpressure.

### Packet Scheduler

- Emergency priority arbitration.
- Bounded emergency burst handling.
- Round-robin normal-channel selection.
- Packet-level grant locking.
- Output backpressure handling.

## Verification Environment

The project uses a SystemVerilog-based verification environment simulated with Vivado XSim.

The verification environment includes:

| Component | Purpose |
|---|---|
| Testbenches | Exercise individual modules and system behavior |
| Reference scoreboard | Compare accepted and received packets |
| SystemVerilog Assertions | Check protocol and stability properties |
| Functional coverage | Track defined verification scenarios |
| Clock generators | Simulate independent input clock domains |

### Verification Components

**1. Scoreboard**

Checks packet integrity and tracks accepted, received, pending, and erroneous transactions.

**2. Assertions**

Checks include:

- Output packet stability during backpressure.
- Valid packet known-state checks.
- Output valid behavior during stalls.
- Buffer status consistency.
- Producer-side ready/valid behavior.
- Invalid output behavior.

**3. Functional Coverage**

Tracks:

- Channel coverage.
- Packet-type coverage.
- Channel × packet-type combinations.
- Backpressure conditions.
- FIFO full and empty conditions.
- Buffer states.
- Scheduler grants.
- Contention scenarios.
- Round-robin behavior.
- Emergency burst handling.
- Grant locking.
- Scheduler idle conditions.

## Verification Scenarios

The integration regression covers the following scenarios:

| Test | Verification Scenario |
|---|---|
| 1 | Simultaneous multi-channel traffic |
| 2 | Output backpressure |
| 3 | Emergency priority under contention |
| 4 | Round-robin fairness |
| 5 | FIFO full and recovery |
| 6A | Temperature producer backpressure |
| 6B | Emergency producer backpressure |
| 7B | Reset during output backpressure |
| 7C | Reset with queued packets in multiple buffers |
| 7D | Post-reset recovery |
| 8 | Buffer state coverage |
| 9A | Emergency burst followed by vibration |
| 9B | Emergency burst followed by temperature |
| 10 | Scheduler grant locking under contention |
| 11 | All valid channel × packet-type combinations |

## Simulation Results

**Simulation environment**

- Simulator: Vivado XSim
- Tool version: Vivado 2025.1
- Verification language: SystemVerilog

### Regression Summary

- All integration regression tests passed.
- Scoreboard mismatch counters remained zero in the reported tests.
- No pending transactions remained in the focused test reports.
- All reported SystemVerilog assertion failure counters were zero.
- All 14 defined functional coverage points reached 100%.

### Functional Coverage

| Coverage Point | Coverage |
|---|---:|
| Channel | 100% |
| Packet Type | 100% |
| Channel × Packet Type | 100% |
| Backpressure | 100% |
| Buffer Full | 100% |
| Buffer Empty | 100% |
| Buffer State | 100% |
| Scheduler Grant | 100% |
| Contention | 100% |
| Grant × Contention | 100% |
| Normal Round Robin | 100% |
| Emergency Burst | 100% |
| Grant Lock | 100% |
| Scheduler Idle | 100% |

**Overall defined functional coverage: 100%.**

This represents coverage of the functional bins defined in the verification environment. It does not represent 100% code coverage, exhaustive verification, formal proof, or physical CDC signoff.

### Performance Observations

The reported integration run recorded:

| Metric | Observed Value |
|---|---:|
| Vibration packets accepted | 66 |
| Temperature packets accepted | 49 |
| Emergency packets accepted | 48 |
| Output transfer cycles | 156 |
| Output stall cycles | 261 |

Accepted and received packet totals can differ in tests that intentionally assert reset while packets are stalled or queued. Such packets are intentionally flushed by reset and should not automatically be classified as unexplained packet loss.

## Project Directory Structure

```text
Telemetry_Verification_Clean_New/
│
├── README.md
│
├── rtl/
│   ├── async_fifo.sv
│   ├── fifo_mem.sv
│   ├── read_pointer.sv
│   ├── synchronizer.sv
│   └── write_pointer.sv
│
├── system_rtl/
│   ├── packet_scheduler.sv
│   ├── sensor_packet_buffer.sv
│   └── telemetry_concentrator.sv
│
├── tb/
│   ├── async_fifo_sva.sv
│   ├── async_fifo_tb.sv
│   ├── async_fifo_tb_top.sv
│   ├── fifo_scoreboard.sv
│   ├── read_driver.sv
│   ├── read_monitor.sv
│   ├── write_driver.sv
│   └── write_monitor.sv
│
├── system_tb/
│   ├── packet_scheduler_tb.sv
│   ├── reference_scoreboard.sv
│   ├── sensor_packet_buffer_tb.sv
│   ├── telemetry_concentrator_tb.sv
│   ├── telemetry_coverage.sv
│   └── telemetry_sva.sv
│
├── coverage/
│   └── async_fifo_coverage.sv
│
├── docs/
│   ├── architecture.md
│   ├── packet_format.md
│   ├── problem_statement.md
│   ├── results.md
│   ├── specification.md
│   └── verification_plan.md
│
├── results/
│   ├── fifo_regression/
│   └── telemetry_regression/
│
├── assertions/
│
└── scripts/
```

## Running the Simulation

1. Install AMD Xilinx Vivado 2025.1 or a compatible version.
2. Open the Vivado project.
3. Add the RTL source files from `rtl/` and `system_rtl/`.
4. Add the required SystemVerilog testbench, assertion, scoreboard, and coverage files.
5. Select the required simulation top.
6. Run behavioral simulation.

### Available Simulation Tops

| Testbench | Purpose |
|---|---|
| `async_fifo_tb_top` | Asynchronous FIFO verification |
| `sensor_packet_buffer_tb` | Packet buffer verification |
| `packet_scheduler_tb` | Standalone scheduler verification |
| `telemetry_concentrator_tb` | Complete system integration verification |

For the complete system regression, select:

```text
telemetry_concentrator_tb
```

## Future Improvements

Potential extensions include:

- UVM-based reusable verification environment.
- Additional randomized stress testing.
- More extensive clock-ratio and reset-phase testing.
- Formal property checking.
- Synthesis and timing analysis.
- FPGA implementation and hardware demonstration.

## Author

**Nirman Dey**

B.Tech – Electronics and Communication Engineering

Jalpaiguri Government Engineering College

**Areas of Interest:** RTL Design, Design Verification, ASIC Design, and VLSI Systems.

---

*This project is an academic RTL design and functional verification implementation. It is not a safety-certified industrial system.*
