<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

/** Each line is [prompt, text]; an empty prompt marks a comment. */
const props = defineProps<{ lines: [string, string][] }>()

const term = ref<HTMLElement>()
const shown = ref(props.lines.map(([, text]) => text.length))
const typing = ref(false)
const full = computed(() => props.lines.map(([p, text]) => `${p}${text}`).join('\n'))
let timer = 0
let observer: IntersectionObserver | undefined

function type(line = 0) {
  if (line >= props.lines.length) {
    typing.value = false
    return
  }
  const comment = !props.lines[line][0]
  shown.value[line]++
  const done = shown.value[line] >= props.lines[line][1].length
  timer = window.setTimeout(() => type(done ? line + 1 : line), done ? (comment ? 500 : 260) : comment ? 8 : 22)
}

onMounted(() => {
  if (matchMedia('(prefers-reduced-motion: reduce)').matches) return
  shown.value = props.lines.map(() => 0)
  observer = new IntersectionObserver(([entry]) => {
    if (!entry.isIntersecting) return
    observer?.disconnect()
    typing.value = true
    type()
  }, { threshold: 0.4 })
  observer.observe(term.value!)
})

onBeforeUnmount(() => {
  clearTimeout(timer)
  observer?.disconnect()
})
</script>

<template>
  <div ref="term" class="term">
    <div class="term-bar"><i /><i /><i /><span>zsh</span></div>
    <pre :aria-label="full"><template v-for="([prompt, text], i) in lines" :key="i"><template v-if="i === 0 || shown[i - 1] >= lines[i - 1][1].length"><span v-if="prompt" class="p">{{ prompt }}</span><span :class="{ c: !prompt }">{{ text.slice(0, shown[i]) }}</span>{{ i < lines.length - 1 && shown[i] >= text.length ? '\n' : '' }}</template></template><span v-if="typing || shown.every((n, i) => n >= lines[i][1].length)" class="caret" /></pre>
  </div>
</template>
