import { defineConfigWithTheme } from 'vitepress'
import type { AvoraTheme } from './theme/types'

/** Where the site is published. Set DOCS_URL for a custom domain; the base path follows from it. */
const url = process.env.DOCS_URL ?? 'https://halitsever.github.io/avora-screen-recorder/'
const base = new URL(url).pathname
const description = 'Open source macOS screen recorder with automatic click-to-zoom, a smooth cursor and backgrounds. Turns a raw take into a finished, shareable video.'

const jsonLd = {
  '@context': 'https://schema.org',
  '@type': 'SoftwareApplication',
  name: 'Avora',
  description,
  url,
  image: `${url}social.png`,
  applicationCategory: 'MultimediaApplication',
  operatingSystem: 'macOS',
  offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
  downloadUrl: 'https://github.com/halitsever/avora-screen-recorder/releases/latest',
  codeRepository: 'https://github.com/halitsever/avora-screen-recorder',
  programmingLanguage: 'Swift',
  license: 'https://opensource.org/licenses/MIT',
  author: { '@type': 'Person', name: 'Halit Sever', url: 'https://github.com/halitsever' },
}

export default defineConfigWithTheme<AvoraTheme>({
  lang: 'en-US',
  title: 'Avora',
  description,
  base,
  cleanUrls: true,
  appearance: false,
  sitemap: { hostname: url },
  head: [
    ['link', { rel: 'canonical', href: url }],
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
    ['script', { type: 'application/ld+json' }, JSON.stringify(jsonLd)],
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
