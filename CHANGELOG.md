# Changelog

## Unreleased

- Start and stop recording from any app with ⌃⌥⌘R.
- Raw recordings are deleted after 7 days. **Clear Raw Recordings** in the menu removes them sooner and shows how much space they use.
- Tests run on GitHub Actions for every pull request.
- Motion blur on zooms, pans and the cursor, set from 0 to 100%.
- Microphone and system audio, each recorded on its own track and mixed on export. The microphone is evened out to a −6 dBFS peak.
- Pause and resume with ⌃⌥⌘P; video, audio and input skip the paused time together.
- Record one window or a dragged area as well as the whole screen.
- Settings window (⌘,): MP4 (H.264 or HEVC), ProRes 422 HQ or GIF, resolution, frame rate, quality, zoom level, padding, corners, shadow, cursor size and smoothing.
- Zoom editor (**Edit Last Recording…**, ⌘E): live preview with sound, zooms you can move, resize, add and remove, a level from 1× to 4× and an automatic or pinned focus per zoom. Edits are saved next to the raw recording and used by every export after them.
- `Avora render` takes `--format` and `--motion-blur`, and uses zooms edited in the editor.
- A recording that fails to start no longer leaves an empty folder behind.

## 0.1.0 - 2026-10-31

- First version: records the screen and zooms in on clicks, with a smoothed cursor drawn by Avora.
- Twelve background presets, chosen from the menu bar or Avora's own window.
- `Avora render` renders a raw recording again, optionally with another background.
- Documentation site at https://halitsever.github.io/avora-screen-recorder/.
