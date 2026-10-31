<script setup lang="ts">
import { onBeforeUnmount, ref } from 'vue'
import { presets, selectedBackground } from '../backgrounds'
import templateIcon from '../../../../Resources/Brand/avoraTemplate@2x.png'

/** Avora's status item menu. Start Recording and the Background submenu respond to clicks. */
const since = ref(0)
const label = ref('Record Screen')
let timer = 0

function toggle() {
  clearInterval(timer)
  if (since.value) {
    since.value = 0
    label.value = 'Record Screen'
    return
  }
  since.value = Date.now()
  const tick = () => {
    const s = Math.floor((Date.now() - since.value) / 1000)
    label.value = `Stop Recording · ${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`
  }
  tick()
  timer = window.setInterval(tick, 500)
}

onBeforeUnmount(() => clearInterval(timer))
</script>

<template>
  <div class="desk">
    <div class="mb-strip">
      <b>Finder</b><span>File</span><span>Edit</span><span>View</span>
      <span class="r"><span class="mb-icon" :class="{ rec: since }"><img :src="templateIcon" alt="Avora menu bar icon" /></span><span>Fri 31 Oct</span><span>10:41</span></span>
    </div>
    <div class="menu" role="menu" aria-label="Avora menu">
      <button class="mi hi" role="menuitem" @click="toggle"><span>{{ label }}</span><kbd>⌃⌥⌘R</kbd></button>
      <div class="mi" role="menuitem" aria-haspopup="true">Capture<span class="ar">›</span></div>
      <div class="mi" role="menuitem" aria-haspopup="true">
        Background<span class="ar">›</span>
        <div class="submenu" role="menu" aria-label="Background">
          <button
            v-for="p in presets"
            :key="p.id"
            class="mi"
            :class="{ ck: p.id === selectedBackground }"
            role="menuitemradio"
            :aria-checked="p.id === selectedBackground"
            @click="selectedBackground = p.id"
          >
            <i :style="{ background: p.css }" />{{ p.name }}
          </button>
        </div>
      </div>
      <hr />
      <div class="mi" role="menuitem">Open Avora…</div>
      <div class="mi" role="menuitem">Edit Last Recording…<kbd>⌘E</kbd></div>
      <div class="mi" role="menuitem">Settings…<kbd>⌘,</kbd></div>
      <div class="mi" role="menuitem">Open Videos Folder</div>
      <div class="mi" role="menuitem">Clear Raw Recordings…</div>
      <hr />
      <div class="mi" role="menuitem">Quit Avora<kbd>⌘Q</kbd></div>
    </div>
    <p class="desk-hint">Try it: click <b>Record Screen</b>, or pick a background.</p>
  </div>
</template>
