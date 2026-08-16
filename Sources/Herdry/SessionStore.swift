import Combine
import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [SessionSnapshot] = []

    private var pollingTask: Task<Void, Never>?

    init() {
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                if let self {
                    await self.refresh()
                } else {
                    return
                }

                do {
                    try await Task.sleep(for: .seconds(2))
                } catch {
                    return
                }
            }
        }
    }

    deinit {
        pollingTask?.cancel()
    }

    private func refresh() async {
        var previousBlockedCounts: [String: Int] = [:]

        for snapshot in sessions where snapshot.session.running {
            if let blockedCount = snapshot.blockedCount {
                previousBlockedCounts[snapshot.id] = blockedCount
            }
        }

        do {
            sessions = try await loadSessionSnapshots(
                previousBlockedCounts: previousBlockedCounts
            )
        } catch is CancellationError {
            return
        } catch {
            print("Failed to refresh sessions:", error)
        }
    }
}
