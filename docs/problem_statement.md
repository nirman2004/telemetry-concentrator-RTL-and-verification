# Problem Statement

## 1. Background

Industrial monitoring systems use multiple sensors to collect telemetry from equipment and surrounding environments.

Different sensors may generate data at different rates and operate using independent clock domains. Their data must be buffered and transferred reliably to a shared processing or monitoring interface.

Emergency events require higher scheduling priority than ordinary telemetry, while normal sensor channels must still receive fair access to the output.

These requirements create challenges involving asynchronous data transfer, buffering, arbitration, and flow control.

## 2. Problem Definition

The objective of this project is to design and verify a SystemVerilog-based telemetry concentrator that accepts packet-based data from three independent input channels:

- Vibration
- Temperature
- Emergency

Each channel operates with an independent input clock and has its own asynchronous FIFO buffer.

A centralized scheduler selects packets from the available buffers and forwards them through a shared ready/valid output interface.

The scheduler must prioritize emergency traffic without allowing normal traffic to be indefinitely postponed under the specified arbitration policy.

## 3. Key Design Challenges

### 3.1 Independent Clock Domains

The input channels operate using independent clocks. Directly transferring control information between these domains requires careful clock-domain synchronization.

The design uses asynchronous FIFO structures with synchronized Gray-coded pointers.

### 3.2 Independent Packet Buffering

Each channel needs independent buffering so that temporary differences between input and output rates do not immediately prevent packet acceptance.

The FIFO implementation must correctly handle full and empty conditions.

### 3.3 Priority-Aware Scheduling

Emergency traffic must receive higher priority than normal traffic.

However, continuously selecting emergency traffic could starve vibration and temperature packets.

The scheduler therefore supports a maximum of two consecutive emergency packet selections while normal traffic is waiting, followed by normal-channel service.

### 3.4 Fairness Between Normal Channels

Vibration and temperature packets share the normal-priority class.

A round-robin arbitration policy is used to distribute service between these channels.

### 3.5 Downstream Backpressure

The downstream receiver may temporarily be unable to accept a packet.

The output interface must preserve the active packet and valid indication during backpressure until the transfer can complete, subject to reset behavior.

### 3.6 Packet-Level Scheduling

Once a packet transmission begins, arbitration must not interrupt that active packet.

The scheduler uses grant locking to preserve packet-level transmission continuity.

## 4. Project Objectives

The project aims to:

1. Develop a modular multi-clock telemetry concentrator using SystemVerilog.
2. Implement independent asynchronous FIFO buffers for three input channels.
3. Integrate binary and Gray-coded pointer logic with clock-domain synchronizers.
4. Implement emergency-priority packet scheduling.
5. Provide round-robin fairness between normal channels.
6. Support packet-level grant locking.
7. Implement a ready/valid output interface with backpressure handling.
8. Develop a self-checking simulation environment using scoreboards.
9. Check important protocol behaviors using SystemVerilog assertions.
10. Measure defined functional coverage across key design scenarios.

## 5. Expected Outcome

The expected outcome is a modular RTL design that combines independent asynchronous input buffering with priority-aware packet scheduling and a shared output interface.

The verification environment should exercise the major functional scenarios and report packet-checking results, assertion outcomes, and functional coverage.

The completed integration regression reported:

- All tests passed.
- Zero scoreboard errors in the reported integration tests.
- Zero reported SVA failure counters.
- 100% coverage across the defined functional coverage coverpoints.

Detailed results are available in [`results.md`](results.md).

## 6. Project Scope

The project focuses on RTL implementation and simulation-based functional verification.

It does not claim formal verification, exhaustive verification, physical CDC signoff, or silicon validation.