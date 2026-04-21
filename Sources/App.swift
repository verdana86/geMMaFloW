import SwiftUI
import Darwin
import os

private let exitLog = Logger(subsystem: "com.verdana86.gemmaflow", category: "Exit")

private func logExitBacktrace(_ reason: String) {
    let symbols = Thread.callStackSymbols.joined(separator: "\n")
    exitLog.error("EXIT TRAP (\(reason, privacy: .public)) — backtrace:\n\(symbols, privacy: .public)")
}

private let signalHandler: @convention(c) (Int32) -> Void = { sig in
    let name: String
    switch sig {
    case SIGSEGV: name = "SIGSEGV"
    case SIGABRT: name = "SIGABRT"
    case SIGBUS:  name = "SIGBUS"
    case SIGILL:  name = "SIGILL"
    case SIGTERM: name = "SIGTERM"
    case SIGFPE:  name = "SIGFPE"
    case SIGPIPE: name = "SIGPIPE"
    default:      name = "signal \(sig)"
    }
    logExitBacktrace("signal \(name)")
    _exit(128 + sig)
}

@main
struct FreeFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("show_menu_bar_icon") private var showMenuBarIcon = true

    init() {
        atexit {
            logExitBacktrace("atexit")
        }
        for sig in [SIGSEGV, SIGABRT, SIGBUS, SIGILL, SIGFPE, SIGPIPE, SIGTERM] {
            signal(sig, signalHandler)
        }
    }

    var body: some Scene {
        MenuBarExtra(isInserted: $showMenuBarIcon) {
            MenuBarView()
                .environmentObject(appDelegate.appState)
        } label: {
            MenuBarLabel()
                .environmentObject(appDelegate.appState)
        }
    }
}

struct MenuBarLabel: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        let icon: String = if appState.isRecording {
            "record.circle"
        } else if appState.isTranscribing {
            "ellipsis.circle"
        } else {
            "waveform"
        }
        Image(systemName: icon)
    }
}
