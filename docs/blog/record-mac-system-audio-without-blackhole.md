---
title: "Record Mac System Audio Without BlackHole"
titleTemplate: false
description: "Why people install BlackHole to screen record with audio on Mac, how the Multi-Output setup works, and the ways to record system audio with no virtual driver."
headline: "Record Mac system audio without BlackHole"
date: "2026-11-28"
keyword: "screen recording with audio mac black hole"
faq: [{"q": "Do I need BlackHole to record system audio on Mac?", "a": "Not any more in many cases. macOS 27 Golden Gate's Screenshot toolbar has Include System Audio, and apps built on ScreenCaptureKit, such as OBS 30+ and Avora, capture it directly."}, {"q": "Why can't I hear anything while recording with BlackHole?", "a": "The Mac's output is going only to BlackHole. Create a Multi-Output Device in Audio MIDI Setup that includes your speakers as well."}]
---

<div class="post wrap">

# Record Mac system audio without BlackHole

<p class="post-meta">By <a href="https://halit.org">Halit Sever</a> · <time datetime="2026-11-28">28 November 2026</time></p>

<p class="lead">For years, recording the Mac's own sound meant installing BlackHole, a free virtual audio driver, and rerouting the Mac's output through it. Recent macOS versions let apps capture system audio directly, so that detour is often no longer needed.</p>

## Why BlackHole became the standard answer

Before macOS 27, the Screenshot toolbar and QuickTime Player recorded the screen and a microphone, but not the sound coming out of the Mac. Apps could not simply listen to the system output. [BlackHole](https://github.com/ExistentialAudio/BlackHole) is an open source virtual audio driver that works around it: it shows up as both an output and an input device, so whatever you send to it can be recorded as if it were a microphone.

## The BlackHole setup, in short

1. Install BlackHole (the 2-channel version is enough for most recordings).
2. Open **Audio MIDI Setup**, click **+** and create a **Multi-Output Device** that includes your speakers or headphones and BlackHole.
3. Set that Multi-Output Device as the Mac's sound output, so you hear the audio and BlackHole receives a copy.
4. In the recorder, choose **BlackHole** as the microphone.

It works, but it has costs: the volume keys do not control a Multi-Output Device, you must switch the output back after recording, and recording your voice at the same time needs an Aggregate Device that combines the real microphone with BlackHole.

## Option 1: the built-in recorder on macOS 27

On macOS 27 Golden Gate, the Screenshot toolbar's **Options** menu has **Include System Audio**. Press <kbd>Shift</kbd> <kbd>Command</kbd> <kbd>5</kbd>, open **Options**, turn it on, pick a microphone if you want your voice too, and record. No driver, no Multi-Output Device. On macOS 26 and earlier this option is not there.

The macOS steps were checked against Apple's [macOS User Guide](https://support.apple.com/guide/mac-help/take-screenshots-or-screen-recordings-mh26782/mac) for macOS 27 Golden Gate and [Apple's screen recording guide](https://support.apple.com/en-us/102618) in November 2026.

## Option 2: an app that uses ScreenCaptureKit

Apple's ScreenCaptureKit framework, available to apps since macOS 13, can capture the audio of the whole system or of single apps together with the screen. Recorders built on it need no virtual driver:

- **OBS Studio** 30 and later on macOS 13 or later has a **macOS Audio Capture** source, and its **macOS Screen Capture** source captures audio too, according to the [OBS knowledge base](https://obsproject.com/kb/macos-desktop-audio-capture-guide).
- **[Avora](/)** records the Mac's audio with ScreenCaptureKit and leaves out its own sounds. Turn on **Record system audio** in **Settings…**.

## Recording the Mac's sound and your voice with Avora

Avora (macOS 14 or later, free and open source) handles both sources without any routing:

- The **Microphone** picker in **Settings…** chooses your mic; **Record system audio** adds the Mac's sound.
- Each source is recorded on its own track and mixed when the video is exported, so one cannot drown the other while you record.
- The **Voice** setting processes the microphone on the Mac at export: **As recorded**, **Even level** (brings the voice to a steady level, with peaks at about −6 dBFS) or **Clear**, which removes background noise with Apple's voice isolation.

Then record as usual with <kbd>Control</kbd> <kbd>Option</kbd> <kbd>Command</kbd> <kbd>R</kbd>. If you already set up BlackHole for another app, Avora does not need it; set your Mac's output back to your speakers. The step-by-step version, with camera and captions, is in [how to record screen and audio on Mac](/blog/how-to-record-screen-and-audio-on-mac).

## FAQ

### Do I need BlackHole to record system audio on Mac?

Not any more in many cases. macOS 27 Golden Gate's Screenshot toolbar has Include System Audio, and apps built on ScreenCaptureKit, such as OBS 30+ and Avora, capture it directly.

### Why can't I hear anything while recording with BlackHole?

The Mac's output is going only to BlackHole. Create a Multi-Output Device in Audio MIDI Setup that includes your speakers as well.

## Related posts

- [How to screen record on Mac](/blog/how-to-screen-record-on-mac)
- [How to record screen and audio on Mac](/blog/how-to-record-screen-and-audio-on-mac)
- [OBS alternatives for Mac, compared](/blog/obs-alternatives-for-mac)
- [All posts](/blog/)

</div>
