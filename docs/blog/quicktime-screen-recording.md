---
title: "QuickTime Screen Recording: Audio, Stop, Trim"
titleTemplate: false
description: "Record your Mac screen with QuickTime Player: start the recording, add your microphone or system audio, stop it, then trim and export the .mov file."
headline: "Record your screen with QuickTime Player"
date: "2026-11-28"
keyword: "quicktime screen recording"
faq: [{"q": "Does QuickTime screen recording record audio?", "a": "It records the microphone you choose under Options. Recording the Mac's own sound needs the Include System Audio option on macOS 27 Golden Gate, or other software on earlier versions."}, {"q": "How do I stop a QuickTime screen recording?", "a": "Click the Stop button in the menu bar or press Command-Control-Esc."}, {"q": "Where are QuickTime screen recordings saved?", "a": "In the location chosen under Options in the Screenshot toolbar. The default is the desktop, as a .mov file."}]
---

<div class="post wrap">

# Record your screen with QuickTime Player

<p class="post-meta">By <a href="https://halit.org">Halit Sever</a> · <time datetime="2026-11-28">28 November 2026</time></p>

<p class="lead">QuickTime Player ships with every Mac, and its New Screen Recording command opens the same Screenshot toolbar that Shift-Command-5 does. It records the screen with optional microphone sound, and afterwards QuickTime can trim the clip and export it at a smaller size.</p>

## Start a recording

1. Open **QuickTime Player** from Applications.
2. Choose **File › New Screen Recording** (<kbd>Control</kbd> <kbd>Command</kbd> <kbd>N</kbd>). The Screenshot toolbar appears at the bottom of the screen.
3. Choose **Record Entire Screen** or **Record Selected Portion**, and drag the frame if you picked a portion.
4. Open **Options** to choose a microphone, the save location, a timer and whether to show mouse clicks.
5. Click **Record**.

These steps follow Apple's [QuickTime Player's screen recording guide](https://support.apple.com/guide/quicktime-player/record-your-screen-qtp97b08e666/mac) for macOS 27 Golden Gate, checked in November 2026.

## Recording with audio

QuickTime records sound only from what you pick under **Options**:

- **Your voice.** Choose a microphone, such as the MacBook's built-in mic or a USB mic.
- **The Mac's own sound.** On macOS 27 Golden Gate the Options menu has **Include System Audio**. On macOS 26 and earlier this option is missing, which is why many guides suggest a virtual driver such as BlackHole. [Record Mac system audio without BlackHole](/blog/record-mac-system-audio-without-blackhole) covers both cases.

If you choose no microphone and leave system audio off, the recording is silent.

## Stop the recording

Click the **Stop** button in the menu bar, or press <kbd>Command</kbd> <kbd>Control</kbd> <kbd>Esc</kbd>. When the menu bar is hidden, for example in a full screen app, the keyboard shortcut is the reliable way. More on that in [how to stop a screen recording on Mac](/blog/how-to-stop-screen-recording-on-mac).

## Trim and save

1. Open the recording in QuickTime Player and choose **Edit › Trim**.
2. Drag the yellow handles in the trimming bar. Everything outside them is cut.
3. Click **Trim**, then save with **File › Save**.

QuickTime can also split a movie into clips and rearrange them, as described in Apple's [trim guide](https://support.apple.com/guide/quicktime-player/trim-a-movie-or-clip-qtpf2115f6fd/mac) and the pages next to it.

## Export a smaller file

**File › Export As** offers 4K, 1080p, 720p and 480p. Each one writes a .mov file with H.264 or HEVC. QuickTime Player does not export MP4; if you need one, see [convert MOV to MP4 on a Mac](/blog/mov-to-mp4-mac).

## When you need more than a raw clip

QuickTime records exactly what was on the screen. [Avora](/) is a free, open source recorder for Mac that adds what a tutorial or demo usually needs, without a separate editor: zoom on every click, a larger and smoother cursor, your microphone and the Mac's audio on separate tracks, a camera bubble, captions, and export to MP4, ProRes or GIF. Start and stop it with <kbd>Control</kbd> <kbd>Option</kbd> <kbd>Command</kbd> <kbd>R</kbd> from any app. [Download Avora](https://github.com/halitsever/avora-screen-recorder/releases/latest).

## FAQ

### Does QuickTime screen recording record audio?

It records the microphone you choose under Options. Recording the Mac's own sound needs the Include System Audio option on macOS 27 Golden Gate, or other software on earlier versions.

### How do I stop a QuickTime screen recording?

Click the Stop button in the menu bar or press Command-Control-Esc.

### Where are QuickTime screen recordings saved?

In the location chosen under Options in the Screenshot toolbar. The default is the desktop, as a .mov file.

## Related posts

- [How to stop a screen recording on Mac](/blog/how-to-stop-screen-recording-on-mac)
- [How to record screen and audio on Mac](/blog/how-to-record-screen-and-audio-on-mac)
- [Convert a MOV file to MP4 on a Mac](/blog/mov-to-mp4-mac)
- [All posts](/blog/)

</div>
