import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'Acanthis',
  description: 'Composable data validation for Dart and Flutter. Learn schemas, handle errors, and validate with confidence.',
  lastUpdated: true,
  head: [
    ['link', { rel: 'icon', type: 'image/png', sizes: '32x32', href: '/acanthis-icon-32x32.png' }],
    ['link', { rel: 'icon', type: 'image/png', sizes: '16x16', href: '/acanthis-icon-16x16.png' }],
  ],
  markdown: { theme: { light: 'github-light', dark: 'github-dark' } },
  themeConfig: {
    logo: { src: '/acanthis-logo.png', alt: '' },
    search: { provider: 'local' },
    nav: [
      { text: 'Guide', link: '/introduction', activeMatch: '^/(introduction|basic-usage|validation-results|error-customization|live-validation)' },
      { text: 'Schemas', link: '/defining-schemas', activeMatch: '^/(defining-schemas|schemas/)' },
      { text: '2.0 migration', link: '/migration-2' },
      { text: 'pub.dev', link: 'https://pub.dev/packages/acanthis' },
    ],
    outline: { level: [2, 3], label: 'On this page' },
    sidebar: [
      { text: 'Get started', items: [
        { text: 'Introduction & installation', link: '/introduction' },
        { text: 'Quick start', link: '/basic-usage' },
      ] },
      { text: 'Schemas', collapsed: false, items: [
        { text: 'Overview', link: '/defining-schemas' },
        { text: 'Strings', link: '/schemas/strings' },
        { text: 'Numbers, booleans & dates', link: '/schemas/numbers' },
        { text: 'Objects', link: '/schemas/objects' },
        { text: 'Lists & tuples', link: '/schemas/collections' },
        { text: 'Nullable values', link: '/schemas/nullable' },
        { text: 'Instances & classes', link: '/schemas/instances' },
        { text: 'Literals & unions', link: '/schemas/unions' },
      ] },
      { text: 'Validation', collapsed: false, items: [
        { text: 'Results & issues', link: '/validation-results' },
        { text: 'Custom error messages', link: '/error-customization' },
        { text: 'Custom validation', link: '/schemas/refinements' },
        { text: 'Transformations & defaults', link: '/schemas/transformations' },
        { text: 'Live validation', link: '/live-validation' },
      ] },
      { text: 'Tools & integrations', collapsed: false, items: [
        { text: 'Metadata', link: '/metadata' },
        { text: 'JSON Schema', link: '/json-schema' },
        { text: 'OpenAPI', link: '/open-api-schema' },
        { text: 'Mock data', link: '/schemas/mocking' },
        { text: 'Seeded mocking', link: '/seeded-mocking' },
      ] },
      { text: 'Upgrade', items: [{ text: 'Migrating to 2.0', link: '/migration-2' }] },
    ],
    docFooter: { prev: 'Previous guide', next: 'Next guide' },
    footer: {
      copyright: 'Copyright © 2024–2026 Avesbox',
      message: 'Built by <a href="https://github.com/avesbox">Avesbox</a> · Made for Dart & Flutter',
    },
    socialLinks: [
      { icon: 'github', link: 'https://github.com/avesbox/acanthis' },
      { icon: 'discord', link: 'https://discord.gg/zydgnJ3ksJ' },
      { icon: 'x', link: 'https://x.com/avesboxx' },
      { icon: 'youtube', link: 'https://www.youtube.com/@avesbox' },
    ],
  },
})
