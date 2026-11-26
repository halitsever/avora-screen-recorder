import { defineConfigWithTheme } from 'vitepress'
import type { AvoraTheme } from './theme/types'

/** Where the site is published. Set DOCS_URL for a custom domain; the base path follows from it. */
const url = process.env.DOCS_URL ?? 'https://halitsever.github.io/avora-screen-recorder/'
const base = new URL(url).pathname
const description = 'Open source screen recorder for Mac that zooms in on your clicks, with a smooth cursor and backgrounds. A free Screen Studio alternative.'

const repo = 'https://github.com/halitsever/avora-screen-recorder'
const license = 'https://opensource.org/licenses/MIT'
const author = { '@type': 'Person', name: 'Halit Sever', url: 'https://github.com/halitsever' }

const jsonLd = {
  '@context': 'https://schema.org',
  '@graph': [
    {
      '@type': 'SoftwareApplication',
      '@id': `${url}#app`,
      name: 'Avora',
      description,
      url,
      image: `${url}social.png`,
      applicationCategory: 'MultimediaApplication',
      operatingSystem: 'macOS',
      offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
      downloadUrl: `${repo}/releases/latest`,
      license,
      author,
    },
    {
      '@type': 'SoftwareSourceCode',
      '@id': `${url}#source`,
      name: 'Avora',
      codeRepository: repo,
      programmingLanguage: 'Swift',
      license,
      author,
      targetProduct: { '@id': `${url}#app` },
    },
  ],
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
    /** Cloudflare Web Analytics, one token for every page on halitsever.github.io. */
    ['script', { defer: '', src: 'https://static.cloudflareinsights.com/beacon.min.js', 'data-cf-beacon': '{"token": "dd7e54d3f48841c187d72d9dbb92a6b6"}' }],
    ['link', { rel: 'icon', type: 'image/svg+xml', href: `${base}favicon.svg` }],
    ['meta', { name: 'theme-color', content: '#0B0C10' }],
    // Link previews need absolute image URLs.
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:image', content: `${url}social.png` }],
    ['meta', { property: 'og:image:width', content: '1280' }],
    ['meta', { property: 'og:image:height', content: '640' }],
    ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
    ['script', { type: 'application/ld+json' }, JSON.stringify(jsonLd)],
    ['link', { rel: 'preconnect', href: 'https://fonts.googleapis.com' }],
    ['link', { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' }],
    ['link', { rel: 'stylesheet', href: 'https://fonts.googleapis.com/css2?family=Sora:wght@300..800&family=JetBrains+Mono:wght@400;500&display=swap' }],
  ],
  /** Canonical and Open Graph tags differ per page, so they are built here instead of in `head`. */
  transformHead({ pageData, title, description }) {
    if (pageData.isNotFound) return
    const path = pageData.relativePath.replace(/(^|\/)index\.md$/, '$1').replace(/\.md$/, '')
    const pageUrl = new URL(path, url).href
    return [
      ['link', { rel: 'canonical', href: pageUrl }],
      ['meta', { property: 'og:url', content: pageUrl }],
      ['meta', { property: 'og:title', content: pageData.frontmatter.ogTitle ?? title }],
      ['meta', { property: 'og:description', content: description }],
    ]
  },
  markdown: { theme: 'github-dark' },
  themeConfig: {
    nav: [
      { text: 'Using', link: '#using' },
      { text: 'Auto zoom', link: '#zoom' },
      { text: 'Backgrounds', link: '#backgrounds' },
      { text: 'Install', link: '#install' },
      { text: 'vs Screen Studio', link: '/screen-studio-alternative' },
    ],
    repo,
    footer: 'MIT. The Sora font is under the SIL Open Font License.',
  },
})
