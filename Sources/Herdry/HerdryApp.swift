import AppKit
import SwiftUI

@main
struct HerdryApp: App {
    @StateObject private var store = SessionStore()
    @AppStorage("terminalKind") private var selectedTerminal = TerminalKind.alacritty

    var body: some Scene {
        let menuBarIcon: NSImage = {
            guard let url = Bundle.module.url(
                forResource: "herdry-menubar",
                withExtension: "png"
            ),
                  let image = NSImage(contentsOf: url) else {
                fatalError("Missing herdry-menubar.png")
            }

            image.isTemplate = true
            image.size = NSSize(width: 20, height: 20)

            return image
        }()
        MenuBarExtra {
            ForEach(store.sessions) { snapshot in
                Button {
                    jump(to: snapshot.session)
                } label: {
                    Label(
                        snapshot.session.name,
                        systemImage: snapshot.session.running ? "circle.fill"
                                : "circle"
                    )
                }
                .badge(snapshot.blockedCount.flatMap { blockedCount in
                    blockedCount > 0
                            ? Text("\(blockedCount) blocked")
                            : nil
                })
                .badgeProminence(.decreased)
            }

            Divider()

            Menu("Terminal") {
                Picker("Terminal", selection: $selectedTerminal) {
                    ForEach(TerminalKind.allCases) { terminal in
                        Text(terminal.displayName).tag(terminal)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Divider()

            Button("Quit Herdry") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            MenuBarIcon(store: store, image: menuBarIcon)
        }
    }

    @MainActor
    private func jump(to session: HerdrSession) {
        switch selectedTerminal {
        case .alacritty:
            attachToSession(session)
        case .iTerm2:
            Task {
                do {
                    try await jumpToITerm2Session(session)
                } catch {
                    NSLog(
                        "Failed to open Herdr session %@ in iTerm2: %@",
                        session.name,
                        error.localizedDescription
                    )
                    showITerm2Error(error)
                }
            }
        }
    }

    @MainActor
    private func showITerm2Error(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn’t open the Herdr session in iTerm2"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")

        NSApplication.shared.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

enum TerminalKind: String, CaseIterable, Identifiable {
    case alacritty
    case iTerm2

    var id: Self { self }

    var displayName: String {
        switch self {
        case .alacritty:
            "Alacritty"
        case .iTerm2:
            "iTerm2"
        }
    }
}

private struct MenuBarIcon: View {
    @ObservedObject var store: SessionStore
    let image: NSImage

    private var hasAttention: Bool {
        store.sessions.contains { ($0.blockedCount ?? 0) > 0 }
    }

    private var renderedImage: NSImage {
        let badge = hasAttention
                ? NSImage(
                    systemSymbolName: "exclamationmark.circle.fill",
                    accessibilityDescription: nil
                )?.withSymbolConfiguration(
                    NSImage.SymbolConfiguration(pointSize: 7, weight: .regular)
                )
                : nil
        let renderedSize = NSSize(width: image.size.width + 2, height: image.size.height)

        let renderedImage = NSImage(size: renderedSize, flipped: false) { bounds in
            image.draw(in: NSRect(origin: .zero, size: image.size))

            if let badge {
                badge.draw(
                    at: NSPoint(x: bounds.maxX - badge.size.width, y: 0.5),
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1
                )
            }

            return true
        }
        renderedImage.isTemplate = true

        return renderedImage
    }

    var body: some View {
        Image(nsImage: renderedImage)
    }
}
