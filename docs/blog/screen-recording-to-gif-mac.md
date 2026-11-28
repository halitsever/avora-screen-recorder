---
title: "Record Your Screen to a GIF on Mac"
titleTemplate: false
description: "macOS records screen video as .mov, not GIF. How to record your screen straight to a GIF on Mac, convert an existing recording, and keep the file small."
headline: "Turn a Mac screen recording into a GIF"
date: "2026-11-28"
keyword: "record screen to gif mac"
faq: [{"q": "Can Mac record the screen as a GIF?", "a": "Not with the built-in tools; they save .mov files. Avora exports GIF directly, or you can convert a .mov with ffmpeg."}, {"q": "Why is my screen recording GIF so large?", "a": "GIFs store up to 256 colors per frame and compress poorly. Record a smaller area, shorten it, and lower the frame rate and width."}]
---

<div class="post wrap">

# Turn a Mac screen recording into a GIF

<p class="post-meta">By <a href="https://halit.org">Halit Sever</a> · <time datetime="2026-11-28">28 November 2026</time></p>

<p class="lead">GIFs play anywhere: in a README on GitHub, in a support ticket, in a chat that won't autoplay video. The Mac's built-in recorder only makes .mov files, so a GIF needs one more step. Here are two ways to get there.</p>

## The built-in recorder makes .mov only

The Screenshot toolbar (<kbd>Shift</kbd> <kbd>Command</kbd> <kbd>5</kbd>) and QuickTime Player save screen recordings as .mov files. Apple's [macOS User Guide](https://support.apple.com/guide/mac-help/take-screenshots-or-screen-recordings-mh26782/mac) for macOS 27 Golden Gate describes no other format, so turning a recording into a GIF takes a converter or a recorder that exports GIF itself.

## Option 1: record and export a GIF with Avora

[Avora](/), a free and open source recorder for macOS 14 or later, exports GIF directly.

1. Open **Settings…** (<kbd>Command</kbd> <kbd>,</kbd>) from Avora's menu bar menu.
2. In the export settings, set **Format** to **GIF**.
3. Pick a **Shape**: the recording's own, 16:9, 4:3, 1:1 square, 4:5, 3:4 or 9:16.
4. Record with <kbd>Control</kbd> <kbd>Option</kbd> <kbd>Command</kbd> <kbd>R</kbd> and stop with the same keys.

The GIF keeps Avora's look: zooms on your clicks, the smoothed cursor and the backdrop if you chose one. Avora's GIFs run at 15 frames per second and are at most 960 pixels wide, which keeps the files a reasonable size, and they loop forever. The file lands in `~/Movies/Avora` with a `.gif` extension, or on the clipboard if **After Recording** is set to copy. Save the settings as a preset to switch between GIF and MP4 quickly.

Already recorded the take as MP4? Open it with **Edit Last Recording…** (<kbd>Command</kbd> <kbd>E</kbd>) within 7 days, change the format to GIF and export again. The [zoom explainer](/blog/auto-zoom-screen-recording) shows what the zoom does in each frame.

## Option 2: convert an existing .mov with ffmpeg

For a recording you already made with the built-in tools, ffmpeg (installable with Homebrew: `brew install ffmpeg`) does a good conversion with a palette built from the video itself:

```bash
ffmpeg -i "Screen Recording.mov" \
  -vf "fps=15,scale=960:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" \
  -loop 0 out.gif
```

`fps=15` and `scale=960:-1` set the frame rate and width; `palettegen` and `paletteuse` pick the best 256 colors for this clip, which looks much better than a fixed palette. `-loop 0` makes it loop.

## Keep GIFs small

- **Record a smaller area.** A window or a dragged area instead of the whole screen.
- **Keep it short.** GIF has no inter-frame compression as good as video, so size grows quickly with length.
- **Lower the frame rate and width.** 10-15 fps and 640-960 px wide are plenty for UI demos.
- **Avoid gradients and video.** GIF has 256 colors per frame; flat interfaces compress far better than photos or blurred backdrops.
- **Consider MP4.** GitHub, Slack and most sites play short MP4s inline, at a fraction of a GIF's size.

## FAQ

### Can Mac record the screen as a GIF?

Not with the built-in tools; they save .mov files. Avora exports GIF directly, or you can convert a .mov with ffmpeg.

### Why is my screen recording GIF so large?

GIFs store up to 256 colors per frame and compress poorly. Record a smaller area, shorten it, and lower the frame rate and width.

## Related posts

- [How to screen record on Mac](/blog/how-to-screen-record-on-mac)
- [Where do screen recordings go on Mac?](/blog/where-do-screen-recordings-go-on-mac)
- [Auto zoom in screen recordings: how it works](/blog/auto-zoom-screen-recording)
- [All posts](/blog/)

</div>
