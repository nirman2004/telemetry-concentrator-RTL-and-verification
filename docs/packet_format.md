# Telemetry Packet Format

## 1. Overview

The telemetry concentrator uses a fixed-width **44-bit packet format** for all three input channels:

- Vibration
- Temperature
- Emergency

Each packet contains a channel identifier, packet type, sequence number, and 32-bit payload.

## 2. Packet Structure

<escape>
| Channel ID | Packet Type | Sequence Number | Payload |
|:---:|:---:|:---:|:---:|
| [43:42] | [41:40] | [39:32] | [31:0] |
| 2 bits | 2 bits | 8 bits | 32 bits |
</escape>

Total packet width:

\[
2 + 2 + 8 + 32 = 44 \text{ bits}
\]

## 3. Field Description

| Field | Bit Range | Width | Description |
|---|---|---:|---|
| Channel ID | `[43:42]` | 2 | Identifies the source channel |
| Packet Type | `[41:40]` | 2 | Identifies the packet category |
| Sequence Number | `[39:32]` | 8 | Identifies packet sequence |
| Payload | `[31:0]` | 32 | Carries telemetry data |

### 3.1 Channel ID

| Binary | Channel |
|---|---|
| `2'b00` | Vibration |
| `2'b01` | Temperature |
| `2'b10` | Emergency |
| `2'b11` | Reserved |

The channel identifier allows the receiving logic and verification environment to identify the packet source.

### 3.2 Packet Type

The packet type field is two bits wide and supports four encodings.

| Binary | Encoding |
|---|---|
| `2'b00` | Type 0 |
| `2'b01` | Type 1 |
| `2'b10` | Type 2 |
| `2'b11` | Type 3 |

These are encoding labels; their application-specific meanings depend on the packet-generation logic.

### 3.3 Sequence Number

The sequence number is an 8-bit field.

It can represent values from 0 to 255 and can be used by the verification environment to track packet identity and ordering.

### 3.4 Payload

The payload is 32 bits wide and carries the telemetry information associated with the packet.

## 4. Packet Packing

The packet fields are concatenated in the following order:

```systemverilog
packet = {
    channel_id,       // [43:42]
    packet_type,      // [41:40]
    sequence_number,  // [39:32]
    payload           // [31:0]
};
```

Example:

```systemverilog
logic [43:0] packet;

assign packet = {
    2'b00,       // Vibration
    2'b01,       // Packet Type 1
    8'h05,       // Sequence Number 5
    32'h12345678 // Payload
};
```

The example packet is:

```text
44'h0512345678
```

## 5. Channel and Packet-Type Combinations

There are three implemented channel IDs and four packet-type encodings.

\[
3 \times 4 = 12
\]

Therefore, the verification environment checks 12 valid channel/type combinations.

| Channel | Type 0 | Type 1 | Type 2 | Type 3 |
|---|---|---|---|---|
| Vibration | Valid | Valid | Valid | Valid |
| Temperature | Valid | Valid | Valid | Valid |
| Emergency | Valid | Valid | Valid | Valid |

The reserved channel ID `2'b11` is not included in these 12 valid combinations.

## 6. Verification Considerations

The packet-format verification checks include:

- Correct extraction of channel ID.
- Correct extraction of packet type.
- Sequence-number preservation.
- Payload integrity.
- Correct channel/type combinations.
- Packet integrity through buffering and scheduling.
- Correct packet association with the selected output channel.

The integration regression reported that all 12 channel/type combinations were verified.

## 7. Summary

The fixed-width packet format provides a common representation for all three telemetry channels. Its explicit source, type, sequence, and payload fields support packet identification, scheduling, and scoreboard-based verification.