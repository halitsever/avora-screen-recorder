/**
 * The rules of Sources/ZoomEngine, ported to play a scripted recording in the browser.
 * The constants mirror ZoomConfig, SpringConfig and OutputStyle; keep them in step.
 */

export interface Point { x: number; y: number }
export interface Rect { x: number; y: number; w: number; h: number }
export interface Region { t0: number; t1: number; x0: number; x1: number; y0: number; y1: number; cx: number; cy: number }
export interface Segment { start: number; end: number; regions: Region[] }
export interface Frame extends Rect { cursor: Point; region: Region | null }
interface Spring { mass: number; stiffness: number; damping: number }

export const SOURCE = { width: 1280, height: 800 }
export const DURATION = 12
export const FPS = 60
/** The screen's resting frame as a fraction of the canvas, inside OutputStyle's 6% padding. */
export const BASE: Rect = { x: 0.06, y: 0.06, w: 0.88, h: 0.88 }
export const CURSOR_SCALE = 1.5
export const BACKGROUND_PARALLAX = 0.125

const config = { scale: 2, leadIn: 0.3, hold: 2.5, mergeGap: 2.5, ignoreClicksInLast: 1, endMargin: 0.8 }
const screenSpring: Spring = { mass: 2.25, stiffness: 250, damping: 40 }
const cursorSpring: Spring = { mass: 3, stiffness: 470, damping: 70 }

/** Pointer stops in source pixels as [time, x, y]. The pointer eases between them. */
const path: [number, number, number][] = [
  [0, 880, 560], [0.5, 880, 560], [1.15, 134, 160], [1.6, 138, 162], [2.05, 140, 165],
  [2.75, 325, 407], [3.15, 327, 406], [3.7, 350, 398], [4.2, 392, 402], [4.8, 384, 420], [5.3, 410, 414],
  [6.3, 640, 520], [7.6, 930, 300], [8.35, 1158, 74], [8.9, 1160, 76], [9.6, 1085, 150], [10.4, 1070, 236], [12, 1068, 238],
]

/** Select Today in the sidebar, tick a task, then open Share near the top edge. */
export const CLICK_TIMES = [1.3, 3.0, 8.6]
/** Where each chapter of the walkthrough starts on the recording. */
export const CHAPTER_STARTS = [0, 1.0, 2.6, 5.5, 8.3]

export const clamp = (value: number, low: number, high: number) => Math.min(high, Math.max(low, value))
const smooth = (s: number) => s * s * (3 - 2 * s)

export function cursorAt(t: number): Point {
  const last = path[path.length - 1]
  if (t >= last[0]) return { x: last[1], y: last[2] }
  const i = Math.max(path.findIndex(p => p[0] > t) - 1, 0)
  const [t0, x0, y0] = path[i], [t1, x1, y1] = path[i + 1]
  const s = smooth(clamp((t - t0) / (t1 - t0), 0, 1))
  return { x: x0 + (x1 - x0) * s, y: y0 + (y1 - y0) * s }
}

export const clicks = CLICK_TIMES.map(t => ({ t, ...cursorAt(t) }))

export const segments: Segment[] = (() => {
  const out: Segment[] = []
  for (const click of clicks) {
    if (click.t > DURATION - config.ignoreClicksInLast) continue
    const start = Math.max(click.t - config.leadIn, 0)
    const end = Math.min(click.t + config.hold, DURATION - config.endMargin)
    const last = out[out.length - 1]
    if (last && start - last.end <= config.mergeGap) last.end = Math.max(last.end, end)
    else out.push({ start, end, regions: [] })
  }
  for (const segment of out) segment.regions = regionsIn(segment)
  return out
})()

/** Samples are evenly spaced in time, so each region's mean is weighted by dwell. */
function regionsIn(segment: Segment): Region[] {
  const maxW = SOURCE.width / config.scale / 2
  const maxH = SOURCE.height / config.scale / 2
  const regions: Region[] = []
  let open: (Region & { n: number }) | null = null
  const close = (r: Region & { n: number }, t1: number) => regions.push({ ...r, t1, cx: r.cx / r.n, cy: r.cy / r.n })

  for (let i = 0; segment.start + i / FPS <= segment.end; i++) {
    const t = segment.start + i / FPS
    const p = cursorAt(t)
    if (open && (Math.max(open.x1, p.x) - Math.min(open.x0, p.x) > maxW || Math.max(open.y1, p.y) - Math.min(open.y0, p.y) > maxH)) {
      close(open, t)
      open = null
    }
    open ??= { t0: t, t1: segment.end, x0: p.x, x1: p.x, y0: p.y, y1: p.y, cx: 0, cy: 0, n: 0 }
    open.x0 = Math.min(open.x0, p.x); open.x1 = Math.max(open.x1, p.x)
    open.y0 = Math.min(open.y0, p.y); open.y1 = Math.max(open.y1, p.y)
    open.cx += p.x; open.cy += p.y; open.n++
  }
  if (open) close(open, segment.end)
  return regions
}

export function regionAt(t: number): Region | null {
  const segment = segments.find(s => t >= s.start && t <= s.end)
  if (!segment) return null
  return segment.regions.find(r => t >= r.t0 && t < r.t1) ?? segment.regions[segment.regions.length - 1]
}

/** Framing.zoomedRect: center the focus, then slide back until the zoomed screen covers BASE. */
function zoomedRect(fx: number, fy: number): Rect {
  const w = BASE.w * config.scale, h = BASE.h * config.scale
  const cover = (origin: number, length: number, start: number, span: number) =>
    length > span ? clamp(origin, start + span - length, start) : start + (span - length) / 2
  return {
    x: cover(BASE.x + BASE.w / 2 - fx * w, w, BASE.x, BASE.w),
    y: cover(BASE.y + BASE.h / 2 - fy * h, h, BASE.y, BASE.h),
    w,
    h,
  }
}

function targetAt(t: number): Rect {
  const region = regionAt(t)
  return region ? zoomedRect(region.cx / SOURCE.width, region.cy / SOURCE.height) : BASE
}

/** One semi-implicit Euler step of 1 ms; returns the new velocity. */
const accelerate = (s: Spring, value: number, velocity: number, goal: number) =>
  velocity + ((-s.stiffness * (value - goal) - s.damping * velocity) / s.mass) * 0.001

let cache: Frame[] | null = null

/** Every frame is simulated up front, so scrubbing backwards gives the same picture. */
export function frames(): Frame[] {
  if (cache) return cache
  const rect = { ...BASE }, rectV = { x: 0, y: 0, w: 0, h: 0 }
  const cursor = cursorAt(0), cursorV = { x: 0, y: 0 }
  const out: Frame[] = []
  let ms = 0
  for (let i = 0; i <= DURATION * FPS; i++) {
    out.push({ ...rect, cursor: { ...cursor }, region: regionAt(i / FPS) })
    for (const end = Math.round(((i + 1) * 1000) / FPS); ms < end; ms++) {
      const goal = targetAt(ms / 1000), raw = cursorAt(ms / 1000)
      for (const k of ['x', 'y', 'w', 'h'] as const) {
        rectV[k] = accelerate(screenSpring, rect[k], rectV[k], goal[k])
        rect[k] += rectV[k] * 0.001
      }
      for (const k of ['x', 'y'] as const) {
        cursorV[k] = accelerate(cursorSpring, cursor[k], cursorV[k], raw[k])
        cursor[k] += cursorV[k] * 0.001
      }
    }
  }
  return (cache = out)
}

export function frameAt(t: number): Frame {
  const all = frames()
  return all[clamp(Math.round(t * FPS), 0, all.length - 1)]
}
