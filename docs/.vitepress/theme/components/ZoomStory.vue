<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, provide, ref } from 'vue'
import AvoraStage from './AvoraStage.vue'
import { BASE, CHAPTER_STARTS, DURATION, clamp, clicks, frameAt, segments } from '../zoom'

/** A tall section whose scroll position is the playhead of the demo recording. */
defineProps<{ id: string; kicker: string; title: string; labels: string[] }>()

const section = ref<HTMLElement>()
const time = ref(0)
const active = computed(() => CHAPTER_STARTS.reduce((current, start, i) => (time.value >= start ? i : current), 0))
let chapters = 0
provide('zoomStory', { register: () => chapters++, active })

const pct = (t: number) => `${(t / DURATION) * 100}%`
const zoom = computed(() => (frameAt(time.value).w / BASE.w).toFixed(2))

let target = 0
let raf = 0

function onScroll() {
  const r = section.value!.getBoundingClientRect()
  target = clamp(-r.top / (r.height - innerHeight), 0, 1) * DURATION
  if (!raf) raf = requestAnimationFrame(ease)
}

/** Eases the playhead toward the scroll position so wheel steps don't jump frames. */
function ease() {
  const gap = target - time.value
  time.value = Math.abs(gap) < 0.002 ? target : time.value + gap * 0.16
  raf = time.value === target ? 0 : requestAnimationFrame(ease)
}

onMounted(() => {
  addEventListener('scroll', onScroll, { passive: true })
  addEventListener('resize', onScroll)
  onScroll()
})

onBeforeUnmount(() => {
  removeEventListener('scroll', onScroll)
  removeEventListener('resize', onScroll)
  cancelAnimationFrame(raf)
})
</script>

<template>
  <section :id="id" ref="section" class="story">
    <div class="pin">
      <div class="copy">
        <p class="kicker">{{ kicker }}</p>
        <h2>{{ title }}</h2>
        <div class="chap-wrap"><slot /></div>
        <ol class="chap-nav">
          <li v-for="(label, i) in labels" :key="label" :class="{ on: i <= active }">{{ label }}</li>
        </ol>
        <p class="hint"><i />Scroll to move the playhead</p>
      </div>
      <div class="story-stage">
        <AvoraStage mode="scrub" :time="time" overlay />
        <div class="tl" aria-hidden="true">
          <div class="tl-track">
            <div v-for="s in segments" :key="s.start" class="tl-seg" :style="{ left: pct(s.start), width: pct(s.end - s.start) }"><span>zoom</span></div>
            <i v-for="c in clicks" :key="c.t" class="tl-click" :style="{ left: pct(c.t) }" />
            <div class="tl-head" :style="{ left: pct(time) }" />
          </div>
          <div class="tl-meta">
            <span>t <b>{{ time.toFixed(2).padStart(5, '0') }}</b> s</span>
            <span>zoom <b>{{ zoom }}</b>×</span>
            <span class="sp">spring · m 2.25 · k 250 · c 40</span>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>
