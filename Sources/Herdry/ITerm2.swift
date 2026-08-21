import Carbon
import Foundation

enum ITerm2JumpError: Error, LocalizedError, Sendable {
    case notInstalled
    case automationPermissionDenied
    case appleScriptFailure(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            "iTerm2 is not installed in /Applications."
        case .automationPermissionDenied:
            "Herdry does not have permission to control iTerm2. Allow it in System Settings > Privacy & Security > Automation."
        case let .appleScriptFailure(message):
            "iTerm2 automation failed: \(message)"
        }
    }
}

func jumpToITerm2Session(_ session: HerdrSession) async throws {
    let sessionName = session.name

    try await Task.detached(priority: .userInitiated) {
        try executeITerm2Jump(sessionName: sessionName)
    }.value
}

private let iTerm2Path = "/Applications/iTerm.app"

// iTerm2 recommends its Python API over AppleScript. Herdry intentionally uses
// AppleScript here because it provides a small, low-latency integration without
// a helper or managed runtime. Revisit this if iTerm2 removes or breaks the API.
private let iTerm2JumpAppleScript = #"""
on jumpToSession(herdrSessionName)
    set quotedSessionName to quoted form of herdrSessionName
    set attachCommand to "exec /usr/bin/env -u HERDR_ENV /opt/homebrew/bin/herdr session attach " & quotedSessionName
    set launchCommand to "/bin/zsh -lc " & quoted form of attachCommand

    tell application "/Applications/iTerm.app"
        repeat with terminalWindow in windows
            repeat with terminalTab in tabs of terminalWindow
                repeat with terminalSession in sessions of terminalTab
                    try
                        set metadataValue to variable terminalSession named "user.herdrySession"
                    on error
                        set metadataValue to ""
                    end try

                    if metadataValue is herdrSessionName then
                        set sessionID to id of terminalSession
                        select terminalSession
                        select terminalTab
                        select terminalWindow
                        activate
                        return sessionID
                    end if
                end repeat
            end repeat
        end repeat

        set terminalWindow to create window with default profile command launchCommand
        set terminalTab to current tab of terminalWindow
        set terminalSession to current session of terminalTab
        set variable terminalSession named "user.herdrySession" to herdrSessionName
        set sessionID to id of terminalSession
        select terminalSession
        select terminalTab
        select terminalWindow
        activate
        return sessionID
    end tell
end jumpToSession
"""#

private func executeITerm2Jump(sessionName: String) throws {
    var isDirectory: ObjCBool = false

    guard FileManager.default.fileExists(
        atPath: iTerm2Path,
        isDirectory: &isDirectory
    ), isDirectory.boolValue else {
        throw ITerm2JumpError.notInstalled
    }

    guard let script = NSAppleScript(source: iTerm2JumpAppleScript) else {
        throw ITerm2JumpError.appleScriptFailure("Could not load the embedded script.")
    }

    let event = NSAppleEventDescriptor(
        eventClass: AEEventClass(kASAppleScriptSuite),
        eventID: AEEventID(kASSubroutineEvent),
        targetDescriptor: nil,
        returnID: AEReturnID(kAutoGenerateReturnID),
        transactionID: AETransactionID(kAnyTransactionID)
    )
    event.setParam(
        NSAppleEventDescriptor(string: "jumpToSession"),
        forKeyword: AEKeyword(keyASSubroutineName)
    )

    let arguments = NSAppleEventDescriptor.list()
    arguments.insert(NSAppleEventDescriptor(string: sessionName), at: 1)
    event.setParam(arguments, forKeyword: AEKeyword(keyDirectObject))

    var errorInfo: NSDictionary?

    _ = script.executeAppleEvent(event, error: &errorInfo)

    if errorInfo != nil {
        throw makeITerm2JumpError(errorInfo)
    }
}

private func makeITerm2JumpError(_ errorInfo: NSDictionary?) -> ITerm2JumpError {
    let errorNumber = (errorInfo?[NSAppleScript.errorNumber] as? NSNumber)?.intValue

    if errorNumber == errAEEventNotPermitted {
        return .automationPermissionDenied
    }

    let message = errorInfo?[NSAppleScript.errorMessage] as? String
        ?? errorInfo?[NSAppleScript.errorBriefMessage] as? String
        ?? "Unknown AppleScript error"

    return .appleScriptFailure(message)
}
