import Cocoa
import os.log
import Foundation

// Global logger for the app
let appLogger = OSLog(subsystem: "app.berrry.joyful", category: "app")

// Redirect stdout and stderr to os_log
func redirectStdToOSLog() {
    // Create pipes for stdout and stderr
    var stdoutPipe = [Int32](repeating: 0, count: 2)
    var stderrPipe = [Int32](repeating: 0, count: 2)

    pipe(&stdoutPipe)
    pipe(&stderrPipe)

    // Redirect stdout and stderr to the pipes
    dup2(stdoutPipe[1], STDOUT_FILENO)
    dup2(stderrPipe[1], STDERR_FILENO)

    // Close write ends (we only need read ends)
    close(stdoutPipe[1])
    close(stderrPipe[1])

    // Read from stdout pipe in background
    DispatchQueue.global(qos: .background).async {
        let readHandle = FileHandle(fileDescriptor: stdoutPipe[0], closeOnDealloc: false)
        while true {
            let data = readHandle.availableData
            if data.count > 0, let string = String(data: data, encoding: .utf8) {
                os_log("%{public}@", log: appLogger, type: .default, string.trimmingCharacters(in: .newlines))
            }
        }
    }

    // Read from stderr pipe in background
    DispatchQueue.global(qos: .background).async {
        let readHandle = FileHandle(fileDescriptor: stderrPipe[0], closeOnDealloc: false)
        while true {
            let data = readHandle.availableData
            if data.count > 0, let string = String(data: data, encoding: .utf8) {
                os_log("%{public}@", log: appLogger, type: .error, string.trimmingCharacters(in: .newlines))
            }
        }
    }
}

redirectStdToOSLog()

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
