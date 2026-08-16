import Foundation

let herdrPath = "/opt/homebrew/bin/herdr"

private struct AgentQueryResult: Sendable {
    let index: Int
    let blockedCount: Int?
    let errorDescription: String?
}

private enum HerdrCLIError: Error, CustomStringConvertible, Sendable {
    case unsuccessfulExit(arguments: [String], status: Int32)

    var description: String {
        switch self {
        case let .unsuccessfulExit(arguments, status):
            "herdr \(arguments.joined(separator: " ")) exited with status \(status)"
        }
    }
}

func loadSessionSnapshots(
    previousBlockedCounts: [String: Int]
) async throws -> [SessionSnapshot] {
    let sessionData = try await runHerdr([
        "session",
        "list",
        "--json"
    ])
    let sessions = try JSONDecoder()
        .decode(SessionList.self, from: sessionData)
        .sessions

    var blockedCountsByIndex: [Int: Int] = [:]

    try await withThrowingTaskGroup(of: AgentQueryResult.self) { group in
        for (index, session) in sessions.enumerated() where session.running {
            group.addTask {
                do {
                    return AgentQueryResult(
                        index: index,
                        blockedCount: try await loadBlockedCount(
                            for: session.name
                        ),
                        errorDescription: nil
                    )
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    return AgentQueryResult(
                        index: index,
                        blockedCount: nil,
                        errorDescription: String(describing: error)
                    )
                }
            }
        }

        for try await result in group {
            if let blockedCount = result.blockedCount {
                blockedCountsByIndex[result.index] = blockedCount
            } else if let errorDescription = result.errorDescription {
                print(
                    "Failed to load agents for \(sessions[result.index].name):",
                    errorDescription
                )
            }
        }
    }

    return sessions.enumerated().map { index, session in
        let blockedCount: Int?

        if session.running {
            blockedCount = blockedCountsByIndex[index]
                ?? previousBlockedCounts[session.id]
        } else {
            blockedCount = 0
        }

        return SessionSnapshot(
            session: session,
            blockedCount: blockedCount
        )
    }
}

private func loadBlockedCount(for sessionName: String) async throws -> Int {
    let data = try await runHerdr([
        "--session",
        sessionName,
        "agent",
        "list"
    ])
    let agents = try JSONDecoder()
        .decode(AgentListResponse.self, from: data)
        .result
        .agents

    return agents.count { $0.agentStatus == "blocked" }
}

private func runHerdr(_ arguments: [String]) async throws -> Data {
    let task = Task.detached(priority: .utility) {
        try Task.checkCancellation()

        let process = Process()
        let output = Pipe()

        process.executableURL = URL(fileURLWithPath: herdrPath)
        process.arguments = arguments

        process.standardOutput = output
        process.standardError = FileHandle.standardError

        try process.run()

        let data = output.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()
        try Task.checkCancellation()

        guard process.terminationStatus == 0 else {
            throw HerdrCLIError.unsuccessfulExit(
                arguments: arguments,
                status: process.terminationStatus
            )
        }

        return data
    }

    return try await withTaskCancellationHandler {
        try await task.value
    } onCancel: {
        task.cancel()
    }
}
