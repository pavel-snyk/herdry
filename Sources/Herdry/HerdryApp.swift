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
                .disabled(!snapshot.session.running)
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
