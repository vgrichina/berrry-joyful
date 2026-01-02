# Joy-Con Drift Logging & Analysis

This guide explains how to use berrry-joyful's drift logging system to diagnose and characterize Joy-Con stick drift patterns.

## What is Stick Drift?

Stick drift occurs when your Joy-Con's analog stick registers movement even when it's at rest (neutral position). This can manifest as:

- **Constant offset**: The stick always reads slightly off-center in one direction
- **Random noise**: The stick position jumps around randomly when idle
- **Gradual drift**: Drift that gets worse over time during a session
- **Directional bias**: Drift that's stronger in one direction (e.g., always drifts up-left)

## How to Collect Drift Data

### 1. Start Drift Logging

Open berrry-joyful and go to **Debug → Start Drift Logging** from the menu bar.

The app will begin recording stick positions to CSV files in:
```
~/Documents/DriftLogs/
```

### 2. Use Your Controller Normally

To get accurate drift data:

- **Let the controller sit idle** for 10-15 seconds (hands off, on a flat surface)
- **Use it normally** for your typical workflows
- **Repeat idle periods** every few minutes
- **Run for at least 5-10 minutes** to capture temporal patterns

The idle periods are crucial - they let the system distinguish drift from intentional input.

### 3. Stop Logging

When done, go to **Debug → Stop Drift Logging**.

Your log files will be saved with timestamps:
```
drift_log_2025-01-01_14-30-00.csv
```

## Analyzing Your Drift Logs

### Quick Statistics

Go to **Debug → Show Drift Statistics** to see real-time drift metrics in the app.

This shows:
- Mean idle position (should be close to 0,0)
- Standard deviation (measures jitter/noise)
- Current neutral calibration

### Detailed Analysis

Use the included Node.js script to get a comprehensive drift analysis:

```bash
node analyze_drift.js ~/Documents/DriftLogs/drift_log_2025-01-01_14-30-00.csv
```

The script will output:

**📊 Session Information**
- Total samples collected
- Idle vs active samples
- Session duration

**🎯 Idle Position Statistics**
- Mean position (indicates constant offset)
- Standard deviation (indicates noise/jitter)
- Maximum deviation observed

**🔍 Drift Pattern Detection**
- ✅/❌ Constant offset detected
- ✅/❌ Random noise detected
- ✅/❌ Gradual drift detected
- ✅/❌ Directional bias detected

**⚠️ Drift Severity Rating (0-10)**
- 🟢 0-3: Minor - Normal operation
- 🟡 3-5: Moderate - Calibration recommended
- 🟠 5-7: Significant - Compensation required
- 🔴 7-10: Severe - Hardware replacement advised

**💡 Recommendations**
- Recommended deadzone setting
- Whether calibration would help
- Whether hardware replacement is needed
- Best compensation strategy

## What the Data Tells You

### Constant Offset Drift
```
Mean position: (+0.085000, -0.032000)
Constant offset: ✅ YES
Recommended strategy: Software calibration
```

**What it means**: Your stick's neutral position has shifted. This is the most common type of drift.

**Fix**: Software calibration works well - the app can adjust for a fixed offset.

### Random Noise Drift
```
Std deviation: (±0.045000, ±0.038000)
Random noise: ✅ YES
Recommended strategy: Increase deadzone and apply smoothing
```

**What it means**: Stick position is unstable and jittery, even when idle.

**Fix**: Increase deadzone to ignore small movements, and apply input smoothing filters.

### Gradual Drift
```
Gradual drift: ✅ YES
Recommended strategy: Adaptive calibration over time
```

**What it means**: Drift gets worse the longer you use the controller in one session.

**Fix**: Implement adaptive calibration that updates neutral position during idle periods.

### Directional Bias
```
Directional bias: ✅ YES
```

**What it means**: Drift is strongly biased in one direction (e.g., always drifts up).

**Fix**: Software compensation can work, but may indicate physical wear.

## CSV Log File Format

Each log contains these columns:

| Column | Description |
|--------|-------------|
| `timestamp` | Unix timestamp |
| `session_time` | Seconds since logging started |
| `sample_count` | Sample number |
| `controller_id` | Unique controller identifier |
| `stick_x`, `stick_y` | Raw stick position (-1 to +1) |
| `neutral_x`, `neutral_y` | Current calibrated neutral |
| `deviation_x`, `deviation_y` | Distance from neutral |
| `deviation_magnitude` | Total deviation distance |
| `is_idle` | 1 if no buttons pressed, 0 otherwise |
| `buttons_pressed` | Count of pressed buttons |
| `velocity_x`, `velocity_y` | Rate of position change |
| `mode` | Current control mode (unified, voice, precision) |

You can analyze these files with any CSV tool (Excel, Google Sheets, etc.) or write custom scripts.

## Using Results to Improve Compensation

Based on your analysis results, you can:

### 1. Adjust Deadzone
Go to **Mouse** tab → **Deadzone** slider

- Minor drift (severity < 3): Keep at 5-10%
- Moderate drift (severity 3-5): Increase to 15-20%
- Significant drift (severity 5-7): Increase to 20-30%

### 2. Calibration (Future Feature)
If you have constant offset drift, manual calibration can help:
- Place controller on flat surface
- Let it sit idle for 10 seconds
- System will learn the new neutral position

### 3. Replacement Decision
If severity > 7, software compensation may not be enough:
- Consider replacing the analog stick component
- Or replace the entire Joy-Con
- Nintendo offers repair services

## Tips for Best Results

**✅ DO:**
- Collect data from multiple sessions
- Include both idle and active periods
- Test different controller orientations
- Log for at least 5-10 minutes

**❌ DON'T:**
- Move the controller during "idle" periods
- Only log active gameplay (need idle samples)
- Analyze logs with < 100 samples
- Forget to stop logging when done

## Advanced: Custom Analysis

You can import the CSV files into your own analysis tools:

**Python (pandas):**
```python
import pandas as pd
df = pd.read_csv('drift_log.csv')
idle = df[df['is_idle'] == 1]
print(idle[['stick_x', 'stick_y']].describe())
```

**Excel/Google Sheets:**
- Import CSV
- Create scatter plot of `stick_x` vs `stick_y` for idle samples
- Calculate `AVERAGE()` and `STDEV()` for X and Y

**R:**
```r
data <- read.csv('drift_log.csv')
idle <- subset(data, is_idle == 1)
summary(idle[c('stick_x', 'stick_y')])
```

## Troubleshooting

**"Not enough idle samples"**
→ Let your controller sit untouched for longer periods

**"No drift detected" but I see cursor movement**
→ Increase logging duration - some drift is intermittent

**Multiple controllers in one log**
→ The script analyzes each controller separately

**Logs taking too much space**
→ Each 10-minute session is ~500KB-2MB. Delete old logs when done.

## Future Enhancements

Planned features for drift compensation:

- [ ] Automatic calibration during idle periods
- [ ] Adaptive deadzone based on detected drift
- [ ] Input smoothing filters (Kalman, low-pass)
- [ ] Per-controller drift profiles
- [ ] Drift prediction and pre-compensation
- [ ] Real-time drift visualization overlay

## Questions?

Check the [main README](README.md) or open an issue on GitHub.
