---
title: "Auto Zoom in Screen Recordings: How It Works"
titleTemplate: false
description: "How a screen recorder with auto zoom decides where and when to zoom: click windows, focus regions, springs, motion blur and a cursor drawn after recording."
headline: "How does auto zoom work in a screen recording?"
date: "2026-11-28"
keyword: "screen recorder with auto zoom"
faq: [{"q": "What is auto zoom in a screen recorder?", "a": "The recorder zooms the video in on the area you click and follows your work, then zooms back out, so the result looks edited without manual keyframes."}, {"q": "Can I turn off or change the automatic zooms?", "a": "Yes. In Avora's editor you can remove, move, resize or add zooms, change their level from 1x to 4x and pin their focus."}]
---

<div class="post wrap">

# How does auto zoom work in a screen recording?

<p class="post-meta">By <a href="https://halit.org">Halit Sever</a> · <time datetime="2026-11-28">28 November 2026</time></p>

<p class="lead">Auto zoom makes a screen recording look edited: the view moves in on what you click and pulls back out when you move on. Here is how Avora decides when and where to zoom, from the code in its open source ZoomEngine.</p>

## 1. Record the screen, not the cursor

While recording, Avora captures the display without the pointer. Separately it logs the cursor position and mouse buttons 120 times a second and keeps a copy of every cursor image it sees. The cursor is drawn back in later, which is what makes zooming and smoothing possible: a cursor baked into the video could not be moved or enlarged.

## 2. A click opens a zoom window

Each click creates a window from 0.3 seconds before it to 2.5 seconds after. Starting before the click means the view is already moving when the click happens, so the viewer sees what you are about to click. Windows less than 2.5 seconds apart merge into one zoom, so a burst of clicks becomes one steady zoom instead of a series of jumps.

## 3. Follow regions, not every movement

Inside a zoom, the view should not chase every twitch of the mouse. Avora groups cursor positions into regions no larger than half of the zoomed view and aims at the center of the current region, weighted by how long the cursor stayed at each spot. Small movements inside a region keep the view still; moving to a different part of the screen pans to the next region.

## 4. Springs ease it in and out

The screen and the cursor reach their targets through damped springs, simulated in 1 ms steps. That gives the ease-in and ease-out that makes the motion feel deliberate. Motion blur then smears whatever moves within a frame: the zoom, the pan and the cursor. It can be set from 0 to 100%.

## 5. Keep the edges filled

Zooming in near a screen edge could show empty space beyond the screen. Avora slides the zoomed view back until it covers the frame again, so the video never shows a gap.

## 6. Draw the cursor, smoothly

Because the cursor is drawn after recording, Avora can make it larger (1.5 times by default), smooth its path with a spring (**Smooth**, **Medium**, **Rapid** or none), add a circle or ripple on clicks, fade it when idle and hold it still at the end.

## You stay in control

The automatic zooms are a starting point. In the editor (**Edit Last Recording…**, <kbd>Command</kbd> <kbd>E</kbd>) you can move, resize, add and remove zooms, set each one's level from 1x to 4x, and pin its focus to a spot instead of following the cursor. <kbd>Z</kbd> adds a zoom at the playhead. Edits are saved next to the raw recording and used by every later export.

## Try it

The [interactive explainer on the home page](/#zoom) scrubs through a recording step by step. The zoom logic lives in `Sources/ZoomEngine` with no UI code, so `swift test` covers it, and you can read it on [GitHub](https://github.com/halitsever/avora-screen-recorder/tree/main/Sources/ZoomEngine). [Download Avora](https://github.com/halitsever/avora-screen-recorder/releases/latest); it needs macOS 14 or later.

## FAQ

### What is auto zoom in a screen recorder?

The recorder zooms the video in on the area you click and follows your work, then zooms back out, so the result looks edited without manual keyframes.

### Can I turn off or change the automatic zooms?

Yes. In Avora's editor you can remove, move, resize or add zooms, change their level from 1x to 4x and pin their focus.

## Related posts

- [How to screen record on Mac](/blog/how-to-screen-record-on-mac)
- [OBS alternatives for Mac, compared](/blog/obs-alternatives-for-mac)
- [Record your screen to a GIF on Mac](/blog/screen-recording-to-gif-mac)
- [All posts](/blog/)

</div>
