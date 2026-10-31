<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { useData, withBase } from 'vitepress'
import SiteNav from './components/SiteNav.vue'
import type { AvoraTheme } from './types'
import mark from '../../../Resources/Brand/avora-mark.svg'

const { page, theme } = useData<AvoraTheme>()
const progress = ref<HTMLElement>()

function onScroll() {
  const max = document.documentElement.scrollHeight - innerHeight
  progress.value!.style.transform = `scaleX(${max > 0 ? scrollY / max : 0})`
}

onMounted(() => {
  addEventListener('scroll', onScroll, { passive: true })
  onScroll()
})
onBeforeUnmount(() => removeEventListener('scroll', onScroll))
</script>

<template>
  <div class="grain" aria-hidden="true" />
  <div ref="progress" class="progress" aria-hidden="true" />
  <SiteNav />
  <main v-if="!page.isNotFound"><Content /></main>
  <main v-else class="wrap not-found">
    <h1>Not found</h1>
    <p>There is no page at this address. <a :href="withBase('/')">Go to the Avora docs</a>.</p>
  </main>
  <footer class="site-foot">
    <div class="wrap foot-row">
      <span class="foot-brand"><img :src="mark" alt="" width="18" height="18" />avora</span>
      <span>{{ theme.footer }}</span>
      <span><a :href="theme.repo">GitHub</a> · <a :href="`${theme.repo}/issues`">Issues</a></span>
    </div>
  </footer>
</template>
