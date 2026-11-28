---
title: "What Is an SRT File? Subtitle Format Explained"
titleTemplate: false
description: "An SRT file is a plain text subtitle file: numbered cues with start and end times. The format with an example, how to open and edit one, and how to make one."
headline: "SRT files: what they are and how they work"
date: "2026-11-28"
keyword: "what is a .srt file"
faq: [{"q": "What is an SRT file used for?", "a": "For subtitles or captions that sit next to a video instead of inside it. Players and video sites show the text at the times written in the file."}, {"q": "How do I open an SRT file?", "a": "With any text editor, such as TextEdit or Notepad, to read or edit it. To watch it with the video, give both files the same name and open the video in a player such as VLC."}, {"q": "Can I make an SRT file automatically?", "a": "Yes. Avora writes one from the speech in a screen recording when Save captions as an .srt file is on in its Captions settings."}]
---

<div class="post wrap">

# SRT files: what they are and how they work

<p class="post-meta">By <a href="https://halit.org">Halit Sever</a> · <time datetime="2026-11-28">28 November 2026</time></p>

<p class="lead">An .srt file holds subtitles as plain text, separate from the video. The name comes from SubRip, a program that extracted subtitles and their timings from DVDs into text files, and the format stuck because it is simple enough to read and edit by hand.</p>

## What is inside

An SRT file is a list of cues. Each cue has a number, a time range and one or more lines of text, followed by a blank line:

```text
1
00:00:01,200 --> 00:00:04,000
This is the new export panel.

2
00:00:04,500 --> 00:00:07,850
Pick a shape, then click Export.
```

- **The number** counts up from 1.
- **The times** are `hours:minutes:seconds,milliseconds`, with a comma before the milliseconds, and `-->` between start and end.
- **The text** is shown from the start time to the end time. A cue can have two lines.

There is no styling, font or position in the core format, which is why almost every player and video site can read it. The US Library of Congress describes it in its [format description for SubRip](https://www.loc.gov/preservation/digital/formats/fdd/fdd000569.shtml).

## SRT, burned-in captions and closed captions

- **Burned-in (open) captions** are drawn into the video frames. Everyone sees them and they cannot be turned off.
- **An .srt file** is a separate track. Players show it when the viewer turns captions on, it can be translated, and the text can be indexed. YouTube, for example, accepts .srt uploads for a video's captions.

## Open and edit an SRT file

It is text, so TextEdit opens it on a Mac (choose **Format › Make Plain Text** before saving) and Notepad on Windows. Keep the file encoded as UTF-8, so accented letters survive.

To play a video with it, give both files the same name, such as `demo.mp4` and `demo.srt`, in the same folder. Players such as VLC load the subtitles automatically.

## Make an SRT file

Typing timestamps by hand is slow. [Avora](/), a free and open source screen recorder for Mac, writes the file for you from what you said in the recording:

1. In Avora's **Settings…**, under **Captions**, turn on **Save captions as an .srt file**. Pick the language or keep **Same as this Mac**.
2. Record, then export. Avora transcribes the microphone track (or the Mac's sound, when no microphone was recorded) with Apple's speech recognition, on the Mac whenever the language supports it.
3. The .srt file is saved next to the video with the same name. Its times match the edited video, so cuts and speed changes are already taken into account.

To fix a misheard word first, open the take with **Edit Last Recording…** and edit the caption text. **Burn captions into the video** in the same section draws them into the frames instead, or as well. The step-by-step is in [add captions to a video on Mac](/blog/add-captions-to-video-mac). [Download Avora](https://github.com/halitsever/avora-screen-recorder/releases/latest).

## FAQ

### What is an SRT file used for?

For subtitles or captions that sit next to a video instead of inside it. Players and video sites show the text at the times written in the file.

### How do I open an SRT file?

With any text editor, such as TextEdit or Notepad, to read or edit it. To watch it with the video, give both files the same name and open the video in a player such as VLC.

### Can I make an SRT file automatically?

Yes. Avora writes one from the speech in a screen recording when Save captions as an .srt file is on in its Captions settings.

## Related posts

- [Convert a MOV file to MP4 on a Mac](/blog/mov-to-mp4-mac)
- [Editing a screen recording on a Mac](/blog/edit-screen-recording-mac)
- [Add captions to a video on your Mac](/blog/add-captions-to-video-mac)
- [All posts](/blog/)

</div>
