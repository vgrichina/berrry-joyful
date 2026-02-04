# Joy-Con Initialization Timing Research Report

**Date:** 2026-02-04
**Issue:** Joy-Con controllers timeout during initialization (getSPIFlash subcommand) when two controllers connect simultaneously

---

## TL;DR

**Problem:** Two Joy-Cons connecting simultaneously = race condition = timeouts

**Solution:** Initialize one at a time + 25ms between commands

```
CURRENT (broken):                       FIXED (sequential queue):
═══════════════════                     ═════════════════════════

    JoyConManager                           JoyConManager
          │                                       │
    ┌─────┴─────┐                           ┌─────┴─────┐
    ▼           ▼                           ▼           │
 init(L)    init(R)                      init(L)       │
    │           │                           │          │
    ├─► SPI ◄───┤  ← COLLISION!             ▼          │
    │           │                        success       │
    ▼           ▼                           │          ▼
 success    TIMEOUT                         └───► init(R)
                                                    │
                                                    ▼
                                                 success
```

**Key Changes:**
1. **Sequential init queue** - only init one controller at a time
2. **25ms rate limit** - minimum gap between subcommands (Linux driver does this)
3. **Send 0x08 0x00 first** - Nintendo Switch always sends this after connect
4. **Reduce retries** - 2 total attempts instead of 4 (matches Linux driver)

**Timing Comparison:**
```
                    Linux Driver    Us (Current)    Recommended
                    ────────────    ────────────    ───────────
Pre-init delay         -              250ms           250ms
Between subcmds       25ms             0ms            25ms
Timeout             250-1000ms       3000ms          1000ms
Retries              1 (2 total)    3 (4 total)    1 (2 total)
```

---

## Problem Summary

When two Joy-Con controllers connect close together in time, whichever controller initializes second frequently experiences timeouts on the `getSPIFlash` subcommand. The issue is not specific to Left or Right Joy-Con - it affects whichever controller happens to initialize second.

### Observed Behavior

```
22:47:26 - Joy-Con (L) connected, waited 250ms, init succeeded in ~65ms
22:47:30 - Joy-Con (R) connected, waited 250ms, getSPIFlash TIMEOUT (3 retries)
22:47:41 - Joy-Con (R) disconnected during retry
22:47:48 - Joy-Con (R) reconnected, timeout on first attempt, succeeded on retry
```

### Current Mitigations (Partial Success)

1. 250ms delay after device match before sending subcommands
2. Retry logic (3 retries with 3-second timeout each)
3. 11-second fallback timer that proceeds with default values if init fails

## Research Findings

### 1. Linux hid-nintendo Kernel Driver

The Linux kernel driver for Nintendo controllers implements several reliability mechanisms:

#### Wait for Input Report Before Subcommands

```c
static void joycon_wait_for_input_report(struct joycon_ctlr *ctlr)
{
    if (ctlr->ctlr_state == JOYCON_CTLR_STATE_READ) {
        ctlr->received_input_report = false;
        ret = wait_event_timeout(ctlr->wait,
                     ctlr->received_input_report,
                     HZ / 4);  // 250ms timeout
        if (!ret)
            hid_warn(ctlr->hdev, "timeout waiting for input report\n");
    }
}
```

The comment in the source states this **"improves reliability considerably"**.

#### 25ms Rate Limiting Between Subcommands

```c
static void joycon_enforce_subcmd_rate(struct joycon_ctlr *ctlr)
{
    static const unsigned int max_subcmd_rate_ms = 25;
    unsigned int delta_ms = current_ms - ctlr->last_subcmd_sent_msecs;

    while (delta_ms < max_subcmd_rate_ms) {
        joycon_wait_for_input_report(ctlr);
        // recalculate delta_ms
    }
}
```

The comment explains: **"Sending subcommands and/or rumble data at too high a rate can cause bluetooth controller disconnections."**

#### Per-Controller Mutex Serialization

Each controller has its own `output_mutex` that serializes all output operations:

```c
struct joycon_ctlr {
    struct mutex output_mutex;  // Serializes output operations
    // ...
};
```

#### Retry Logic

The driver uses 2 total attempts (1 original + 1 retry):

```c
static int joycon_hid_send_sync(...)
{
    int tries = 2;
    while (tries--) {
        // send and wait for response
    }
}
```

The comment notes: **"The controller occasionally seems to drop subcommands. In testing, doing one retry after a timeout appears to always work."**

### 2. Nintendo Switch Reverse Engineering Documentation

#### Initialization Sequence

The Nintendo Switch firmware performs this sequence after Bluetooth connection:

1. **`0x08 0x00`** - Set shipment low power state (always sent first)
2. **`0x02`** - Request device info
3. **`0x10`** - Read SPI flash (calibration, colors)
4. **`0x03 0x30`** - Set standard full mode (60Hz reports)
5. **`0x40 0x01`** - Enable IMU
6. **`0x48 0x01`** - Enable vibration
7. **`0x30`** - Set player lights

**Key Finding:** Our implementation does NOT send `0x08 0x00` which the Switch always sends. This command "enables Triggered Broadcom Fast Connect and LPM mode to SLEEP."

#### SPI Flash Read Limitations

- Maximum read size: `0x1D` (29 bytes) per request
- Address format: Little-endian int32
- Response: `0x9010` ACK, echoes request, followed by data

### 3. HID-Joy-Con-Whispering Reference Implementation

The reference C++ implementation uses:

- **Response validation loops** (up to 2000 iterations) checking buffer contents
- **No hardcoded delays** - relies on response checking instead
- **Non-blocking mode** for dual controller handling with polling loops

### 4. macOS-Specific Issues

Community reports indicate that connecting a second Joy-Con on macOS can cause both controllers to stop working properly. This appears to be a known issue with the macOS Bluetooth stack handling multiple Switch controllers.

## Root Cause Analysis

The primary issue is a **race condition** where two controllers attempt to initialize concurrently:

1. Controller A connects, starts initialization (sends subcommands)
2. Controller B connects, starts initialization (sends subcommands)
3. Both controllers sending commands simultaneously overwhelms the Bluetooth HID channel
4. Commands get dropped or responses get misrouted
5. Timeouts occur on whichever controller is "losing" the race

## Recommended Solutions

### Priority 1: Sequential Initialization Queue (Critical)

Implement a queue in `JoyConManager` to ensure only one controller initializes at a time:

```
Device A matched → Add to queue → Start init
Device B matched → Add to queue → Wait
Device A init complete → Start Device B init
Device B init complete → Queue empty
```

### Priority 2: Subcommand Rate Limiting

Add 25ms minimum delay between subcommands to prevent Bluetooth disconnections:

```swift
let timeSinceLast = Date().timeIntervalSince(lastSubcommandTimestamp)
let minInterval = 0.025 // 25ms
if timeSinceLast < minInterval {
    // delay before sending
}
```

### Priority 3: Send 0x08 0x00 at Init Start

Add the shipment mode command that Nintendo always sends:

```swift
// At start of readInitializeData()
sendSubcommand(type: .setShipmentLowPowerState, data: [0x00])
```

### Priority 4: Reduce Retry Count

Change from 3 retries to 1 retry (2 total attempts) to match Linux driver behavior and fail faster when controller is truly unresponsive.

## Implementation Checklist

- [ ] Add `initQueue` and `isInitializing` properties to JoyConManager
- [ ] Modify `handleMatch()` to queue devices instead of immediate init
- [ ] Add `processInitQueue()` function for sequential processing
- [ ] Add `lastSubcommandTimestamp` to Controller for rate limiting
- [ ] Implement 25ms rate limiting in `processSubcommand()`
- [ ] Add `setShipmentLowPowerState` (0x08) subcommand type
- [ ] Send 0x08 0x00 at start of initialization
- [ ] Reduce `Subcommand.maxRetries` from 3 to 1
- [ ] Clean up queue on device removal in `handleRemove()`

## References

### Primary Sources

1. **Linux hid-nintendo kernel driver**
   - Repository: https://github.com/nicman23/dkms-hid-nintendo
   - Source file: `src/hid-nintendo.c`
   - Key functions: `joycon_wait_for_input_report()`, `joycon_enforce_subcmd_rate()`, `joycon_hid_send_sync()`

2. **Nintendo Switch Reverse Engineering**
   - Repository: https://github.com/dekuNukem/Nintendo_Switch_Reverse_Engineering
   - Bluetooth HID Subcommands: `bluetooth_hid_subcommands_notes.md`
   - Bluetooth HID Notes: `bluetooth_hid_notes.md`

3. **HID-Joy-Con-Whispering**
   - Repository: https://github.com/shinyquagsire23/HID-Joy-Con-Whispering
   - Reference implementation: `hidtest/hidtest.cpp`

### Secondary Sources

4. **JoyConSwift (Original Library)**
   - Repository: https://github.com/magicien/JoyConSwift
   - Our vendored copy with fixes: `Sources/JoyConSwift/`

5. **JoyCon.NET**
   - NuGet: https://www.nuget.org/packages/JoyCon.NET/1.0.0
   - Documentation: https://clusterm.github.io/joycon/

6. **Joy-Con HID Reverse Engineering Discussion**
   - GBAtemp thread: https://gbatemp.net/threads/joy-con-hid-reverse-engineering.467290/

7. **Blog: Picking Apart the Joy-Con**
   - Pro Controllers and Extended HID: https://douevenknow.us/post/160976568023/picking-apart-the-joy-con-pro-controllers
   - Charging Grip and HID: https://douevenknow.us/post/159446741358/picking-apart-the-joy-con-charging-joy-con-grip

### macOS-Specific

8. **Apple Community Discussion**
   - Multiple Joy-Con issues: https://discussions.apple.com/thread/253659152

9. **QJoyControl (macOS Qt implementation)**
   - Repository: https://github.com/erikmwerner/QJoyControl

## Appendix: Key Timing Values

| Parameter | Linux Driver | Our Current | Recommended |
|-----------|--------------|-------------|-------------|
| Pre-init delay | N/A | 250ms | 250ms |
| Input report wait | 250ms | None | 250ms (optional) |
| Min between subcommands | 25ms | None | 25ms |
| Subcommand timeout | 250ms-1000ms | 3000ms | 1000ms |
| Max retries | 1 | 3 | 1 |
| Fallback timer | N/A | 11000ms | 11000ms |
