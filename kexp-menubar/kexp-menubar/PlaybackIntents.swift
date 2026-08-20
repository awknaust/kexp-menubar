//
//  PlaybackIntents.swift
//  kexp-menubar
//

// Compiled in only when the build is signed with a real (team ID) identity —
// macOS refuses App Intents connections to ad-hoc-signed apps, so an unsigned
// build would surface a permanently broken action in Shortcuts.
#if APP_INTENTS_ENABLED

import AppIntents
import Foundation

/// Toggles the KEXP stream from outside the app: the Shortcuts app (where a
/// shortcut can be given a global keyboard shortcut), Spotlight, Stream Deck's
/// "Run Shortcut" action, or `shortcuts run` from any macro tool.
struct TogglePlaybackIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Playback"
    static let description = IntentDescription("Plays or pauses the KEXP stream.")
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // If the intent cold-launched the app, the player may not
        // be constructed yet — give it a moment before giving up.
        var attempts = 0
        while AudioPlayer.shared == nil && attempts < 20 {
            try await Task.sleep(nanoseconds: 50_000_000)
            attempts += 1
        }
        guard let player = AudioPlayer.shared else {
            print("[Intents] toggle failed: no AudioPlayer instance")
            throw PlaybackIntentError.playerUnavailable
        }

        // isPlaying updates asynchronously via KVO on the play path, so report
        // the intended state rather than reading back after the toggle.
        let wasActive = player.isPlaying || player.isBuffering
        player.togglePlayback()
        print("[Intents] toggled playback -> \(wasActive ? "paused" : "playing")")
        return .result(dialog: wasActive ? "KEXP paused" : "KEXP playing")
    }
}

private enum PlaybackIntentError: Error, CustomLocalizedStringResourceConvertible {
    case playerUnavailable

    var localizedStringResource: LocalizedStringResource {
        "KEXP Menubar's audio player isn't ready yet. Try again in a moment."
    }
}

/// Surfaces "Toggle Playback" in Shortcuts and Spotlight without the user
/// having to assemble a shortcut by hand.
struct KEXPShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TogglePlaybackIntent(),
            phrases: [
                "Toggle \(.applicationName)",
                "Play \(.applicationName)",
                "Pause \(.applicationName)"
            ],
            shortTitle: "Toggle Playback",
            systemImageName: "playpause"
        )
    }
}

#endif
