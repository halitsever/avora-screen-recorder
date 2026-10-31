# How Avora works

## Using Avora

Avora lives in the menu bar. Choose **Start Recording**, do your thing, then **Stop Recording**. The video is saved to `~/Movies/Avora` and Finder opens on it. The first recording asks for Screen Recording permission.

Avora also has its own window. It opens when you launch the app and again from **Open Avora…** in the menu. It previews the backdrop, offers twelve preset backgrounds and has the same record and folder controls. Avora shows a Dock icon while the window is open and goes back to living only in the menu bar when you close it.

The build script signs the app ad hoc. macOS ties the permission to the signature, so after a rebuild you may have to switch Avora off and on again in System Settings. Set `SIGN_IDENTITY` to a certificate from your keychain to keep the permission across builds.

## Backgrounds

Pick a backdrop in the window or from the **Background** submenu in the menu bar. The choice applies to every video after it. The presets and their ids:

| Id | Look |
| --- | --- |
| `avora` | Avora orange to peach (default) |
| `ember` | Dark brown to Avora orange |
| `grove` | Leaf green to ink |
| `studio` | Dark grey radial glow |
| `sand` | Warm brown radial glow |
| `aurora` | Purple and blue spots on near black |
| `iris` | Blue violet to purple |
| `blossom` | Pink to coral |
| `sky` | Blue to cyan |
| `mint` | Green to aqua |
| `sunset` | Orange to magenta |
| `indigo` | Sky blue to violet |

## Re-rendering a recording

Raw recordings stay in `~/Library/Application Support/Avora/Recordings`. Each folder holds the screen video, `input.json` with cursor and click data, and the captured cursor images. Render one again with:

```sh
swift build -c release
.build/release/Avora render "<recording folder>" out.mp4 --background sky
```

Without `--background` the render uses the background picked in the app.

## How the automatic zoom works

1. While recording, Avora captures the display without the cursor. It logs the cursor position and mouse buttons 120 times a second and keeps a copy of every cursor image it sees.
2. Each click opens a zoom window from 0.3 s before the click to 2.5 s after it. Windows less than 2.5 s apart merge, so a burst of clicks becomes one continuous zoom.
3. Inside a zoom the camera ignores small cursor movements. Cursor positions are grouped into regions no larger than half of the zoomed view. The camera aims at the center of the current region, weighted by how long the cursor stayed at each spot, and moves only when the cursor leaves the region.
4. The zoomed screen is kept large enough to cover its resting frame, so zooming near an edge never shows empty space.
5. The screen and the cursor reach their targets through damped springs simulated in 1 ms steps. That produces the smooth ease in and out.

The logic is plain Swift in `Sources/ZoomEngine` and has tests:

```sh
swift test
```

## Project layout

- `Sources/ZoomEngine`: zoom windows, focus regions, framing, springs and the per-frame director. No UI code.
- `Sources/Avora`: menu bar app, main window, background presets, screen capture, input logging, Core Image renderer and exporter.
- `Resources`: `Info.plist`, brand assets (app icon, menu bar icon, logo) and the Sora font.
- `Tests/ZoomEngineTests`, `Tests/AvoraTests`: tests for the engine and for backgrounds and preferences.

## Not done yet

Audio, motion blur and an editor for adjusting zooms by hand.
