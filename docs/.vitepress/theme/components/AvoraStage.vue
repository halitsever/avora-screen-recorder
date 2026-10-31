<script setup lang="ts">
import { onBeforeUnmount, onMounted, provide, ref, watch } from 'vue'
import FakeScreen from './FakeScreen.vue'
import { BACKGROUND_PARALLAX, BASE, CURSOR_SCALE, DURATION, SOURCE, clamp, clicks, frameAt, type Frame } from '../zoom'
import { presetCSS, selectedBackground } from '../backgrounds'

/** One frame of Avora's output: backdrop, zoomed screen, shadow and cursor, composed like FrameRenderer. */
const props = withDefaults(defineProps<{ mode?: 'loop' | 'still' | 'scrub'; time?: number; overlay?: boolean }>(), {
  mode: 'loop',
  time: 6.9,
  overlay: false,
})

const stage = ref<HTMLElement>()
const backdrop = ref<HTMLElement>()
const incoming = ref<HTMLElement>()
const screen = ref<HTMLElement>()
const pointer = ref<HTMLElement>()
const box = ref<HTMLElement>()
const dot = ref<HTMLElement>()
const rings: HTMLElement[] = []
const tags: HTMLElement[] = []
const ready = ref(false)
const resting = ref(presetCSS(selectedBackground.value))
const clock = ref(props.mode === 'loop' ? 0 : props.time)
provide('stageClock', clock)

let size = { w: 1, h: 1 }
let raf = 0
let fadeTimer = 0
let loopStart = 0
const observers: (ResizeObserver | IntersectionObserver)[] = []

function draw(t: number) {
  if (!screen.value || !backdrop.value || !pointer.value) return
  clock.value = t
  const f = frameAt(t)
  const sx = f.x * size.w, sy = f.y * size.h, scale = (f.w * size.w) / SOURCE.width
  const zoom = f.w / BASE.w
  // The backdrop grows around the point of the screen under the frame center.
  const ax = clamp((BASE.x + BASE.w / 2 - f.x) / f.w, 0, 1) * size.w
  const ay = clamp((BASE.y + BASE.h / 2 - f.y) / f.h, 0, 1) * size.h
  backdrop.value.style.transformOrigin = `${ax}px ${ay}px`
  backdrop.value.style.transform = `scale(${1 + Math.max(zoom - 1, 0) * BACKGROUND_PARALLAX})`
  screen.value.style.transform = `translate(${sx}px, ${sy}px) scale(${scale})`
  const pt = scale * CURSOR_SCALE
  pointer.value.style.transform = `translate(${sx + f.cursor.x * scale - 2 * pt}px, ${sy + f.cursor.y * scale - 2 * pt}px) scale(${pt})`
  if (props.overlay) drawOverlay(t, f, sx, sy, scale)
}

function drawOverlay(t: number, f: Frame, sx: number, sy: number, scale: number) {
  const at = (x: number, y: number) => [sx + x * scale, sy + y * scale]
  const region = f.region
  if (box.value && dot.value) {
    box.value.style.opacity = dot.value.style.opacity = region ? '1' : '0'
    if (region) {
      const pad = 26
      const [x0, y0] = at(region.x0 - pad, region.y0 - pad), [x1, y1] = at(region.x1 + pad, region.y1 + pad)
      Object.assign(box.value.style, { left: `${x0}px`, top: `${y0}px`, width: `${x1 - x0}px`, height: `${y1 - y0}px` })
      const [cx, cy] = at(region.cx, region.cy)
      Object.assign(dot.value.style, { left: `${cx}px`, top: `${cy}px` })
    }
  }
  clicks.forEach((click, i) => {
    const since = t - click.t, ring = rings[i], tag = tags[i]
    if (!ring || !tag) return
    ring.style.opacity = since >= 0 && since <= 0.9 ? `${1 - since / 0.9}` : '0'
    tag.style.opacity = since >= 0 && since <= 1.6 ? '1' : '0'
    if (since < -0.1 || since > 1.6) return
    const [x, y] = at(click.x, click.y), r = 6 + Math.max(since, 0) * 46 * scale
    Object.assign(ring.style, { left: `${x - r}px`, top: `${y - r}px`, width: `${2 * r}px`, height: `${2 * r}px` })
    Object.assign(tag.style, { left: `${x + 16 * scale}px`, top: `${y + 14 * scale}px` })
  })
}

function loop(now: number) {
  raf = requestAnimationFrame(loop)
  draw(((now - loopStart) / 1000) % (DURATION + 0.6))
}

watch(() => props.time, t => props.mode === 'scrub' && draw(t))

watch(selectedBackground, id => {
  const layer = incoming.value
  if (!layer) return
  const css = presetCSS(id)
  layer.style.transition = 'none'
  layer.style.opacity = '0'
  layer.style.background = css
  void layer.offsetWidth
  layer.style.transition = 'opacity .6s ease'
  layer.style.opacity = '1'
  clearTimeout(fadeTimer)
  fadeTimer = window.setTimeout(() => {
    resting.value = css
    layer.style.transition = 'none'
    layer.style.opacity = '0'
  }, 650)
})

onMounted(() => {
  const el = stage.value!
  const still = props.mode === 'still' || (props.mode === 'loop' && matchMedia('(prefers-reduced-motion: reduce)').matches)
  const resize = new ResizeObserver(() => {
    size = { w: el.clientWidth, h: el.clientHeight }
    draw(still ? (props.mode === 'loop' ? 4.3 : props.time) : clock.value)
  })
  resize.observe(el)
  observers.push(resize)
  if (props.mode === 'loop' && !still) {
    const visibility = new IntersectionObserver(([entry]) => {
      cancelAnimationFrame(raf)
      if (entry.isIntersecting) {
        loopStart = performance.now() - clock.value * 1000
        raf = requestAnimationFrame(loop)
      }
    })
    visibility.observe(el)
    observers.push(visibility)
  }
  ready.value = true
})

onBeforeUnmount(() => {
  cancelAnimationFrame(raf)
  clearTimeout(fadeTimer)
  observers.forEach(o => o.disconnect())
})
</script>

<template>
  <div ref="stage" class="stage" :class="{ ready }" role="img" aria-label="Avora output: a screen recording on a backdrop that zooms in where the pointer clicks">
    <div ref="backdrop" class="st-bg"><i :style="{ background: resting }" /><i ref="incoming" /></div>
    <div ref="screen" class="st-screen"><FakeScreen /></div>
    <div ref="pointer" class="st-cursor">
      <svg viewBox="0 0 18 24"><path d="M2 2 L2 19 L6.3 15.2 L9 21.3 L11.7 20.1 L9.1 14.3 L14.7 14.3 Z" fill="#111" stroke="#fff" stroke-width="1.4" stroke-linejoin="round" /></svg>
    </div>
    <div v-if="overlay" class="ov">
      <div ref="box" class="ov-box"><span>focus region</span></div>
      <div ref="dot" class="ov-dot" />
      <template v-for="(click, i) in clicks" :key="click.t">
        <div :ref="el => (rings[i] = el as HTMLElement)" class="ov-ring" />
        <div :ref="el => (tags[i] = el as HTMLElement)" class="ov-tag">click</div>
      </template>
    </div>
  </div>
</template>
