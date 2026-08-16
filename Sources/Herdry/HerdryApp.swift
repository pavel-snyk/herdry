import AppKit
import SwiftUI

@main
struct HerdryApp: App {
    @StateObject private var store = SessionStore()

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
                    attachToSession(snapshot.session)
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

            Button("Quit Herdry") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            MenuBarIcon(store: store, image: menuBarIcon)
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
