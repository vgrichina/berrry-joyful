import Foundation

/// Logs controller stick input data for drift analysis
class DriftLogger {
    static let shared = DriftLogger()

    private var isLogging = false
    private var logFileHandle: FileHandle?
    private var sessionStartTime: Date?
    private var sampleCount: UInt64 = 0

    // Configuration
    private let logInterval: TimeInterval = 0.1 // Log every 100ms
    private var lastLogTime: Date = Date.distantPast

    // Drift detection state
    private var neutralCalibration: (x: Float, y: Float) = (0, 0)
    private var idleSamples: [(x: Float, y: Float)] = []
    private let idleSampleLimit = 100 // Keep last 100 idle samples for calibration

    // User drift marking
    private var isDriftMarked: Bool = false
    private var driftMarkExpiry: Date?

    private init() {}

    // MARK: - Logging Control

    func startLogging() {
        guard !isLogging else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())

        let logsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DriftLogs")

        // Create logs directory if needed
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        let logFile = logsDir.appendingPathComponent("drift_log_\(timestamp).csv")

        // Create log file with headers
        let headers = "timestamp,session_time,sample_count,controller_id,stick_x,stick_y,neutral_x,neutral_y,deviation_x,deviation_y,deviation_magnitude,is_idle,buttons_pressed,velocity_x,velocity_y,mode,user_marked_drift\n"

        FileManager.default.createFile(atPath: logFile.path, contents: headers.data(using: .utf8))
        logFileHandle = try? FileHandle(forWritingTo: logFile)
        logFileHandle?.seekToEndOfFile()

        sessionStartTime = Date()
        sampleCount = 0
        isLogging = true

        print("📊 Drift logging started: \(logFile.path)")
    }

    func stopLogging() {
        guard isLogging else { return }

        logFileHandle?.closeFile()
        logFileHandle = nil
        isLogging = false
        sessionStartTime = nil
        sampleCount = 0

        print("📊 Drift logging stopped. Total samples: \(sampleCount)")
    }

    var loggingEnabled: Bool {
        get { isLogging }
        set {
            if newValue {
                startLogging()
            } else {
                stopLogging()
            }
        }
    }

    // MARK: - Data Logging

    struct StickSample {
        let x: Float
        let y: Float
        let controllerId: String
        let isIdle: Bool  // No buttons pressed, stick should be neutral
        let buttonsPressed: Int  // Count of pressed buttons
        let currentMode: String
        let previousSample: (x: Float, y: Float)?  // For velocity calculation
        let userMarkedDrift: Bool  // User manually flagged drift at this moment
    }

    func logSample(_ sample: StickSample) {
        guard isLogging else { return }

        // Rate limiting
        let now = Date()
        guard now.timeIntervalSince(lastLogTime) >= logInterval else { return }
        lastLogTime = now

        // Update neutral calibration with idle samples
        if sample.isIdle {
            idleSamples.append((sample.x, sample.y))
            if idleSamples.count > idleSampleLimit {
                idleSamples.removeFirst()
            }

            // Recalculate neutral as median of idle samples
            if idleSamples.count > 10 {
                let sortedX = idleSamples.map { $0.x }.sorted()
                let sortedY = idleSamples.map { $0.y }.sorted()
                neutralCalibration.x = sortedX[sortedX.count / 2]
                neutralCalibration.y = sortedY[sortedY.count / 2]
            }
        }

        // Calculate deviations
        let deviationX = sample.x - neutralCalibration.x
        let deviationY = sample.y - neutralCalibration.y
        let magnitude = sqrt(deviationX * deviationX + deviationY * deviationY)

        // Calculate velocity
        var velocityX: Float = 0
        var velocityY: Float = 0
        if let prev = sample.previousSample {
            velocityX = (sample.x - prev.x) / Float(logInterval)
            velocityY = (sample.y - prev.y) / Float(logInterval)
        }

        guard let startTime = sessionStartTime else { return }
        let sessionTime = now.timeIntervalSince(startTime)
        sampleCount += 1

        // Check if drift marking has expired (5 seconds after marking)
        if let expiry = driftMarkExpiry, now > expiry {
            isDriftMarked = false
            driftMarkExpiry = nil
        }

        // Format: timestamp,session_time,sample_count,controller_id,stick_x,stick_y,neutral_x,neutral_y,deviation_x,deviation_y,deviation_magnitude,is_idle,buttons_pressed,velocity_x,velocity_y,mode,user_marked_drift
        let logLine = String(format: "%.3f,%.3f,%llu,%@,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%d,%.6f,%.6f,%@,%d\n",
                            now.timeIntervalSince1970,
                            sessionTime,
                            sampleCount,
                            sample.controllerId,
                            sample.x,
                            sample.y,
                            neutralCalibration.x,
                            neutralCalibration.y,
                            deviationX,
                            deviationY,
                            magnitude,
                            sample.isIdle ? 1 : 0,
                            sample.buttonsPressed,
                            velocityX,
                            velocityY,
                            sample.currentMode,
                            (sample.userMarkedDrift || isDriftMarked) ? 1 : 0)

        if let data = logLine.data(using: .utf8) {
            logFileHandle?.write(data)
        }
    }

    // MARK: - Drift Marking

    /// User manually marks that drift is occurring right now
    /// Marks the next 5 seconds of samples as user-flagged drift
    func markDriftNow() {
        isDriftMarked = true
        driftMarkExpiry = Date().addingTimeInterval(5.0)  // Mark for 5 seconds
        print("🚩 Drift marked by user - flagging next 5 seconds")
    }

    // MARK: - Analysis Helpers

    /// Get current neutral calibration
    func getCurrentNeutral() -> (x: Float, y: Float) {
        return neutralCalibration
    }

    /// Manually set neutral calibration
    func setNeutral(x: Float, y: Float) {
        neutralCalibration = (x, y)
        print("🎯 Neutral calibration set to: x=\(x), y=\(y)")
    }

    /// Reset neutral calibration to default (0, 0)
    func resetNeutral() {
        neutralCalibration = (0, 0)
        idleSamples.removeAll()
        print("🔄 Neutral calibration reset")
    }

    /// Get statistics on idle samples
    func getIdleStatistics() -> (mean: (x: Float, y: Float), stdDev: (x: Float, y: Float))? {
        guard idleSamples.count > 1 else { return nil }

        let meanX = idleSamples.map { $0.x }.reduce(0, +) / Float(idleSamples.count)
        let meanY = idleSamples.map { $0.y }.reduce(0, +) / Float(idleSamples.count)

        let varianceX = idleSamples.map { pow($0.x - meanX, 2) }.reduce(0, +) / Float(idleSamples.count)
        let varianceY = idleSamples.map { pow($0.y - meanY, 2) }.reduce(0, +) / Float(idleSamples.count)

        return (mean: (meanX, meanY), stdDev: (sqrt(varianceX), sqrt(varianceY)))
    }

    /// Print current drift statistics to console
    func printStatistics() {
        guard let stats = getIdleStatistics() else {
            print("📊 Not enough idle samples for statistics")
            return
        }

        print("📊 Drift Statistics:")
        print("   Idle samples: \(idleSamples.count)")
        print("   Mean position: x=\(String(format: "%.4f", stats.mean.x)), y=\(String(format: "%.4f", stats.mean.y))")
        print("   Std deviation: x=\(String(format: "%.4f", stats.stdDev.x)), y=\(String(format: "%.4f", stats.stdDev.y))")
        print("   Current neutral: x=\(String(format: "%.4f", neutralCalibration.x)), y=\(String(format: "%.4f", neutralCalibration.y))")
    }
}
