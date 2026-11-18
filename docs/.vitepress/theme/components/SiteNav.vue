<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useData, withBase } from 'vitepress'
import type { AvoraTheme } from '../types'
import mark from '../../../../Resources/Brand/avora-mark.svg'

const { theme, page } = useData<AvoraTheme>()
const active = ref(-1)
const onHome = computed(() => page.value.relativePath === 'index.md')

/** Section anchors live on the home page, so other pages link back to it. */
function href(link: string) {
  if (!link.startsWith('#')) return withBase(link)
  return onHome.value ? link : withBase('/') + link
}

const isCurrentPage = (link: string) => page.value.relativePath === `${link.slice(1)}.md`

/** Marks the last section whose top has passed the middle of the viewport. */
function onScroll() {
  active.value = theme.value.nav.reduce((current, item, i) => {
    if (!item.link.startsWith('#') || !onHome.value) return current
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
    <a class="brand" :href="onHome ? '#top' : withBase('/')"><img :src="mark" alt="" width="20" height="20" />avora</a>
    <a v-for="(item, i) in theme.nav" :key="item.link" class="l" :class="{ on: (onHome && i === active) || isCurrentPage(item.link) }" :aria-current="isCurrentPage(item.link) ? 'page' : undefined" :href="href(item.link)">{{ item.text }}</a>
    <a class="gh" :href="theme.repo">GitHub ↗</a>
  </nav>
</template>
