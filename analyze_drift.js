#!/usr/bin/env node
/**
 * Drift Log Analyzer for berrry-joyful
 *
 * Analyzes Joy-Con stick drift patterns from CSV log files to identify:
 * - Constant offset drift
 * - Random noise/jitter
 * - Gradual drift progression
 * - Directional bias
 * - Temporal patterns
 *
 * Usage:
 *   node analyze_drift.js <log_file.csv>
 *   node analyze_drift.js ~/Documents/DriftLogs/drift_log_*.csv
 */

const fs = require('fs');
const path = require('path');

class DriftSample {
    constructor(row) {
        this.timestamp = parseFloat(row.timestamp);
        this.sessionTime = parseFloat(row.session_time);
        this.sampleCount = parseInt(row.sample_count);
        this.controllerId = row.controller_id;
        this.stickX = parseFloat(row.stick_x);
        this.stickY = parseFloat(row.stick_y);
        this.neutralX = parseFloat(row.neutral_x);
        this.neutralY = parseFloat(row.neutral_y);
        this.deviationX = parseFloat(row.deviation_x);
        this.deviationY = parseFloat(row.deviation_y);
        this.deviationMagnitude = parseFloat(row.deviation_magnitude);
        this.isIdle = parseInt(row.is_idle) === 1;
        this.buttonsPressed = parseInt(row.buttons_pressed);
        this.velocityX = parseFloat(row.velocity_x);
        this.velocityY = parseFloat(row.velocity_y);
        this.mode = row.mode;
    }
}

class DriftAnalysis {
    constructor(data) {
        Object.assign(this, data);
    }
}

/**
 * Parse CSV file into array of objects
 */
function parseCSV(filePath) {
    const content = fs.readFileSync(filePath, 'utf-8');
    const lines = content.trim().split('\n');

    if (lines.length < 2) {
        throw new Error('CSV file is empty or invalid');
    }

    const headers = lines[0].split(',');
    const samples = [];

    for (let i = 1; i < lines.length; i++) {
        const values = lines[i].split(',');
        if (values.length !== headers.length) {
            console.warn(`Warning: Skipping malformed row ${i}`);
            continue;
        }

        const row = {};
        headers.forEach((header, index) => {
            row[header] = values[index];
        });

        try {
            samples.push(new DriftSample(row));
        } catch (e) {
            console.warn(`Warning: Skipping invalid row ${i}: ${e.message}`);
        }
    }

    return samples;
}

/**
 * Calculate mean of array
 */
function mean(arr) {
    if (arr.length === 0) return 0;
    return arr.reduce((sum, val) => sum + val, 0) / arr.length;
}

/**
 * Calculate standard deviation
 */
function stdDev(arr) {
    if (arr.length < 2) return 0;
    const avg = mean(arr);
    const squareDiffs = arr.map(val => Math.pow(val - avg, 2));
    return Math.sqrt(mean(squareDiffs));
}

/**
 * Detect if drift is gradually increasing over time
 */
function detectGradualDrift(idleSamples) {
    if (idleSamples.length < 20) return false;

    const mid = Math.floor(idleSamples.length / 2);
    const firstHalf = idleSamples.slice(0, mid);
    const secondHalf = idleSamples.slice(mid);

    const firstMean = mean(firstHalf.map(s => s.deviationMagnitude));
    const secondMean = mean(secondHalf.map(s => s.deviationMagnitude));

    return secondMean > firstMean * 1.5 && (secondMean - firstMean) > 0.02;
}

/**
 * Detect if drift has a strong directional component
 */
function detectDirectionalBias(idleSamples) {
    if (idleSamples.length < 10) return false;

    const xValues = idleSamples.map(s => s.stickX);
    const yValues = idleSamples.map(s => s.stickY);

    const meanX = mean(xValues);
    const meanY = mean(yValues);

    if (Math.abs(meanX) < 0.01 && Math.abs(meanY) < 0.01) {
        return false;
    }

    const magnitude = Math.sqrt(meanX ** 2 + meanY ** 2);
    if (magnitude === 0) return false;

    const xRatio = Math.abs(meanX) / magnitude;
    const yRatio = Math.abs(meanY) / magnitude;

    // One axis dominates (>80% of drift in one direction)
    return Math.max(xRatio, yRatio) > 0.8;
}

/**
 * Analyze drift samples and return comprehensive analysis
 */
function analyzeDrift(samples, currentDeadzone = 0.1) {
    if (samples.length === 0) {
        throw new Error('No samples to analyze');
    }

    // Separate idle and active samples
    const idleSamples = samples.filter(s => s.isIdle);
    const activeSamples = samples.filter(s => !s.isIdle);

    const totalSamples = samples.length;
    const sessionDuration = samples[samples.length - 1].sessionTime;

    // Calculate idle statistics (RAW values)
    let idleMeanX = 0, idleMeanY = 0, idleStdX = 0, idleStdY = 0, idleMaxDeviation = 0;
    let effectiveIdleSamples = 0;  // Samples that exceed deadzone

    if (idleSamples.length > 0) {
        const idleXValues = idleSamples.map(s => s.stickX);
        const idleYValues = idleSamples.map(s => s.stickY);

        idleMeanX = mean(idleXValues);
        idleMeanY = mean(idleYValues);
        idleStdX = stdDev(idleXValues);
        idleStdY = stdDev(idleYValues);

        const idleDeviations = idleSamples.map(s => s.deviationMagnitude);
        idleMaxDeviation = Math.max(...idleDeviations);

        // Count how many idle samples EXCEED the deadzone (these cause actual drift)
        effectiveIdleSamples = idleSamples.filter(s => s.deviationMagnitude > currentDeadzone).length;
    }

    // Calculate EFFECTIVE drift (what actually moves the cursor)
    const effectiveDriftPercent = idleSamples.length > 0
        ? (effectiveIdleSamples / idleSamples.length) * 100
        : 0;

    // Detect drift types (considering deadzone)
    const rawOffsetMagnitude = Math.sqrt(idleMeanX ** 2 + idleMeanY ** 2);
    const hasConstantOffset = rawOffsetMagnitude > currentDeadzone;
    const hasRandomNoise = idleStdX > currentDeadzone * 0.5 || idleStdY > currentDeadzone * 0.5;
    const hasGradualDrift = detectGradualDrift(idleSamples);
    const hasDirectionalBias = detectDirectionalBias(idleSamples);

    // Calculate drift severity (0-10 scale) - based on EFFECTIVE drift
    let severity = 0;

    // Only penalize if drift exceeds current deadzone
    if (hasConstantOffset) {
        const excessOffset = rawOffsetMagnitude - currentDeadzone;
        severity += Math.min(excessOffset * 30, 4);  // Up to 4 points
    }
    if (hasRandomNoise) {
        const excessNoise = Math.max(idleStdX, idleStdY) - currentDeadzone;
        if (excessNoise > 0) {
            severity += Math.min(excessNoise * 50, 3);  // Up to 3 points
        }
    }
    if (hasGradualDrift && effectiveDriftPercent > 10) severity += 2;
    if (idleMaxDeviation > currentDeadzone * 1.5) severity += 1;

    // Bonus severity based on how often drift actually affects cursor
    if (effectiveDriftPercent > 25) severity += 1;
    if (effectiveDriftPercent > 50) severity += 1;

    const driftSeverity = Math.min(severity, 10);

    // Recommendations - only increase deadzone if needed
    let recommendedDeadzone = currentDeadzone;
    if (idleMaxDeviation > currentDeadzone) {
        recommendedDeadzone = Math.max(currentDeadzone, Math.min(idleMaxDeviation * 1.2, 0.3));
    }

    const needsCalibration = hasConstantOffset && !hasRandomNoise && driftSeverity < 5;
    const replacementRecommended = driftSeverity > 7 || effectiveDriftPercent > 75;

    return new DriftAnalysis({
        totalSamples,
        idleSamples: idleSamples.length,
        activeSamples: activeSamples.length,
        sessionDuration,
        idleMeanX,
        idleMeanY,
        idleStdX,
        idleStdY,
        idleMaxDeviation,
        currentDeadzone,
        effectiveIdleSamples,
        effectiveDriftPercent,
        rawOffsetMagnitude,
        hasConstantOffset,
        hasRandomNoise,
        hasGradualDrift,
        hasDirectionalBias,
        driftSeverity,
        recommendedDeadzone,
        needsCalibration,
        replacementRecommended
    });
}

/**
 * Print formatted analysis results
 */
function printAnalysis(analysis, controllerId = 'Unknown') {
    console.log('\n' + '='.repeat(70));
    console.log(`DRIFT ANALYSIS REPORT - ${controllerId}`);
    console.log('='.repeat(70));

    // Session info
    console.log(`\n📊 Session Information:`);
    console.log(`   Total samples: ${analysis.totalSamples.toLocaleString()}`);
    console.log(`   Idle samples: ${analysis.idleSamples.toLocaleString()} (${(analysis.idleSamples/analysis.totalSamples*100).toFixed(1)}%)`);
    console.log(`   Active samples: ${analysis.activeSamples.toLocaleString()} (${(analysis.activeSamples/analysis.totalSamples*100).toFixed(1)}%)`);
    console.log(`   Session duration: ${analysis.sessionDuration.toFixed(1)} seconds`);

    // Idle position statistics (RAW values)
    console.log(`\n🎯 Idle Position Statistics (Raw):`);
    console.log(`   Mean position: (${analysis.idleMeanX >= 0 ? '+' : ''}${analysis.idleMeanX.toFixed(6)}, ${analysis.idleMeanY >= 0 ? '+' : ''}${analysis.idleMeanY.toFixed(6)})`);
    console.log(`   Offset magnitude: ${analysis.rawOffsetMagnitude.toFixed(6)}`);
    console.log(`   Std deviation: (±${analysis.idleStdX.toFixed(6)}, ±${analysis.idleStdY.toFixed(6)})`);
    console.log(`   Max deviation: ${analysis.idleMaxDeviation.toFixed(6)}`);

    // EFFECTIVE drift (after deadzone)
    console.log(`\n⚙️  Effective Drift (After ${(analysis.currentDeadzone*100).toFixed(0)}% Deadzone):`);
    console.log(`   Current deadzone: ${analysis.currentDeadzone.toFixed(3)} (${(analysis.currentDeadzone*100).toFixed(0)}%)`);
    console.log(`   Idle samples causing drift: ${analysis.effectiveIdleSamples} / ${analysis.idleSamples} (${analysis.effectiveDriftPercent.toFixed(1)}%)`);

    if (analysis.effectiveDriftPercent === 0) {
        console.log(`   ✅ GOOD: Current deadzone fully suppresses drift!`);
    } else if (analysis.effectiveDriftPercent < 10) {
        console.log(`   🟡 ACCEPTABLE: Minor breakthrough drift`);
    } else if (analysis.effectiveDriftPercent < 50) {
        console.log(`   🟠 PROBLEMATIC: Frequent breakthrough drift`);
    } else {
        console.log(`   🔴 SEVERE: Deadzone insufficient for this drift`);
    }

    // Drift types detected
    console.log(`\n🔍 Drift Pattern Detection:`);
    console.log(`   Constant offset: ${analysis.hasConstantOffset ? '✅ YES' : '❌ NO'}`);
    if (analysis.hasConstantOffset) {
        console.log(`      → Offset: ${analysis.rawOffsetMagnitude.toFixed(4)} (deadzone: ${analysis.currentDeadzone.toFixed(3)})`);
        console.log(`      → Exceeds deadzone by: ${Math.max(0, analysis.rawOffsetMagnitude - analysis.currentDeadzone).toFixed(4)}`);
    }
    console.log(`   Random noise: ${analysis.hasRandomNoise ? '✅ YES' : '❌ NO'}`);
    if (analysis.hasRandomNoise) {
        console.log(`      → Noise level: ${((analysis.idleStdX + analysis.idleStdY)/2).toFixed(4)}`);
    }
    console.log(`   Gradual drift: ${analysis.hasGradualDrift ? '✅ YES' : '❌ NO'}`);
    console.log(`   Directional bias: ${analysis.hasDirectionalBias ? '✅ YES' : '❌ NO'}`);

    // Severity assessment
    console.log(`\n⚠️  Drift Severity: ${analysis.driftSeverity.toFixed(1)}/10`);
    let severityLabel, severityColor;
    if (analysis.driftSeverity < 3) {
        severityLabel = 'MINOR - Current deadzone handling it';
        severityColor = '🟢';
    } else if (analysis.driftSeverity < 5) {
        severityLabel = 'MODERATE - Adjustment recommended';
        severityColor = '🟡';
    } else if (analysis.driftSeverity < 7) {
        severityLabel = 'SIGNIFICANT - Deadzone insufficient';
        severityColor = '🟠';
    } else {
        severityLabel = 'SEVERE - Hardware replacement advised';
        severityColor = '🔴';
    }
    console.log(`   ${severityColor} ${severityLabel}`);

    // Recommendations
    console.log(`\n💡 Recommendations:`);

    const deadzoneChange = analysis.recommendedDeadzone - analysis.currentDeadzone;
    if (deadzoneChange > 0.001) {
        console.log(`   ⚙️  Increase deadzone: ${analysis.currentDeadzone.toFixed(3)} → ${analysis.recommendedDeadzone.toFixed(3)} (+${(deadzoneChange*100).toFixed(1)}%)`);
    } else {
        console.log(`   ✅ Current deadzone (${(analysis.currentDeadzone*100).toFixed(0)}%) is adequate`);
    }

    if (analysis.needsCalibration) {
        console.log(`   🎯 Calibration recommended - consistent offset detected`);
    }
    if (analysis.replacementRecommended) {
        console.log(`   ⚠️  Hardware replacement recommended - drift too severe`);
    }

    if (analysis.hasConstantOffset && !analysis.hasRandomNoise) {
        console.log(`   💡 Best strategy: Software calibration (offset is consistent)`);
    } else if (analysis.hasRandomNoise && !analysis.hasConstantOffset) {
        console.log(`   💡 Best strategy: Increase deadzone + smoothing filter`);
    } else if (analysis.hasConstantOffset && analysis.hasRandomNoise) {
        console.log(`   💡 Best strategy: Calibration + increased deadzone + filtering`);
    } else if (analysis.hasGradualDrift) {
        console.log(`   💡 Best strategy: Adaptive calibration (drift changes over time)`);
    }

    console.log('\n' + '='.repeat(70) + '\n');
}

/**
 * Main function
 */
function main() {
    const args = process.argv.slice(2);

    if (args.length === 0) {
        console.error('Usage: node analyze_drift.js <log_file.csv> [--deadzone 0.15]');
        console.error('Example: node analyze_drift.js ~/Documents/DriftLogs/drift_log_2025-01-01_12-00-00.csv');
        console.error('         node analyze_drift.js drift.csv --deadzone 0.15');
        process.exit(1);
    }

    // Parse arguments
    let logFilePath = null;
    let deadzone = 0.10;  // Default 10%

    for (let i = 0; i < args.length; i++) {
        if (args[i] === '--deadzone' && i + 1 < args.length) {
            deadzone = parseFloat(args[i + 1]);
            i++; // Skip next arg
        } else if (!logFilePath) {
            logFilePath = path.resolve(args[i]);
        }
    }

    if (!logFilePath || !fs.existsSync(logFilePath)) {
        console.error(`Error: Log file not found: ${logFilePath}`);
        process.exit(1);
    }

    console.log(`Reading log file: ${logFilePath}`);
    console.log(`Analyzing with deadzone: ${deadzone.toFixed(3)} (${(deadzone*100).toFixed(0)}%)`);

    const samples = parseCSV(logFilePath);

    if (samples.length === 0) {
        console.error('Error: No valid samples found in log file');
        process.exit(1);
    }

    console.log(`Loaded ${samples.length.toLocaleString()} samples`);

    // Group by controller ID
    const controllers = {};
    for (const sample of samples) {
        if (!controllers[sample.controllerId]) {
            controllers[sample.controllerId] = [];
        }
        controllers[sample.controllerId].push(sample);
    }

    // Analyze each controller separately
    for (const [controllerId, controllerSamples] of Object.entries(controllers)) {
        const analysis = analyzeDrift(controllerSamples, deadzone);
        printAnalysis(analysis, controllerId);
    }
}

// Run if called directly
if (require.main === module) {
    main();
}

module.exports = { analyzeDrift, parseCSV };
