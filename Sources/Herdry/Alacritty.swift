import Foundation

let alacrittyPath = "/Applications/Alacritty.app/Contents/MacOS/alacritty"

private struct AlacrittyCommandResult {
    let status: Int32
    let stdout: String
    let stderr: String
}

func attachToSession(_ session: HerdrSession) {
    if let socket = findAlacrittySocket() {
        attachUsingExistingAlacritty(session, socket: socket)
    } else {
        attachUsingNewAlacritty(session)
    }
}

func findAlacrittySocket() -> String? {
    let process = Process()
    let output = Pipe()

    process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
    process.arguments = ["-n", "-U", "-c", "alacritty"]
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
        process.waitUntilExit()

        let data = output.fileHandleForReading.readDataToEndOfFile()

        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        return text
                .split(separator: "\n")
                .compactMap { line -> String? in
            guard let path = line.split(separator: " ").last else {
                return nil
            }

            let value = String(path)

            guard value.contains("Alacritty-"),
                  value.hasSuffix(".sock")
            else {
                return nil
            }

            return value
        }
                .first

    } catch {
        return nil
    }
}

func attachUsingNewAlacritty(_ session: HerdrSession) {
    let process = Process()

    process.executableURL = URL(
        fileURLWithPath: alacrittyPath
    )

    process.arguments = [
        "-e",
        herdrPath,
        "session",
        "attach",
        session.name
    ]

    var environment = ProcessInfo.processInfo.environment
    environment.removeValue(forKey: "HERDR_ENV")
    process.environment = environment

    process.standardError = FileHandle.standardError

    do {
        try process.run()
    } catch {
        print("Failed to launch Alacritty for \(session.name):", error)
    }
}

func attachUsingExistingAlacritty(
    _ session: HerdrSession,
    socket: String
) {
    do {
        let findArguments = [
            "msg",
            "--socket",
            socket,
            "find-window",
            "--title",
            session.name
        ]
        let findResult = try runAlacrittyCommand(findArguments)

        if findResult.status == 0 {
            let windowIDText = findResult.stdout.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            guard let windowID = UInt64(windowIDText) else {
                print(
                    "Failed to attach using existing Alacritty: invalid window ID;",
                    "status: \(findResult.status);",
                    "stdout: \(String(reflecting: findResult.stdout));",
                    "stderr: \(String(reflecting: findResult.stderr))"
                )
                return
            }

            let focusArguments = [
                "msg",
                "--socket",
                socket,
                "focus-window",
                "--window-id",
                String(windowID)
            ]
            let focusResult = try runAlacrittyCommand(focusArguments)

            guard focusResult.status == 0 else {
                logAlacrittyFailure(focusArguments, result: focusResult)
                return
            }

            return
        }

        guard isWindowNotFound(findResult) else {
            logAlacrittyFailure(findArguments, result: findResult)
            return
        }

        let createArguments = [
            "msg",
            "--socket",
            socket,
            "create-window",
            "--title",
            session.name,
            "-e",
            herdrPath,
            "session",
            "attach",
            session.name
        ]
        let createResult = try runAlacrittyCommand(createArguments)

        if createResult.status != 0 {
            logAlacrittyFailure(createArguments, result: createResult)
        }
    } catch {
        print("Failed to attach using existing Alacritty:", error)
    }
}

private func isWindowNotFound(_ result: AlacrittyCommandResult) -> Bool {
    let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)

    return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (stderr.hasPrefix("Error: no window found with title ")
                    || stderr.hasPrefix(
                        "Error: Custom { kind: Other, error: \"no window found with title "
                    ))
}

private func logAlacrittyFailure(
    _ arguments: [String],
    result: AlacrittyCommandResult
) {
    print(
        "Failed to attach using existing Alacritty:",
        "alacritty \(arguments.joined(separator: " ")) exited with status \(result.status);",
        "stdout: \(String(reflecting: result.stdout));",
        "stderr: \(String(reflecting: result.stderr))"
    )
}

private func runAlacrittyCommand(
    _ arguments: [String]
) throws -> AlacrittyCommandResult {
    let process = Process()
    let output = Pipe()
    let error = Pipe()

    process.executableURL = URL(
        fileURLWithPath: alacrittyPath
    )
    process.arguments = arguments
    process.standardOutput = output
    process.standardError = error

    try process.run()

    let stdout = output.fileHandleForReading.readDataToEndOfFile()
    let stderr = error.fileHandleForReading.readDataToEndOfFile()

    process.waitUntilExit()

    return AlacrittyCommandResult(
        status: process.terminationStatus,
        stdout: String(decoding: stdout, as: UTF8.self),
        stderr: String(decoding: stderr, as: UTF8.self)
    )
}
