import { defineConfigWithTheme } from 'vitepress'
import type { AvoraTheme } from './theme/types'

/** GitHub Pages serves the site under the repo name. Set DOCS_BASE=/ for a custom domain. */
const base = process.env.DOCS_BASE ?? '/avora-screen-recorder/'

export default defineConfigWithTheme<AvoraTheme>({
  lang: 'en-US',
  title: 'Avora',
  description: 'A macOS screen recorder that zooms in on what you click.',
  base,
  cleanUrls: true,
  appearance: false,
  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: `${base}favicon.svg` }],
    ['meta', { name: 'theme-color', content: '#0B0C10' }],
    ['link', { rel: 'preconnect', href: 'https://fonts.googleapis.com' }],
    ['link', { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' }],
    ['link', { rel: 'stylesheet', href: 'https://fonts.googleapis.com/css2?family=Sora:wght@300..800&family=JetBrains+Mono:wght@400;500&display=swap' }],
  ],
  markdown: { theme: 'github-dark' },
  themeConfig: {
    nav: [
      { text: 'Using', link: '#using' },
      { text: 'Auto zoom', link: '#zoom' },
      { text: 'Backgrounds', link: '#backgrounds' },
      { text: 'Install', link: '#install' },
    ],
    repo: 'https://github.com/halitsever/avora-screen-recorder',
    footer: 'MIT. The Sora font is under the SIL Open Font License.',
  },
})
