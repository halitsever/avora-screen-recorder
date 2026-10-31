---
title: Avora
titleTemplate: Screen recorder that zooms in on what you click
---

<HeroSection>

<p class="eyebrow">Open source screen recorder for macOS</p>

# Every click,<br><span class="hl">in close&#8209;up.</span>

Avora records your screen and zooms in on what you click. Press stop and a finished video lands in your Movies folder.

<div class="ctas"><a class="btn primary" href="#install">Build from source</a><a class="btn ghost" href="#zoom">How the zoom works ↓</a></div>

<p class="meta">macOS 14+ · Swift · MIT</p>

</HeroSection>

<UsingSection id="using" kicker="Using Avora">

## Lives in your<br>menu bar.

Choose **Record Screen**, do your thing, then **Stop Recording**, or press **⌃⌥⌘R** from any app to do both. **⌃⌥⌘P** pauses and resumes. The video is saved to `~/Movies/Avora` and Finder opens on it.

- **Screen, window or area.** Pick what to record under **Capture** in the menu or in Avora's window. A window or area is chosen on a dimmed overlay: click a window, or drag out an area and press Return. A window is recorded as the area it covers, so moving it during the recording is not followed.
- **Sound.** Turn on your microphone and the Mac's own sound in **Settings…**. Each is kept on its own track while recording and mixed when the video is exported, with your voice evened out to a steady level.
- **Edit the zooms.** **Edit Last Recording…** opens the zoom editor: drag zooms along the timeline, resize them, add or remove them, change how far each one zooms in and pin its focus to a spot. **Export** saves a new video. The video from the recording is saved either way, and Settings can open the editor after every recording.
- **Its own window too.** It opens when you launch the app and again from **Open Avora…** in the menu. It previews the backdrop and has the same controls. Avora shows a Dock icon while a window is open and goes back to the menu bar when you close it.
- **Permissions.** The first recording asks for Screen Recording access, and the microphone asks the first time you use it.

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

Pick a backdrop in the window or from the **Background** submenu in the menu bar. The choice applies to every video after it. The id under each name is what `--background` takes.

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

`--format` takes `h264`, `hevc`, `prores` or `gif`, and `--motion-blur` a number from 0 to 1. Anything left out uses what is picked in the app.

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

**Settings…** changes the export: MP4 (H.264 or HEVC), ProRes 422 HQ or GIF, resolution, frame rate, quality, zoom level, motion blur, padding, corners, shadow, cursor size and cursor smoothing.

<CardGrid>
<FileTree :rows="[['Sources/', ''], ['ZoomEngine/', 'zoom windows, focus regions, framing, springs, motion trails, zoom edits, the per-frame director', true], ['Avora/', 'menu bar app, windows, editor, capture, audio, input log, renderer, exporter', true], ['Resources/', 'Info.plist, app icon, menu bar icon, logo, Sora font'], ['Tests/', 'the engine, backgrounds and preferences']]" />
<InfoCard title="Not done yet">

- Following a window that moves while it is recorded
- An audio waveform in the editor

</InfoCard>
</CardGrid>

</DocSection>
