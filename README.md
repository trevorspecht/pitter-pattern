# PitterPattern

A practice companion for woodwind players (and anyone who reads staff notation):
generate scales and scale-derived patterns, transpose them into any key, clamp
them to a playable range, view them on a staff, and play them back — on macOS,
iOS, and iPadOS from one codebase.

## Status

Pre-alpha. Milestone progress is tracked in `TASKS.md`; design decisions are
recorded in `docs/DECISIONS.md`; specs delegated for implementation live in
`docs/specs/`.

## Layout

| Path                  | What it is                                                        |
| --------------------- | ----------------------------------------------------------------- |
| `Sources/PitterCore/` | Platform-agnostic core: music theory, catalog, notation, audio   |
| `Tests/PitterCoreTests/` | Unit tests for the core (runs headlessly with `swift test`)   |
| `App/`                | Shared SwiftUI app sources (multiplatform)                        |
| `project.yml`         | XcodeGen project definition for the app targets                   |
| `docs/`               | Decisions, specs, notes                                           |

## Building

- Core + tests (no Xcode needed): `swift test`
- App targets: requires full Xcode + [XcodeGen](https://github.com/yonaskolb/XcodeGen):
  `xcodegen generate` then open `PitterPattern.xcodeproj`.

## License

TBD (before any public/App Store distribution).
