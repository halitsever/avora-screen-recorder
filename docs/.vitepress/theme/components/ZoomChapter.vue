<script setup lang="ts">
import { inject, type Ref } from 'vue'

defineProps<{ title: string }>()
const story = inject<{ register: () => number; active: Ref<number> }>('zoomStory')!
const index = story.register()
</script>

<template>
  <article class="chap" :class="{ on: story.active.value === index }">
    <span class="num">{{ String(index + 1).padStart(2, '0') }}</span>
    <h3>{{ title }}</h3>
    <slot />
  </article>
</template>
