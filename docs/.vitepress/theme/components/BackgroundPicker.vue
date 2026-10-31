<script setup lang="ts">
import AvoraStage from './AvoraStage.vue'
import { presets, selectedBackground } from '../backgrounds'
</script>

<template>
  <div class="bgs">
    <AvoraStage mode="still" :time="6.9" />
    <div class="swatches" role="radiogroup" aria-label="Background">
      <button
        v-for="p in presets"
        :key="p.id"
        class="sw"
        :class="{ on: p.id === selectedBackground }"
        role="radio"
        :aria-checked="p.id === selectedBackground"
        @click="selectedBackground = p.id"
      >
        <i :style="{ background: p.css }" />
        <b>{{ p.name }}</b>
        <code>{{ p.id }}{{ p.id === 'avora' ? ' · default' : '' }}</code>
      </button>
    </div>
  </div>
</template>
