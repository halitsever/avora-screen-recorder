<script setup lang="ts">
import MenuBarDemo from './MenuBarDemo.vue'

defineProps<{ id: string; kicker: string }>()
</script>

<template>
  <section :id="id" class="sec">
    <div class="wrap using">
      <div class="sec-body">
        <p class="kicker">{{ kicker }}</p>
        <slot />
      </div>
      <MenuBarDemo />
    </div>
  </section>
</template>
