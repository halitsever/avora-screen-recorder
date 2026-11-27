# Avora

Open-source macOS screen recorder (Swift, ScreenCaptureKit, SwiftUI) with automatic click-to-zoom, used by people who record product demos and tutorials and download it from GitHub Releases.

## Verify a change

- CI (`.github/workflows/test.yml`) runs `swift test` on `macos-26` with a 20 minute timeout. Run it before pushing any Swift change.
- Package tools version is 6.0, so building needs Xcode 16 or later on macOS 14+. Linux cannot build or test it.
- `./scripts/build-app.sh` assembles `build/Avora.app`. Without `SIGN_IDENTITY` it signs ad hoc, and macOS asks for Screen Recording permission again after every rebuild.
- For website changes: `npm ci && npm run docs:build` from the repository root.

## Gotchas

- Zoom logic lives in the `ZoomEngine` target with no UI code, which is what lets `swift test` cover it. Keep UI code in `Sources/Avora`.
- `.build/release/Avora render "<recording folder>" out.mp4` re-renders a raw recording from `~/Library/Application Support/Avora/Recordings` without the UI (`Sources/Avora/RenderCommand.swift`). Use it to check renderer changes.
- Publishing a GitHub release triggers `.github/workflows/release.yml`, which fails unless `CFBundleShortVersionString` in `Resources/Info.plist` equals the tag without the `v`. The in-app updater installs the `Avora.zip` that workflow uploads.
- `CHANGELOG.md` gets an entry per release.
- Tests skip pushes that only touch `docs/**`, `**.md` or the root `package.json` and lockfile.

## Docs and site

- The root `package.json` belongs to the VitePress site in `docs/`, not to the app.
- `.github/workflows/deploy-docs.yml` deploys it to https://projects.halit.org/avora-screen-recorder/ on pushes to `main` that touch `docs/**`, `Resources/Brand/**`, `package.json` or `package-lock.json`.
- `DOCS_URL` overrides the site URL for a custom domain; the base path follows from it. `docs/public/robots.txt` and `docs/public/llms.txt` hardcode the Pages URL, so update them with it.
- The site is a single page. Sections are `#using`, `#zoom`, `#backgrounds`, `#install` and `#hood`; the README feature links point at them.

## Conventions

- Conventional-commit subject lines only, in English, with no body and no trailer.
- Work on a branch and open a pull request. The owner merges.
- No emoji in new text. Code comments are short, one line where possible, and explain why.
- The README follows the owner's template. Every image served from `halitsever-api.vercel.app` stays byte-for-byte; only the `title=` value of `api/repo-title` and the issue wrapper link may be corrected.
- Version bumps in `Info.plist` and publishing releases are done by the owner.
