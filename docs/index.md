---
title: Avora
titleTemplate: Screen recordings that come out finished
---

<HeroSection>

<p class="eyebrow">Open source screen recorder for macOS</p>

# Your screen,<br><span class="hl">already edited.</span>

Avora records your Mac and hands back a polished video, with smooth zooms, a clean cursor, sound and a backdrop already in place. Press stop and it is ready to share.

<div class="ctas"><a class="btn primary" href="#install">Build from source</a><a class="btn ghost" href="#using">See what it does ↓</a></div>

<p class="meta">macOS 14+ · Swift · MIT</p>

</HeroSection>

<UsingSection id="using" kicker="Using Avora">

## Lives in your<br>menu bar.

Choose **Record Screen**, do your thing, then **Stop Recording**, or press **⌃⌥⌘R** from any app to do both. **⌃⌥⌘P** pauses and resumes, and **⌃⌥⌘⌫** throws the take away and starts again. The video is saved to `~/Movies/Avora` and Finder opens on it, or it goes straight to the clipboard, ready to paste into a chat.

- **Screen, window or area.** Pick what to record under **Capture** in the menu or in Avora's window. A window or area is chosen on a dimmed overlay: click a window, or drag out an area and press Return. A window is recorded on its own, so it stays in the video when you move it or other windows cover it.
- **Sound.** Turn on your microphone and the Mac's own sound in **Settings…**. Each is kept on its own track while recording and mixed on export. Your voice is evened out, or cleaned of background noise with Apple's voice isolation, all on the Mac.
- **Camera.** Pick a camera and you show up in a bubble in the corner of the video: square or wide, rounded or circular, in any corner, shrinking out of the way when the screen zooms in. In the editor you can put yourself next to the screen, or stacked under it in a tall video, or fill the whole frame for a while. A small preview floats on screen while you record, and it never ends up in the video. When you stop, Avora watches your lips and lines the picture up with your voice.
- **Captions.** Avora writes captions from what you say, on the Mac. Burn them into the video, save them as an .srt file, or both, and fix any word in the editor first.
- **Keyboard.** Turn on **Show keyboard shortcuts** and the shortcuts you press appear as a badge near the bottom of the video. Turn on **Note when you type** and **Speed Up Typing** in the editor plays every stretch of steady typing at 3×. Avora keeps only when keys were pressed, never which ones.
- **The editor.** The editor opens on its own once a recording is saved, and **Edit Last Recording…** brings it back. Turn that off under **After Recording** in **Settings…**. Cut, split and speed up clips with voices keeping their pitch; move, resize and add zooms or pin their focus; blur or highlight part of the screen for a while; hide the cursor or the camera where they get in the way; crop the recording; edit captions. **Auto Blur** reads the screen on the Mac and blurs email addresses, phone and card numbers, IBANs, API keys or faces wherever they show up. Everything can be undone, and **Export** saves a new video, copies it, or saves a single frame.
- **Its own window too.** **Open Avora…** in the menu opens it, as does opening the app again while it runs. It previews the backdrop around a sample desktop and has the same controls. Avora shows a Dock icon while a window is open and goes back to the menu bar when you close it.
- **Permissions.** The first recording asks for Screen Recording access. The microphone, camera, captions and keyboard shortcuts each ask the first time you turn them on.
- **Crash safe.** Recordings are saved as they go. If Avora stops in the middle of one, it offers to turn what was saved into a video the next time it opens.

</UsingSection>

<ZoomStory id="zoom" kicker="The automatic zoom" title="Scroll to scrub a recording." :labels="['Record', 'Click', 'Follow', 'Ease', 'Edges']">

<ZoomChapter title="It records the screen, not the cursor.">

While recording, Avora captures the display without the pointer. It logs the cursor position and mouse buttons 120 times a second and keeps a copy of every cursor image it sees.

</ZoomChapter>

<ZoomChapter title="A click opens a zoom window.">

Each window runs from 0.3 s before the click to 2.5 s after it, so the camera is already moving when you click.

</ZoomChapter>

<ZoomChapter title="It follows regions, not jitter.">

Windows less than 2.5 s apart merge into one zoom. Cursor positions are grouped into regions no larger than half the zoomed view, and the camera aims at the center of the current one, weighted by how long the cursor stayed at each spot.

</ZoomChapter>

<ZoomChapter title="Springs ease it in and out.">

The screen and the cursor reach their targets through damped springs simulated in 1 ms steps. That gives the smooth ease in and out, and motion blur smears whatever moves within a frame.

</ZoomChapter>

<ZoomChapter title="Edges stay filled.">

Near an edge the zoomed screen slides back until it covers its resting frame again, so the frame never shows a gap.

</ZoomChapter>

</ZoomStory>

<DocSection id="backgrounds" kicker="Backgrounds">

## Twelve backdrops.<br>Pick one, it sticks.

Pick a backdrop in the window or from the **Background** submenu in the menu bar, or use a solid color, a picture of your own or your desktop wallpaper from **Settings…**, blurred as much as you like. The choice applies to every video after it. The id under each name is what `--background` takes, along with `color:RRGGBB`, `image:<path>` and `wallpaper`.

<BackgroundPicker />

</DocSection>

<DocSection id="install" kicker="Install">

## Build it from source.

Avora needs macOS 14 or later and Xcode 16 or later. Run the tests with `swift test`.

<CardGrid>
<TypedTerminal :lines="[['$ ', 'git clone https://github.com/halitsever/avora-screen-recorder'], ['$ ', 'cd avora-screen-recorder'], ['$ ', './scripts/build-app.sh'], ['', '# build/Avora.app is ready'], ['$ ', 'open build/Avora.app']]" />
<div class="cards">
<InfoCard title="Re-render a recording">

Raw recordings stay in `~/Library/Application Support/Avora/Recordings` for 7 days, and **Clear Raw Recordings** in the menu removes them sooner. Each folder holds the screen video, `input.json` with cursor and click data, and the captured cursor images. Render one again with:

```sh
swift build -c release
.build/release/Avora render "<recording folder>" out.mp4 --background sky
```

`--format` takes `h264`, `hevc`, `prores` or `gif`, `--preset` the name of a saved look, and `--setting key=value` any single setting, such as `aspect=vertical` or `clickEffect=ripple`. Anything left out uses what is picked in the app, and edits made in the editor always apply.

</InfoCard>
<InfoCard title="Keep the permission">

The build script signs the app ad hoc. macOS ties the permission to the signature, so after a rebuild you may have to switch Avora off and on again in System Settings. Set `SIGN_IDENTITY` to a certificate from your keychain to keep the permission across builds.

</InfoCard>
</div>
</CardGrid>

</DocSection>

<DocSection id="hood" kicker="Under the hood">

## Plain Swift, tested.

The zoom logic lives in `Sources/ZoomEngine` with no UI code, and `swift test` covers it.

**Settings…** changes the export: MP4 (H.264 or HEVC), ProRes 422 HQ or GIF; 16:9, square, 4:5 or 9:16 shapes as well as the recording's own, where a zoom fills the whole frame; resolution, frame rate and quality; zoom level, motion blur, padding, corners and shadow; the cursor's size, smoothing, click effect and fading when idle. A look can be saved as a preset and used again.

<CardGrid>
<FileTree :rows="[['Sources/', ''], ['ZoomEngine/', 'zoom windows, focus regions, framing, springs, motion trails, timeline edits, the per-frame director', true], ['Avora/', 'menu bar app, windows, editor, capture, camera, audio, captions, renderer, exporter', true], ['Resources/', 'Info.plist, app icon, menu bar icon, logo, Sora font'], ['Tests/', 'the engine, backgrounds and preferences']]" />
<InfoCard title="Not done yet">

- Downloads signed for macOS; build from source for now

</InfoCard>
</CardGrid>

</DocSection>
