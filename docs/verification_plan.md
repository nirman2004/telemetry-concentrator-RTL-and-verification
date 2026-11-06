# Verification Plan

## 1. Objective

The objective of this verification plan is to validate the functional behavior of the Priority-Aware Multi-Clock Industrial Telemetry Concentrator.

The verification environment focuses on:

- Asynchronous FIFO functionality.
- Independent input-channel buffering.
- Priority-aware packet scheduling.
- Fairness between normal-priority channels.
- Packet integrity and ordering.
- Ready/valid output protocol.
- Backpressure handling.
- Reset behavior.
- SystemVerilog assertion checks.
- Functional coverage collection.

Verification is performed using a SystemVerilog testbench and Vivado 2025.1 XSim.

## 2. Design Under Verification

The design contains three asynchronous input channels:

| Channel | Priority |
|---|---|
| Vibration | Normal |
| Temperature | Normal |
| Emergency | Highest |

Each channel has an independent asynchronous FIFO.

The scheduler selects packets from the available buffers and transfers them through a shared ready/valid output interface.

## 3. Verification Environment

The integration testbench is:

`system_tb/telemetry_concentrator_tb.sv`

Supporting verification components include:

| Component | File | Purpose |
|---|---|---|
| Integration testbench | `telemetry_concentrator_tb.sv` | Drives and verifies system scenarios |
| Reference scoreboard | `reference_scoreboard.sv` | Checks expected packet behavior |
| Functional coverage | `telemetry_coverage.sv` | Tracks defined functional coverage bins |
| System assertions | `telemetry_sva.sv` | Checks protocol and design properties |

The FIFO verification environment also contains dedicated drivers, monitors, a scoreboard, and FIFO assertions.

## 4. Verification Strategy

The verification strategy combines directed simulation scenarios, scoreboard-based checking, assertion monitoring, and functional coverage.

### 4.1 Directed Testing

Directed tests exercise specific design behaviors, including:

- Normal packet transfers.
- Emergency packet priority.
- Normal-channel fairness.
- Simultaneous channel activity.
- FIFO full and empty conditions.
- Output backpressure.
- Reset during active traffic.

### 4.2 Scoreboard-Based Checking

The reference scoreboard tracks expected and observed packet transfers.

The regression reports:

- Packets accepted.
- Packets received.
- Pending packets.
- Scoreboard errors.
- Backpressure errors.

The scoreboard is used to detect unexpected packet behavior in the tested scenarios.

### 4.3 Assertion-Based Verification

SystemVerilog assertions check important protocol and design behaviors.

The reported checks include:

- Output stability.
- Valid packet known.
- Buffer status.
- Valid held during stall.
- Invalid output zero.
- Vibration producer behavior.
- Temperature producer behavior.
- Emergency producer behavior.

### 4.4 Functional Coverage

Functional coverage tracks whether the defined verification scenarios and combinations have been exercised.

The coverage model includes channel, packet type, channel/type combinations, backpressure, FIFO state, scheduler grants, contention, normal round robin, emergency burst, grant lock, and scheduler idle.

## 5. Test Scenario Matrix

| Test Area | Verification Objective |
|---|---|
| Packet format | Verify all 12 valid channel/type combinations |
| Normal transfers | Check packet acceptance and delivery |
| Emergency priority | Check emergency scheduling behavior |
| Normal fairness | Check vibration/temperature round-robin service |
| Channel contention | Exercise simultaneous requests |
| FIFO full | Exercise full-buffer behavior |
| FIFO empty | Exercise empty-buffer behavior |
| Backpressure | Check output behavior when receiver is not ready |
| Producer stalls | Check input behavior when buffering is constrained |
| Grant locking | Check that active packet transmission is not interrupted |
| Reset recovery | Exercise reset during traffic and output backpressure |
| Coverage closure | Check that defined functional coverage bins are hit |

## 6. Important Protocol Checks

### Ready/Valid Transfer

A transfer is considered complete when:

```systemverilog
out_valid && out_ready
```

### Output Stability

When output valid is asserted and the receiver is not ready, the output packet must remain stable until the transfer completes, subject to reset behavior.

### Scheduler Grant Locking

Once an output packet begins transmission, the selected source must remain active until that packet completes.

### Normal Channel Fairness

When both normal channels have pending traffic, the scheduler should provide round-robin service according to the implemented policy.

### Emergency Burst Policy

The scheduler supports up to two consecutive emergency packets while normal traffic is waiting, followed by normal-channel service according to the arbitration policy.

## 7. Regression Results

The successful integration regression reported:

| Metric | Result |
|---|---:|
| Integration regression | ALL TESTS PASSED |
| Scoreboard errors in reported integration tests | 0 |
| Pending packets in reported integration tests | 0 |
| SVA failure counters | 0 |
| Defined functional coverage | 100.00% |

See [`results/telemetry_regression/telemetry_regression.log`](../results/telemetry_regression/telemetry_regression.log) for the actual simulator transcript.

See [`results.md`](results.md) for the detailed results.

## 8. Verification Limitations

The reported results represent simulation-based verification of the implemented test scenarios.

The reported 100% functional coverage refers only to the defined functional coverage model.

The current results do not claim:

- 100% RTL code coverage.
- Exhaustive verification of all possible input sequences.
- Formal verification.
- Physical CDC signoff.
- Silicon validation.

## 9. Future Verification Improvements

Potential extensions include:

- Additional constrained-random traffic generation.
- More extensive reset sequencing.
- Expanded packet ordering and latency checks.
- Formal property checking.
- RTL code coverage analysis.
- Additional CDC analysis and signoff-oriented checks.
- Regression automation and coverage trend tracking.