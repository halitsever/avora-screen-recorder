# Changelog

## 0.2.0 - 2026-11-01

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
- A recorded window is followed when it moves and stays visible when other windows cover it.
- The editor shows the audio waveform under the zooms.
- The test workflow can also be started by hand.
- Camera: a bubble in any corner, square to 16:9, rounded or circular, that shrinks during zooms; a floating preview while recording; hidden ranges in the editor.
- Captions written on the Mac from what was said, burned into the video or saved as .srt, editable in the editor.
- Voice presets: as recorded, even level, or clear, which removes background noise with Apple's voice isolation.
- Editor: cut, split and speed up clips with pitch kept, blur and highlight masks, crop, cursor-hidden ranges, undo and redo, export and copy, copy or save the current frame.
- Cursor: click effects (circle or ripple), fading out when idle, holding still at the end, hiding it entirely.
- A badge for the keyboard shortcuts pressed while recording, which never records plain typing.
- Output shapes from 16:9 to 9:16, and backdrops from a solid color, your own picture or the desktop wallpaper, with blur.
- Restart (⌃⌥⌘⌫) and discard a recording; send a finished video to the clipboard; save looks as presets.
- Recordings are written as they go, and Avora offers to recover one cut short by a crash.
- `Avora render` takes `--preset` and `--setting key=value`.
- Camera layouts for any stretch of the video: side by side with the screen (stacked in a tall video) or full screen, easing in and out.
- After each recording the camera is lined up with the microphone by matching the speaker's lips to their voice.
- **Auto Blur** in the editor finds email addresses, phone and card numbers, IBANs, API keys or faces on screen and blurs them. Masks may now overlap.
- **Speed Up Typing** in the editor plays stretches of steady typing at 3×, when **Note when you type** is on.
- In square, 4:5 and 9:16 videos a zoom fills the frame instead of leaving bands of backdrop.
- The editor opens after each recording unless turned off in **Settings…**.
- Avora starts in the menu bar without opening its window; **Open Avora…** opens it. The window previews the backdrop around a more lifelike desktop.
- The headline describes the whole app instead of the zoom alone.
- A recording that fails to start no longer leaves an empty folder behind.

## 0.1.0 - 2026-10-31

- First version: records the screen and zooms in on clicks, with a smoothed cursor drawn by Avora.
- Twelve background presets, chosen from the menu bar or Avora's own window.
- `Avora render` renders a raw recording again, optionally with another background.
- Documentation site at https://halitsever.github.io/avora-screen-recorder/.
