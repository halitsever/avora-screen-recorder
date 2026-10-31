<script setup lang="ts">
defineProps<{ id: string; kicker: string }>()
</script>

<template>
  <section :id="id" class="sec">
    <div class="wrap sec-body">
      <p class="kicker">{{ kicker }}</p>
      <slot />
    </div>
  </section>
</template>
