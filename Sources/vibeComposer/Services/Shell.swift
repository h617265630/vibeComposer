import Foundation

struct ShellResult {
    let output: String
    let error: String
    let status: Int32

    var succeeded: Bool { status == 0 }
}

enum Shell {
    static func run(_ arguments: [String], currentDirectory: URL? = nil) -> ShellResult {
        guard let executable = arguments.first else {
            return ShellResult(output: "", error: "No command", status: 127)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(arguments.dropFirst())
        if let currentDirectory {
            process.currentDirectoryURL = currentDirectory
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ShellResult(output: "", error: String(describing: error), status: 127)
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ShellResult(output: output, error: error, status: process.terminationStatus)
    }
}
