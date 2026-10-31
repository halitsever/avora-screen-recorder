import { defineConfigWithTheme } from 'vitepress'
import type { AvoraTheme } from './theme/types'

/** Where the site is published. Set DOCS_URL for a custom domain; the base path follows from it. */
const url = process.env.DOCS_URL ?? 'https://halitsever.github.io/avora-screen-recorder/'
const base = new URL(url).pathname
const description = 'A macOS screen recorder that turns a raw take into a finished, shareable video.'

export default defineConfigWithTheme<AvoraTheme>({
  lang: 'en-US',
  title: 'Avora',
  description,
  base,
  cleanUrls: true,
  appearance: false,
  head: [
    ['link', { rel: 'icon', type: 'image/svg+xml', href: `${base}favicon.svg` }],
    ['meta', { name: 'theme-color', content: '#0B0C10' }],
    // Link previews need absolute image URLs.
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:url', content: url }],
    ['meta', { property: 'og:title', content: 'Avora: your screen, already edited' }],
    ['meta', { property: 'og:description', content: description }],
    ['meta', { property: 'og:image', content: `${url}social.png` }],
    ['meta', { property: 'og:image:width', content: '1280' }],
    ['meta', { property: 'og:image:height', content: '640' }],
    ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
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
