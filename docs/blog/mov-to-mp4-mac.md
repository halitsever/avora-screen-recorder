---
title: "MOV to MP4 on Mac: Convert Without Uploading"
titleTemplate: false
description: "QuickTime Player cannot save MP4, so here are the ways that can: HandBrake, ffmpeg in Terminal, or a recorder that exports MP4 to begin with. No upload needed."
headline: "Convert a MOV file to MP4 on a Mac"
date: "2026-11-28"
keyword: ".mov to mp4"
faq: [{"q": "Can QuickTime convert MOV to MP4?", "a": "No. QuickTime Player's Export As writes QuickTime movies (.mov), and Apple's guide says it doesn't export MP4."}, {"q": "Does converting MOV to MP4 lose quality?", "a": "Not with ffmpeg's -c copy, which moves the existing streams into a new container. A re-encode, as HandBrake does, can lose some quality depending on the settings."}, {"q": "Is it safe to convert MOV to MP4 online?", "a": "It works, but the file is uploaded to someone else's server. For screen recordings that show private information, converting on the Mac is the safer choice."}]
---

<div class="post wrap">

# Convert a MOV file to MP4 on a Mac

<p class="post-meta">By <a href="https://halit.org">Halit Sever</a> · <time datetime="2026-11-28">28 November 2026</time></p>

<p class="lead">Screen recordings made with the Mac's own tools are .mov files. Most players and sites accept them, but some upload forms, older Windows apps and messaging tools want .mp4. Both are containers that usually hold the same H.264 or HEVC video, so the conversion is quick, and you can do it on the Mac without sending the file to a website.</p>

## Why QuickTime Player is not enough

QuickTime Player's **File › Export As** offers 4K, 1080p, 720p, 480p and Audio Only. Every video choice writes a QuickTime movie, and Apple's [QuickTime Player's export guide](https://support.apple.com/guide/quicktime-player/export-movies-qtp20e395859/mac) says it plainly: QuickTime Player doesn't export movies as MP4 videos. Renaming the file from .mov to .mp4 sometimes plays, but it is not a conversion, so it is not a reliable fix.

## HandBrake (free, with a window)

[HandBrake](https://handbrake.fr) is a free, open source video converter for Mac, Windows and Linux.

1. Open HandBrake and drag the .mov file onto its window, or click **Open Source**.
2. Keep the default preset, **Fast 1080p30**, or pick another from the **Presets** list. HandBrake's General presets all use the MP4 container.
3. Check the **Format** is MP4 on the **Summary** tab, and choose a destination at the bottom.
4. Click **Start**.

HandBrake re-encodes the video, which takes a while for long files and can make the file smaller. Its [container documentation](https://handbrake.fr/docs/en/latest/technical/containers.html) notes that it may name the file .m4v when chapters or AC3 audio are enabled; there is a preference to keep .mp4.

## ffmpeg (Terminal, no re-encode)

When the .mov already holds H.264 or HEVC video and AAC audio, which is what Mac screen recordings normally contain, ffmpeg can copy the streams into an MP4 container without touching the picture:

```bash
ffmpeg -i "Screen Recording.mov" -c copy "Screen Recording.mp4"
```

`-c copy` is ffmpeg's [stream copy](https://ffmpeg.org/ffmpeg.html#Stream-copy) mode, so it finishes in seconds and the quality does not change. If ffmpeg reports that a codec is not supported in MP4, drop `-c copy` and let it re-encode. ffmpeg is not part of macOS; it is commonly installed with Homebrew (`brew install ffmpeg`).

## Skip the conversion: record to MP4

[Avora](/), a free and open source screen recorder for Mac (macOS 14 or later), exports straight to MP4. Under its export settings, H.264 and HEVC produce `.mp4` files, ProRes 422 HQ produces `.mov` and GIF produces `.gif`, in shapes from 16:9 to 9:16. The finished video lands in `~/Movies/Avora` and can be copied to the clipboard on export, so it pastes into a chat or an upload form as it is. Start and stop with <kbd>Control</kbd> <kbd>Option</kbd> <kbd>Command</kbd> <kbd>R</kbd> in any app. [Download Avora](https://github.com/halitsever/avora-screen-recorder/releases/latest).

## FAQ

### Can QuickTime convert MOV to MP4?

No. QuickTime Player's Export As writes QuickTime movies (.mov), and Apple's guide says it doesn't export MP4.

### Does converting MOV to MP4 lose quality?

Not with ffmpeg's -c copy, which moves the existing streams into a new container. A re-encode, as HandBrake does, can lose some quality depending on the settings.

### Is it safe to convert MOV to MP4 online?

It works, but the file is uploaded to someone else's server. For screen recordings that show private information, converting on the Mac is the safer choice.

## Related posts

- [Where do screen recordings go on Mac?](/blog/where-do-screen-recordings-go-on-mac)
- [Record your screen to a GIF on Mac](/blog/screen-recording-to-gif-mac)
- [Record your screen with QuickTime Player](/blog/quicktime-screen-recording)
- [All posts](/blog/)

</div>
