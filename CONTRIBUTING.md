# Contributing

DockDock is a small macOS utility, so changes should stay narrow and easy to
verify.

## Local Setup

```bash
./script/build_and_run.sh
swift run GeometryChecks
```

## Pull Request Checklist

- Keep the app source buildable with SwiftPM.
- Run `swift run GeometryChecks`.
- Run `swift build`.
- If the change affects launch, permissions, signing, or event taps, run
  `./script/build_and_run.sh --verify`.
- Mention any manual testing done with Accessibility permission enabled.

## Design Rules

- Use public macOS APIs only.
- Do not use private Dock, SkyLight, or injection-based APIs.
- Keep the trigger geometry logic in `DockDockCore` when possible.
- Keep platform side effects in `Sources/DockDock/Services`.
- Avoid making the pointer feel trapped. Snaps should happen only on deliberate
  trigger entry.
