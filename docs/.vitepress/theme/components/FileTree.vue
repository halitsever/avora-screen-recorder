<script setup lang="ts">
/** Each row is [path, description, nested]. */
defineProps<{ rows: [string, string, boolean?][] }>()
</script>

<template>
  <div class="card tree">
    <div v-for="[path, about, nested] in rows" :key="path" class="tree-row">
      <code :class="{ nested }">{{ path }}</code><span>{{ about }}</span>
    </div>
  </div>
</template>
