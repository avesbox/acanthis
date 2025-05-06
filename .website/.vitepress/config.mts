import { defineConfig } from 'vitepress'

// https://vitepress.dev/reference/site-config
export default defineConfig({
  title: "Acanthis",
  description: "Your best pal for validating data",
  lastUpdated: true,
  head: [
    ['link', { rel: "icon", type: "image/png", sizes: "32x32", href: "/acanthis-icon-32x32.png"}],
    ['link', { rel: "icon", type: "image/png", sizes: "16x16", href: "/acanthis-icon-16x16.png"}],
  ],
  themeConfig: {
    search: {
      provider: 'local'
    },
    // https://vitepress.dev/reference/default-theme-config
    nav: [
      {
        text: 'pub.dev',
        link: 'https://pub.dev/packages/acanthis'
      }
    ],
    outline: {
      level: [2, 3]
    },
    logo: '/acanthis-logo.png',
    sidebar: [
      {
        text: 'Introduction',
        link: '/introduction',
      },
      {
        text: 'Basic usage',
        link: '/basic-usage',
      },
      {
        text: 'Defining Schemas',
        link: '/defining-schemas',
      },
      {
        text: 'Customizing Errors',
        link: '/error-customization',
      },
      {
        text: 'Metadata',
        link: '/metadata',
      },
      {
        text: 'JSON Schema',
        link: '/json-schema',
      },
    ],
    footer: {
      copyright: 'Copyright © 2024 Avesbox',
      message: 'Built with 💙 by <a href="https://github.com/avesbox">Avesbox</a>'
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/francescovallone/acanthis' },
      { icon: 'x', link: 'https://x.com/avesboxx' },
      { icon: 'discord', link: 'https://discord.gg/zydgnJ3ksJ' },
      { icon: 'youtube', link: 'https://www.youtube.com/@avesbox' }
    ]
  }
})
