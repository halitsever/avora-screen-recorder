---
title: 'Mac Screen Recorder With Audio: Free, Open Source'
titleTemplate: false
description: Avora is free screen and audio recording software for Mac. It records your microphone and the Mac's own sound without BlackHole, plus camera, captions and zoom.
faq:
  - q: Does Avora record the Mac's own sound?
    a: Yes. Turn on Record system audio in Settings. Avora captures it with ScreenCaptureKit, so no virtual driver such as BlackHole is needed.
  - q: Which macOS version does Avora need?
    a: macOS 14 or later. Building it yourself needs Xcode 16 or later.
  - q: Why does macOS warn me when I open Avora?
    a: Avora is signed ad hoc and not notarized yet. Open it the first time with right-click, Open. After that it opens normally.
  - q: Which permissions does it ask for?
    a: Screen Recording on the first recording. The microphone, camera, captions and keyboard shortcuts each ask the first time you turn them on.
  - q: Is Avora really free?
    a: Yes. It is open source under the MIT license, with no account, watermark or time limit.
---

<DocSection id="top" kicker="Mac screen recorder with audio">

# Record your screen, your voice and your Mac's sound.

Avora is free, open source screen and audio recording software for Mac. It records your microphone and the sound your Mac plays, each on its own track, with no virtual audio driver to install. It also zooms in on your clicks, adds a camera bubble and writes captions, so the video is ready when you press stop.

<div class="ctas"><a class="btn primary" href="https://github.com/halitsever/avora-screen-recorder/releases/latest">Download Avora</a><a class="btn ghost" href="../blog/how-to-record-screen-and-audio-on-mac">How to record with sound</a></div>

<p class="meta">macOS 14+ · Free · MIT license</p>

</DocSection>

<DocSection id="audio" kicker="Sound">

## Voice and system audio, no BlackHole.

The Mac's built-in recorder only records the Mac's own sound from macOS 27 Golden Gate on, and for years the workaround was a virtual driver such as BlackHole. Avora records the system audio with Apple's ScreenCaptureKit on macOS 14 and later, and leaves its own sounds out.

<div class="cards">
<InfoCard title="Microphone">

Pick any microphone in **Settings…**. The **Voice** setting keeps it **As recorded**, brings it to an **Even level** with peaks at about −6 dBFS, or makes it **Clear** by removing background noise with Apple's voice isolation, all on the Mac.

</InfoCard>
<InfoCard title="System audio">

Turn on **Record system audio** to capture app sounds, music or a call. It is recorded on its own track and mixed with your voice when the video is exported.

</InfoCard>
</div>

</DocSection>

<DocSection id="features" kicker="What else it records">

## A finished video, not raw footage.

<div class="cards">
<InfoCard title="Auto zoom">

Every click zooms the video in on that spot and the camera follows the area you work in, easing in and out on springs with motion blur. [How it works](../blog/auto-zoom-screen-recording).

</InfoCard>
<InfoCard title="Camera bubble">

You in a corner, square or wide, rounded or circular, shrinking out of the way when the screen zooms. Or side by side with the screen, or full frame for a while. Lined up with your voice after recording.

</InfoCard>
<InfoCard title="Captions">

Written on the Mac from what you say, burned into the video, saved as .srt, or both. Fix any word in the editor first.

</InfoCard>
<InfoCard title="Screen, window or area">

Record the whole display, one window that stays in the video when other windows cover it, or an area you drag out. Start and stop with ⌃⌥⌘R from any app, pause with ⌃⌥⌘P.

</InfoCard>
<InfoCard title="Editor">

Cut, split and speed up clips, move or add zooms, blur private details with Auto Blur, crop, and undo anything.

</InfoCard>
<InfoCard title="Export">

MP4 (H.264 or HEVC), ProRes 422 HQ or GIF, up to 4K, in the recording's own shape or 16:9, 4:3, 1:1, 4:5, 3:4 or 9:16. Saved to `~/Movies/Avora` or copied to the clipboard.

</InfoCard>
</div>

</DocSection>

<DocSection id="compare" kicker="Compared">

## Avora and the other ways to record.

| | Avora | Screenshot toolbar and QuickTime | OBS Studio | Screen Studio |
| --- | --- | --- | --- | --- |
| Price | Free, open source | Free, built in | Free, open source | Paid subscription |
| Microphone | Yes | Yes | Yes | Yes |
| Mac's own sound | Yes, macOS 14+ | macOS 27 Golden Gate+ | Yes, macOS 13+ | Yes |
| Camera | Bubble, side by side or full frame | No | As a scene source | Yes |
| Captions | Yes, on the Mac | No | No | Yes |
| Auto zoom on clicks | Yes | No | No | Yes |
| Live streaming | No | No | Yes | No |
| Shareable links | No | No | No | Yes |

Built-in tools per Apple's macOS 27 documentation, OBS per its [knowledge base](https://obsproject.com/kb/macos-desktop-audio-capture-guide), Screen Studio per [screen.studio](https://screen.studio/), as of November 2026. More detail in [OBS alternatives for Mac](../blog/obs-alternatives-for-mac) and the [Screen Studio comparison](../screen-studio-alternative).

</DocSection>

<DocSection id="start" kicker="Get started">

## Three steps to your first recording.

1. [Download `Avora.zip`](https://github.com/halitsever/avora-screen-recorder/releases/latest), unzip it and move Avora to Applications. Open it the first time with right-click, **Open**.
2. In **Settings…**, choose your microphone and turn on **Record system audio**.
3. Press ⌃⌥⌘R, record, and press it again to stop. Allow Screen Recording when macOS asks.

</DocSection>

<DocSection id="faq" kicker="FAQ">

## Questions.

### Does Avora record the Mac's own sound?

Yes. Turn on **Record system audio** in **Settings…**. Avora captures it with ScreenCaptureKit, so no virtual driver such as BlackHole is needed.

### Which macOS version does Avora need?

macOS 14 or later. Building it yourself needs Xcode 16 or later.

### Why does macOS warn me when I open Avora?

Avora is signed ad hoc and not notarized yet. Open it the first time with right-click, **Open**. After that it opens normally.

### Which permissions does it ask for?

Screen Recording on the first recording. The microphone, camera, captions and keyboard shortcuts each ask the first time you turn them on.

### Is Avora really free?

Yes. It is open source under the MIT license, with no account, watermark or time limit.

</DocSection>
