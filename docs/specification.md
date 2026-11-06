# Design Specification

## 1. Project Description

The Priority-Aware Multi-Clock Industrial Telemetry Concentrator collects telemetry packets from three independent sensor channels and forwards them through a shared output interface.

The design uses asynchronous FIFO buffers and a centralized packet scheduler to support independent input clock domains, priority-based arbitration, and downstream backpressure.

## 2. Functional Requirements

| ID | Requirement |
|---|---|
| FR-01 | The system shall support three input channels: vibration, temperature, and emergency. |
| FR-02 | Each input channel shall have an independent asynchronous FIFO buffer. |
| FR-03 | The scheduler shall select packets from available input buffers. |
| FR-04 | Emergency traffic shall receive the highest scheduling priority. |
| FR-05 | The scheduler shall support up to two consecutive emergency packets when normal traffic is waiting. |
| FR-06 | After the emergency burst limit, a waiting normal packet shall receive service. |
| FR-07 | Vibration and temperature traffic shall use round-robin arbitration. |
| FR-08 | An active packet transmission shall not be interrupted by a change in arbitration requests. |
| FR-09 | The output shall use a ready/valid handshake. |
| FR-10 | Output data and valid indication shall remain stable during downstream backpressure, subject to reset behavior. |
| FR-11 | The design shall support reset and recovery scenarios. |

## 3. Interface and Packet Configuration

### 3.1 Packet Width

| Parameter | Value |
|---|---:|
| Packet width | 44 bits |
| Channel ID width | 2 bits |
| Packet type width | 2 bits |
| Sequence number width | 8 bits |
| Payload width | 32 bits |

### 3.2 Packet Layout

| Field | Bits |
|---|---|
| Channel ID | `[43:42]` |
| Packet Type | `[41:40]` |
| Sequence Number | `[39:32]` |
| Payload | `[31:0]` |

### 3.3 Channel Encoding

| Encoding | Channel |
|---|---|
| `00` | Vibration |
| `01` | Temperature |
| `10` | Emergency |
| `11` | Reserved |

Each of the three implemented channels supports four packet-type encodings, giving 12 valid channel/type combinations.

## 4. FIFO Configuration

Each channel uses an asynchronous FIFO.

| Parameter | Configuration |
|---|---:|
| Data width | 44 bits |
| Address width | 4 bits |
| Depth | 16 entries |
| Pointer representation | Binary and Gray code |
| Clocking | Independent write and read clocks |

The FIFO implementation includes pointer synchronization between clock domains and full/empty status generation.

## 5. Scheduling Requirements

### 5.1 Priority Policy

Emergency traffic has higher priority than normal traffic.

### 5.2 Emergency Burst Limiting

The scheduler permits up to two consecutive emergency packet selections while normal traffic is pending.

After reaching this limit, the scheduler selects a waiting normal packet.

### 5.3 Normal Traffic Arbitration

Vibration and temperature channels use round-robin arbitration to distribute normal traffic service.

### 5.4 Packet-Level Grant Locking

Once packet transmission begins, the scheduler retains the selected source until the active packet completes.

## 6. Output Protocol

The output uses a ready/valid interface.

A packet transfer occurs when:

```systemverilog
out_valid && out_ready
```

When the receiver is not ready, the output packet must remain stable while valid is asserted, subject to reset behavior.

## 7. Verification Requirements

The verification environment shall check:

- Correct packet format and channel identification.
- All valid channel/type combinations.
- Packet acceptance and delivery.
- Emergency priority behavior.
- Normal-channel round-robin fairness.
- FIFO full and empty conditions.
- Simultaneous channel requests.
- Output backpressure handling.
- Producer stall behavior.
- Packet-level grant locking.
- Reset behavior and recovery.
- Assertion failures and scoreboard errors.
- Defined functional coverage bins.

## 8. Configuration Summary

| Feature | Configuration |
|---|---|
| Input channels | 3 |
| Priority classes | 2 |
| Packet width | 44 bits |
| FIFO depth per channel | 16 |
| FIFO data width | 44 bits |
| Scheduler | Priority-aware |
| Normal arbitration | Round robin |
| Emergency burst limit | 2 consecutive packets while normal traffic waits |
| Output protocol | Ready/valid |
| Verification language | SystemVerilog |
| Simulation tool | Vivado 2025.1 XSim |

## 9. Scope and Limitations

This specification describes the intended functional behavior of the implemented RTL and its simulation-based verification scope.

It does not establish formal correctness, exhaustive verification, physical CDC signoff, or silicon-level validation.