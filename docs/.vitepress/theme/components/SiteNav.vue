<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { useData } from 'vitepress'
import type { AvoraTheme } from '../types'
import mark from '../../../../Resources/Brand/avora-mark.svg'

const { theme } = useData<AvoraTheme>()
const active = ref(-1)

/** Marks the last section whose top has passed the middle of the viewport. */
function onScroll() {
  active.value = theme.value.nav.reduce((current, item, i) => {
    const top = document.querySelector(item.link)?.getBoundingClientRect().top ?? Infinity
    return top < innerHeight / 2 ? i : current
  }, -1)
}

onMounted(() => {
  addEventListener('scroll', onScroll, { passive: true })
  onScroll()
})
onBeforeUnmount(() => removeEventListener('scroll', onScroll))
</script>

<template>
  <nav class="nav" aria-label="Sections">
    <a class="brand" href="#top"><img :src="mark" alt="" width="20" height="20" />avora</a>
    <a v-for="(item, i) in theme.nav" :key="item.link" class="l" :class="{ on: i === active }" :href="item.link">{{ item.text }}</a>
    <a class="gh" :href="theme.repo">GitHub ↗</a>
  </nav>
</template>
