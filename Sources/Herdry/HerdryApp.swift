import SwiftUI
import Foundation

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

    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [
        "herdr",
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
    let process = Process()

    process.executableURL = URL(
        fileURLWithPath: "/Applications/Alacritty.app/Contents/MacOS/alacritty"
    )

    process.arguments = [
        "-e",
        "/opt/homebrew/bin/herdr",
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
        print("Failed to attach to \(session.name):", error)
    }
}

@main
struct HerdryApp: App {
    @StateObject private var store = SessionStore()

    var body: some Scene {
        MenuBarExtra("Herdry", systemImage: "circle") {
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
        }
    }
}
