<script setup lang="ts">
import { computed, inject, type Ref } from 'vue'
import { CLICK_TIMES } from '../zoom'

/** The recorded screen, laid out in 1280x800 source pixels so the click points line up. */
const clock = inject<Ref<number>>('stageClock')!
const [todayAt, tickAt, shareAt] = CLICK_TIMES

const today = computed(() => clock.value >= todayAt)
const ticked = computed(() => clock.value >= tickAt)
const sharing = computed(() => clock.value >= shareAt)

const rows = [
  ['Record the onboarding demo', 'Avora launch', '9:30'],
  ['Review spring presets', 'Avora launch', '11:00'],
  ['Pick a backdrop for the launch video', '', '12:15'],
  ['Draft the release notes', 'Website', '14:00'],
  ['Send the build to beta testers', '', '15:30'],
  ['Fix menu bar icon contrast', 'Avora launch', ''],
  ['Prepare the meetup talk', 'Talks', '18:00'],
]
</script>

<template>
  <div class="app">
    <div class="wall" />
    <div class="menubar"><b>Tasks</b><span>File</span><span>Edit</span><span>View</span><span>Window</span><span class="r">Fri 31 Oct&nbsp;&nbsp;10:41</span></div>
    <div class="win">
      <div class="side">
        <div class="lights"><i /><i /><i /></div>
        <div class="si" :class="{ on: !today }">Inbox<span>4</span></div>
        <div class="si" :class="{ on: today }">Today<span>7</span></div>
        <div class="si">Upcoming</div>
        <div class="si">Someday</div>
        <div class="sh">PROJECTS</div>
        <div class="si"><i class="pd" style="background: #f26b1d" />Avora launch</div>
        <div class="si"><i class="pd" style="background: #4facfe" />Website</div>
        <div class="si"><i class="pd" style="background: #43e97b" />Talks</div>
      </div>
      <div class="main">
        <div class="search">Search</div>
        <div class="share" :class="{ on: sharing }">Share</div>
        <div class="ttl">Today</div>
        <div class="rows">
          <div v-for="(row, i) in rows" :key="row[0]" class="row" :class="{ done: i === 4 && ticked }">
            <i class="cb" /><span class="tx">{{ row[0] }}</span>
            <span class="chip" :style="{ visibility: row[1] ? 'visible' : 'hidden' }">{{ row[1] }}</span>
            <span class="when">{{ row[2] }}</span>
          </div>
        </div>
        <div class="pop" :class="{ on: sharing }">
          <h4>Share “Today”</h4>
          <div class="av"><i style="background: #f26b1d" /><i style="background: #667eea" /><i style="background: #43e97b" /></div>
          <div class="lk">tasks.app/s/today-31-oct</div>
          <div class="cp">Copy link</div>
        </div>
      </div>
    </div>
  </div>
</template>
