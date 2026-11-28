---
title: "Where Do Screen Recordings Go on Mac?"
titleTemplate: false
description: "Mac screen recordings are saved to the desktop as .mov files by default. How to find them, change where they go, and where Avora keeps its recordings."
headline: "Where do screen recordings go on Mac?"
date: "2026-11-28"
keyword: "where do screen recordings go on mac"
faq: [{"q": "Where are QuickTime screen recordings saved?", "a": "QuickTime's New Screen Recording uses the Screenshot toolbar, so recordings go to the desktop or the place chosen under Options, Save to."}, {"q": "Why is my screen recording not on the desktop?", "a": "The thumbnail may still be showing, Save to may point to another folder, or the recording was not stopped. Search Finder for Screen Recording."}]
---

<div class="post wrap">

# Where do screen recordings go on Mac?

<p class="post-meta">By <a href="https://halit.org">Halit Sever</a> · <time datetime="2026-11-28">28 November 2026</time></p>

<p class="lead">A Mac saves screen recordings to the desktop by default, as .mov files whose names start with "Screen Recording" and include the date and time. Here is how to find them, how to change the location, and where Avora puts its videos.</p>

## The default: the desktop

Recordings made with the Screenshot toolbar (<kbd>Shift</kbd> <kbd>Command</kbd> <kbd>5</kbd>) or QuickTime Player's **New Screen Recording** are saved to the desktop, in the **Desktop** folder of your home folder (`~/Desktop`). A thumbnail appears in the corner for a few seconds after you stop; the file is written when it goes away, or when you click it.

The macOS steps were checked against Apple's [macOS User Guide](https://support.apple.com/guide/mac-help/take-screenshots-or-screen-recordings-mh26782/mac) for macOS 27 Golden Gate and [Apple's screen recording guide](https://support.apple.com/en-us/102618) in November 2026.

## Change where they are saved

1. Press <kbd>Shift</kbd> <kbd>Command</kbd> <kbd>5</kbd>.
2. Click **Options**.
3. Under **Save to**, pick a preset place such as Documents, or **Other Location** to choose any folder.

The setting is shared with screenshots, so both go to the new place.

## Find a recording you lost

- Search Finder or Spotlight for `Screen Recording`.
- Open Finder's **Recents**, which lists recently created files.
- If **Desktop & Documents Folders** is on in iCloud Drive, your desktop is in iCloud Drive, and the recording is there.
- Check that you actually stopped it: an unstopped recording is not saved. See [how to stop a screen recording](/blog/how-to-stop-screen-recording-on-mac).

## Where Avora saves recordings

[Avora](/) keeps two kinds of files:

| What | Where | How long |
| --- | --- | --- |
| Finished videos | `~/Movies/Avora`, named like `Avora 2026-11-28 at 10.15.32.mp4` | Until you delete them |
| Raw recordings | `~/Library/Application Support/Avora/Recordings` | 7 days |

**Finished videos** are what you share. The extension follows the export format: `.mp4` for H.264 and HEVC, `.mov` for ProRes 422 HQ, `.gif` for GIF. **Open Videos Folder** in the menu bar menu opens the folder. Under **Settings… › After Recording**, choose **Show in Finder**, **Copy to clipboard** or **Show and copy**. A copied video pastes straight into a chat or an email, and no searching is needed.

**Raw recordings** hold the screen video, the cursor and click data, the audio tracks and the camera, before any zoom or backdrop is applied. They let you open a take again with **Edit Last Recording…** (<kbd>Command</kbd> <kbd>E</kbd>) and export it with a different look. Avora deletes them after 7 days; **Clear Raw Recordings** in the menu removes them sooner and shows how much space they use. Developers can render one again from the command line with `Avora render`, as shown on the [home page](/#install).

## FAQ

### Where are QuickTime screen recordings saved?

QuickTime's New Screen Recording uses the Screenshot toolbar, so recordings go to the desktop or the place chosen under Options, Save to.

### Why is my screen recording not on the desktop?

The thumbnail may still be showing, Save to may point to another folder, or the recording was not stopped. Search Finder for Screen Recording.

## Related posts

- [How to stop a screen recording on Mac](/blog/how-to-stop-screen-recording-on-mac)
- [Record your screen to a GIF on Mac](/blog/screen-recording-to-gif-mac)
- [Convert a MOV file to MP4 on a Mac](/blog/mov-to-mp4-mac)
- [All posts](/blog/)

</div>
