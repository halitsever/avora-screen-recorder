<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import AvoraStage from './AvoraStage.vue'

const frame = ref<HTMLElement>()

/** The stage starts tipped back and lies flat as the page scrolls. */
function onScroll() {
  const p = Math.min(Math.max(scrollY / (innerHeight * 0.7), 0), 1)
  frame.value!.style.transform = `rotateX(${(1 - p) * 22}deg) scale(${0.9 + 0.1 * p})`
}

onMounted(() => {
  if (matchMedia('(prefers-reduced-motion: reduce)').matches) return
  addEventListener('scroll', onScroll, { passive: true })
  onScroll()
})
onBeforeUnmount(() => removeEventListener('scroll', onScroll))
</script>

<template>
  <section id="top" class="hero">
    <div class="wrap hero-copy"><slot /></div>
    <div class="hero-frame">
      <div ref="frame" class="hero-tilt"><AvoraStage mode="loop" /></div>
    </div>
  </section>
</template>
