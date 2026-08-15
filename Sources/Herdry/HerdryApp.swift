import AppKit
import Foundation
import SwiftUI

let herdrPath = "/opt/homebrew/bin/herdr"
let alacrittyPath = "/Applications/Alacritty.app/Contents/MacOS/alacritty"

struct SessionList: Decodable {
    let sessions: [HerdrSession]
}

struct HerdrSession: Decodable, Identifiable {
    let name: String
    let running: Bool
    let `default`: Bool

    var id: String { name }
}

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [HerdrSession] = []

    init() {
        Task {
            while true {
                refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func refresh() {
        do {
            sessions = try loadSessions()
        } catch {
            print("Failed to load sessions:", error)
        }
    }
}

func loadSessions() throws -> [HerdrSession] {
    let process = Process()
    let output = Pipe()

    process.executableURL = URL(fileURLWithPath: herdrPath)
    process.arguments = [
        "session",
        "list",
        "--json"
    ]

    process.standardOutput = output
    process.standardError = FileHandle.standardError

    try process.run()

    let data = output.fileHandleForReading.readDataToEndOfFile()

    process.waitUntilExit()

    return try JSONDecoder()
    .decode(SessionList.self, from: data)
    .sessions
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

@main
struct HerdryApp: App {
    @StateObject private var store = SessionStore()

    var body: some Scene {
        let menuBarIcon: NSImage = {
            guard
            let url = Bundle.main.url(
                forResource: "herdr-menubar",
                withExtension: "png"
            ),
            let image = NSImage(contentsOf: url)
            else {
                fatalError("Missing herdr-menubar.png")
            }

            image.isTemplate = true
            image.size = NSSize(width: 21, height: 21)

            return image
        }()
        MenuBarExtra {
            ForEach(store.sessions) { session in
                Button {
                    attachToSession(session)
                } label: {
                    Label(
                        session.name,
                        systemImage: session.running
                                ? "circle.fill"
                                : "circle"
                    )
                }
                .disabled(!session.running)
            }

            Divider()

            Button("Quit Herdry") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Image(nsImage: menuBarIcon)
        }
    }
}
