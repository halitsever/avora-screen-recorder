---
title: "How to Blur Faces in a Video on Mac"
titleTemplate: false
description: "Blur faces, email addresses and card numbers in a video on Mac: what iMovie and QuickTime cannot do, and how Avora finds and blurs them on your Mac."
headline: "Blur faces and private details in a screen recording"
date: "2026-11-28"
keyword: "how to blur faces in video"
faq: [{"q": "Can iMovie blur faces?", "a": "iMovie has no blur that follows a face. Use an editor with tracking, or a tool that detects faces for you, such as Avora's Auto Blur."}, {"q": "Is the video uploaded to blur faces?", "a": "Not with Avora. It finds faces and text with Apple's Vision framework on your Mac."}, {"q": "Does automatic blurring catch everything?", "a": "No detector is perfect. Watch the video before sharing and add a blur by hand where one is missing."}]
---

<div class="post wrap">

# Blur faces and private details in a screen recording

<p class="post-meta">By <a href="https://halit.org">Halit Sever</a> · <time datetime="2026-11-28">28 November 2026</time></p>

<p class="lead">A screen recording can show more than you meant to share: a face on a video call, an email address in a sidebar, a card number in a form. Blurring them means placing a blur over the area for as long as it is visible, and moving it if the thing moves.</p>

## What the built-in apps can do

QuickTime Player can trim, split, rotate and remove audio or video, but it has no blur. iMovie, Apple's free editor, does not have a blur that tracks a face either. That leaves two options: an editor with masks or tracking, or a recorder that blurs on export.

## Blur automatically with Avora

[Avora](/) is a free, open source screen recorder for Mac (macOS 14 or later). Its editor can look through a recording and blur private things for you, using Apple's Vision framework on your Mac. Nothing is uploaded.

1. Record as usual, then choose **Edit Last Recording…** (<kbd>Command</kbd> <kbd>E</kbd>) from Avora's menu bar menu.
2. Click **Auto Blur** in the editor's toolbar and choose:
   - **Blur Faces** to find faces on screen. Avora reads two frames per second.
   - **Blur Private Info** to find email addresses, phone numbers, card numbers (checked with the Luhn digit check), IBANs (checked with their checksum) and keys or tokens, such as API keys. Text is read once per second, and a frame that has not changed reuses the previous result.
3. Each find becomes a blur on the timeline in the **Blur & highlight** lane. Sightings of the same thing in nearby frames are joined into one blur, which starts a moment early and ends a moment late, because the thing may have appeared between two frames that were read.
4. Check the results, delete a blur you do not want, and export.

If nothing is found, Avora says so, for example "No faces were found on screen."

## Add or adjust a blur by hand

Automatic detection can miss a face in profile or text in an unusual font, so look through the video before you share it. In the **Blur & highlight** lane, **Add Blur** places a new area that you resize and time with the playhead (**Start at Playhead**, **End at Playhead**). A mask can also be a **Highlight**, which keeps the area bright and dims the rest. Blurs fade in and out at their ends, and the blur is strong enough that text under it cannot be read back.

## Before you share

- Watch the export once at full size. A blur that is a few frames late shows exactly what you wanted to hide.
- Blur what the camera bubble shows too, if other people walk behind you.
- If someone else appears in the recording, ask them before you share it.

The rest of the editor, from cutting clips to speeding up typing, is in [how to edit a screen recording on Mac](/blog/edit-screen-recording-mac). [Download Avora](https://github.com/halitsever/avora-screen-recorder/releases/latest).

## FAQ

### Can iMovie blur faces?

iMovie has no blur that follows a face. Use an editor with tracking, or a tool that detects faces for you, such as Avora's Auto Blur.

### Is the video uploaded to blur faces?

Not with Avora. It finds faces and text with Apple's Vision framework on your Mac.

### Does automatic blurring catch everything?

No detector is perfect. Watch the video before sharing and add a blur by hand where one is missing.

## Related posts

- [How to screen record on Mac](/blog/how-to-screen-record-on-mac)
- [Editing a screen recording on a Mac](/blog/edit-screen-recording-mac)
- [Add captions to a video on your Mac](/blog/add-captions-to-video-mac)
- [All posts](/blog/)

</div>
