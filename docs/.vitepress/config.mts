import { defineConfigWithTheme, type HeadConfig } from 'vitepress'
import type { AvoraTheme } from './theme/types'

/** Where the site is published. Set DOCS_URL for a custom domain; the base path follows from it. */
const url = process.env.DOCS_URL ?? 'https://projects.halit.org/avora-screen-recorder/'
const base = new URL(url).pathname
const description = 'Open source screen recorder for Mac that zooms in on your clicks, with a smooth cursor and backgrounds. A free Screen Studio alternative.'

const repo = 'https://github.com/halitsever/avora-screen-recorder'
const license = 'https://opensource.org/licenses/MIT'
const author = { '@type': 'Person', name: 'Halit Sever', url: 'https://github.com/halitsever' }

const jsonLd = {
  '@context': 'https://schema.org',
  '@graph': [
    {
      '@type': 'SoftwareSourceCode',
      '@id': `${url}#source`,
      name: 'Avora',
      description,
      url,
      image: `${url}social.png`,
      codeRepository: repo,
      programmingLanguage: 'Swift',
      license,
      author,
    },
  ],
}

/** BlogPosting and breadcrumbs for posts, FAQPage wherever the page shows an FAQ. */
function pageJsonLd(fm: Record<string, any>, pageUrl: string, title: string, description: string) {
  const person = { ...author, url: 'https://halit.org' }
  const graph: object[] = []
  if (fm.date) {
    graph.push(
      {
        '@type': 'BlogPosting',
        headline: fm.headline ?? title,
        description,
        url: pageUrl,
        mainEntityOfPage: pageUrl,
        datePublished: fm.date,
        dateModified: fm.date,
        inLanguage: 'en',
        image: `${url}social.png`,
        keywords: fm.keyword,
        author: person,
        publisher: person,
      },
      {
        '@type': 'BreadcrumbList',
        itemListElement: [
          { '@type': 'ListItem', position: 1, name: 'Avora', item: url },
          { '@type': 'ListItem', position: 2, name: 'Blog', item: `${url}blog/` },
          { '@type': 'ListItem', position: 3, name: fm.headline ?? title, item: pageUrl },
        ],
      },
    )
  }
  if (fm.faq?.length) {
    graph.push({
      '@type': 'FAQPage',
      mainEntity: fm.faq.map((f: { q: string; a: string }) => ({
        '@type': 'Question',
        name: f.q,
        acceptedAnswer: { '@type': 'Answer', text: f.a.replace(/<[^>]+>|`|\*\*/g, '') },
      })),
    })
  }
  return { '@context': 'https://schema.org', '@graph': graph }
}

export default defineConfigWithTheme<AvoraTheme>({
  /** keeps the page hash map out of every page's HTML, which Semrush reads as a low text-to-HTML ratio */
  metaChunk: true,
  lang: 'en-US',
  title: 'Avora',
  description,
  base,
  cleanUrls: true,
  appearance: false,
  sitemap: { hostname: url },
  head: [
    /** Cloudflare Web Analytics, one token for every page on projects.halit.org. */
    ['script', { defer: '', src: 'https://static.cloudflareinsights.com/beacon.min.js', 'data-cf-beacon': '{"token": "dd7e54d3f48841c187d72d9dbb92a6b6"}' }],
    ['link', { rel: 'icon', type: 'image/svg+xml', href: `${base}favicon.svg` }],
    ['meta', { name: 'theme-color', content: '#0B0C10' }],
    // Link previews need absolute image URLs.
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
    const fm = pageData.frontmatter
    const extra: HeadConfig[] = []
    if (fm.date || fm.faq) extra.push(['script', { type: 'application/ld+json' }, JSON.stringify(pageJsonLd(fm, pageUrl, title, description))])
    return [
      ...extra,
      ['meta', { property: 'og:type', content: fm.date ? 'article' : 'website' }],
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
      { text: 'Blog', link: '/blog/' },
    ],
    repo,
    footer: 'MIT. The Sora font is under the SIL Open Font License.',
  },
})
