---
title: "How to Record Screen and Audio on Mac"
titleTemplate: false
description: "Record your Mac's screen with your voice and the Mac's own sound: the built-in options by macOS version, then a voice-over with camera and captions."
headline: "Record your Mac screen with your voice and system audio"
date: "2026-11-28"
keyword: "how to record audio and screen on mac"
faq: [{"q": "Why is there no sound in my Mac screen recording?", "a": "No microphone was chosen under Options, or you expected the Mac's own sound, which the built-in recorder only captures on macOS 27 Golden Gate with Include System Audio turned on."}, {"q": "Can I record my voice and the Mac's sound at the same time?", "a": "Yes. On macOS 27, choose a microphone and turn on Include System Audio. Avora records both on separate tracks on macOS 14 and later."}]
---

<div class="post wrap">

# Record your Mac screen with your voice and system audio

<p class="post-meta">By <a href="https://halit.org">Halit Sever</a> · <time datetime="2026-11-28">28 November 2026</time></p>

<p class="lead">"Audio" can mean two things in a screen recording: your voice through a microphone, and the sound the Mac itself plays. The built-in recorder handles the first on every version of macOS and the second only on the newest. This guide covers both.</p>

## What the built-in recorder records

| Sound | Screenshot toolbar (<kbd>Shift</kbd> <kbd>Command</kbd> <kbd>5</kbd>) |
| --- | --- |
| Your voice | Yes: choose a microphone under **Options** |
| The Mac's own sound | macOS 27 Golden Gate or later: **Options › Include System Audio** |

QuickTime Player's **New Screen Recording** opens the same toolbar. On macOS 26 and earlier the Mac's sound needs another app or a virtual driver; [recording system audio without BlackHole](/blog/record-mac-system-audio-without-blackhole) explains the options.

The macOS steps were checked against Apple's [macOS User Guide](https://support.apple.com/guide/mac-help/take-screenshots-or-screen-recordings-mh26782/mac) for macOS 27 Golden Gate and [Apple's screen recording guide](https://support.apple.com/en-us/102618) in November 2026.

## Steps with the built-in recorder

1. Press <kbd>Shift</kbd> <kbd>Command</kbd> <kbd>5</kbd> and choose what to record.
2. Click **Options**. Under **Microphone**, choose your mic. On macOS 27, also tick **Include System Audio**.
3. Click **Record**, talk through what you are doing, then stop with the Stop button in the menu bar or <kbd>Command</kbd> <kbd>Control</kbd> <kbd>Esc</kbd>.

## Steps with Avora: voice-over, system audio, camera and captions

[Avora](/) is a free, open source recorder for macOS 14 or later. It records both kinds of sound on every version it supports, and adds a camera bubble and captions.

1. **Set the sound.** Open **Settings…** (<kbd>Command</kbd> <kbd>,</kbd>) from the menu bar menu. Choose your **Microphone**, turn on **Record system audio**, and pick a **Voice** preset: **As recorded**, **Even level**, or **Clear** to remove background noise with Apple's voice isolation. The microphone and the Mac's sound are recorded on separate tracks and mixed on export.
2. **Add your camera (optional).** Pick a camera and you appear in a bubble in a corner of the video: square or wide, rounded or circular. It shrinks out of the way when the screen zooms in. A preview floats on screen while you record and never ends up in the video. After recording, Avora lines the picture up with your voice by matching your lips.
3. **Turn on captions (optional).** Avora writes captions on the Mac from what you say. Burn them into the video, save them as an .srt file, or both.
4. **Choose what to record.** Under **Capture**, pick **Whole Screen**, **Window** or **Area**.
5. **Record.** Press <kbd>Control</kbd> <kbd>Option</kbd> <kbd>Command</kbd> <kbd>R</kbd> in any app, or choose **Record Screen**. <kbd>Control</kbd> <kbd>Option</kbd> <kbd>Command</kbd> <kbd>P</kbd> pauses and resumes.
6. **Stop and edit.** Press <kbd>Control</kbd> <kbd>Option</kbd> <kbd>Command</kbd> <kbd>R</kbd> again. The editor opens on its own: fix caption words, cut mistakes, move zooms, then **Export**.

The first recording asks for Screen Recording permission, and the microphone, camera and captions each ask the first time you turn them on. Finished videos go to `~/Movies/Avora`; see [where screen recordings go](/blog/where-do-screen-recordings-go-on-mac).

## Tips for clearer voice-overs

- Use a headset or an external microphone if you can; the built-in mic picks up keyboard noise.
- With system audio on, keep notifications off (Focus mode) so alerts do not end up in the video.
- Record a 10-second test, stop, and listen before the real take.

## FAQ

### Why is there no sound in my Mac screen recording?

No microphone was chosen under Options, or you expected the Mac's own sound, which the built-in recorder only captures on macOS 27 Golden Gate with Include System Audio turned on.

### Can I record my voice and the Mac's sound at the same time?

Yes. On macOS 27, choose a microphone and turn on Include System Audio. Avora records both on separate tracks on macOS 14 and later.

## Related posts

- [Record Mac system audio without BlackHole](/blog/record-mac-system-audio-without-blackhole)
- [Record your screen with QuickTime Player](/blog/quicktime-screen-recording)
- [Add captions to a video on your Mac](/blog/add-captions-to-video-mac)
- [All posts](/blog/)

</div>
