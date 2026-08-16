import Foundation

let alacrittyPath = "/Applications/Alacritty.app/Contents/MacOS/alacritty"

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
    let process = Process()

    process.executableURL = URL(
        fileURLWithPath: alacrittyPath
    )

    process.arguments = [
        "msg",
        "--socket",
        socket,
        "create-window",
        "-T",
        session.name,
        "-e",
        herdrPath,
        "session",
        "attach",
        session.name
    ]

    process.standardError = FileHandle.standardError

    do {
        try process.run()
    } catch {
        print("Failed to attach using existing Alacritty:", error)
    }
}
