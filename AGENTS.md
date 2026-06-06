# AGENTS

## Current Rules
- All new feature work must use Flutter.
- UI and business state must remain strictly separated.
- Before every new modification, read this file and continue with the existing architecture.
- After every modification, run `flutter analyze` and keep the project analyzer-clean.

## Layout Notes
- The app uses a landscape dashboard shell.
- Current implementation has moved away from whole-page global scaling.
- Shared shell areas such as left navigation and top bar should remain reusable and stable.

## Implemented / In Progress
- Auth pages: migrated to Flutter 2.0 UI.
- Home page: migrated to Flutter 2.0 UI baseline.
- AI chat, courseware, cloud drive, video center, music companion, notes, collection, recording system: all have Flutter 2.0 pages connected.
- Smart campus: currently kept in a stable placeholder-safe version to avoid project-wide breakage before the full rebuild.
- Dictation secondary page: implemented with real menu + textbook APIs and 2.0 layout.
- Sight singing / music theory / answer questions / voice / instrumental secondary pages:
  - unified under `lib/features/study_catalog/`
  - share the dictation 2.0 visual structure
  - use 1.0 menu/textbook API rules and route branching
  - router now points these routes to real Flutter pages instead of placeholders
- Music play tertiary page:
  - implemented under `lib/features/music_play/`
  - route `/musicPlay` now points to a real Flutter page
  - detail data uses 1.0 `textbookDetail` API rules
  - long-audio playback uses `media_kit`
  - bottom piano interaction reuses the existing Flutter short-audio ecosystem via `flutter_soloud`
  - page startup must not block on full piano/metronome asset preload
  - musicPlay should warm up piano audio in the background and load textbook detail first
- iOS audio architecture (professional single-session model, refactored):
  - `lib/core/audio/native_playback_audio_session.dart` is the SOLE owner of AVAudioSession. It configures + `setActive(true)` once and NEVER calls `setActive(false)` during in-app navigation. Default category `playback`; record/tuner/sight-singing temporarily escalate to `playAndRecord` (default vs `measurement` mode) by re-configuring on the live, still-active session.
  - `ios/Runner/LowLatencyNoteAudio.swift` keeps ONE persistent `AVAudioEngine` (24-voice fixed pool, static graph) for ALL short audio (piano / metronome / dictation) for the whole app lifetime. It NEVER rebuilds the graph on navigation and NEVER touches the session category. It only restarts the engine (start + resume nodes) in response to `AVAudioEngineConfigurationChange`, interruption-ended, or route changes; a full graph rebuild happens ONLY on `mediaServicesWereReset`.
  - Long audio uses `media_kit` (mpv) on the same shared `playback` session via `mixWithOthers`.
  - Rationale: the previous deactivate/reactivate-per-navigation + per-keypress `setCategory` + graph rebuild caused iPad piano silence/large latency (engine IO killed by `setActive(false)`, stale `isRunning`). Do NOT reintroduce `setActive(false)` on navigation or per-page engine rebuilds.
- Page audio lifecycle (`lib/features/music_companion/audio/page_audio_lifecycle.dart` + `lib/core/audio/native_piano_handoff.dart`):
  - enter on page open (playback piano / mediaKit+piano / sight-singing capture / tuner)
  - leave on page dispose or session exit: stop short audio, mark shared native graph stale; next page does one coalesced handoff (no double reclaim on sight-singing exit + music companion enter)
- Smart sight singing (`/smart-singing`):
  - implemented under `lib/features/smart_sight_singing/`
  - left nav entry enabled; supports built-in demo, local `.mid/.midi` upload, and online URL
  - after MIDI parse, user selects and confirms melody track; playback + scoring use that track only
  - iPad defaults to visual-only follow (no speaker accompaniment during sing; KTV track timer only)
  - iPad ready state offers melody preview; optional toggle to enable speaker accompaniment (headphones recommended)
  - playback uses shared piano short-audio scheduler when accompaniment enabled
  - follow-along scoring uses measurement mode (visual-only) or echo-cancel session (with accompaniment)
  - online import supports `.mid` / `.midi` only; legacy YIN/mp3 path kept in code but unused for demo

## Technical Direction
- For secondary study pages, prefer a reusable catalog architecture instead of duplicating page logic.
- Shared responsibilities are split into:
  - `data/`: API repository
  - `state/`: route args, state model, controller
  - `ui/`: page and presentational widgets
- Route-specific behavior such as target page parameters should be configured, not hard-coded per screen when possible.
