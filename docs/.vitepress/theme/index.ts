import type { Theme } from 'vitepress'
import Layout from './Layout.vue'
import BackgroundPicker from './components/BackgroundPicker.vue'
import CardGrid from './components/CardGrid.vue'
import DocSection from './components/DocSection.vue'
import FileTree from './components/FileTree.vue'
import HeroSection from './components/HeroSection.vue'
import InfoCard from './components/InfoCard.vue'
import TypedTerminal from './components/TypedTerminal.vue'
import UsingSection from './components/UsingSection.vue'
import ZoomChapter from './components/ZoomChapter.vue'
import ZoomStory from './components/ZoomStory.vue'
import './style.css'

/** A standalone theme: nothing from VitePress's default theme is loaded. */
export default {
  Layout,
  enhanceApp({ app }) {
    const components = { BackgroundPicker, CardGrid, DocSection, FileTree, HeroSection, InfoCard, TypedTerminal, UsingSection, ZoomChapter, ZoomStory }
    for (const [name, component] of Object.entries(components)) app.component(name, component)
  },
} satisfies Theme
