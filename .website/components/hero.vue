<template>
  <div class="acanthis-home">
    <section class="home-hero" aria-labelledby="home-title">
      <div class="hero-copy">
        <p class="eyebrow">DATA VALIDATION FOR DART & FLUTTER</p>
        <h1 id="home-title">Good data.<br><em>From the start.</em></h1>
        <p class="hero-description">Describe the shape of your data. Validate it, transform it, and get clear errors when something doesn’t fit.</p>
        <div class="hero-actions">
          <a class="primary-action" href="/basic-usage.html">Start validating <span aria-hidden="true">↗</span></a>
          <a class="secondary-action" href="/defining-schemas.html">Explore the schemas <span aria-hidden="true">→</span></a>
        </div>
        <p class="install-note"><code>dart pub add acanthis</code><span>One package. Dart & Flutter.</span></p>
      </div>
      <div class="hero-example">
        <div class="example-bar"><span><span class="status-dot" aria-hidden="true"></span> Your first schema</span><span>Dart</span></div>
        <div class="vp-doc"><slot name="example" /></div>
        <div class="example-result"><span aria-hidden="true">✓</span> Define once. Reuse wherever data comes in.</div>
      </div>
    </section>
    <section class="home-paths" aria-labelledby="paths-title">
      <div class="paths-heading"><p class="eyebrow">THE DOCUMENTATION</p><h2 id="paths-title">A clear path from input to output.</h2></div>
      <div class="path-grid">
        <a href="/basic-usage.html"><span class="path-number">01 / LEARN</span><h3>Your first validation <span aria-hidden="true">↗</span></h3><p>Build a schema, parse an input, and handle a failed check in one short guide.</p></a>
        <a href="/defining-schemas.html"><span class="path-number">02 / BUILD</span><h3>Find your schema <span aria-hidden="true">↗</span></h3><p>From a single email to nested objects. Find types, constraints, and examples.</p></a>
        <a href="/validation-results.html"><span class="path-number">03 / HANDLE</span><h3>Make errors useful <span aria-hidden="true">↗</span></h3><p>Read typed outcomes and field-level issues, then show the right message.</p></a>
      </div>
    </section>
    <section class="home-more" aria-label="More guides">
      <p>Already using Acanthis?</p>
      <a href="/live-validation.html">Live validation →</a>
      <a href="/json-schema.html">JSON Schema →</a>
      <a href="/migration-2.html">Migrating to 2.0 →</a>
    </section>
  </div>
</template>

<style scoped>
.acanthis-home { max-width: 1200px; margin: 0 auto; padding: 0 32px; }
.home-hero { display: grid; grid-template-columns: 1fr 1fr; align-items: center; gap: 64px; padding: 96px 0 80px; }
.eyebrow { color: var(--vp-c-brand-1); font-size: 11px; font-weight: 700; letter-spacing: .13em; }
h1 { font-family: Georgia, 'Times New Roman', serif; font-size: clamp(48px, 5.2vw, 72px); line-height: 1.06; letter-spacing: -.045em; margin: 24px 0; font-weight: 400; }
h1 em { color: var(--vp-c-brand-1); font-weight: 400; }
.hero-description { max-width: 440px; font-size: 18px; line-height: 1.75; color: var(--vp-c-text-2); }
.hero-actions { display: flex; flex-wrap: wrap; align-items: center; gap: 20px; margin-top: 30px; font-size: 14px; font-weight: 600; }
.primary-action { display: flex; align-items: center; gap: 24px; border-radius: 6px; padding: 13px 20px; background: var(--vp-button-brand-bg); color: #fff; }
.primary-action:hover { background: var(--vp-button-brand-hover-bg); }
.secondary-action:hover { color: var(--vp-c-brand-1); }
.install-note { display: flex; flex-wrap: wrap; gap: 12px; align-items: center; margin-top: 26px; color: var(--vp-c-text-3); font-size: 11px; }
.install-note code { padding: 6px 9px; background: var(--vp-c-bg-alt); border: 1px solid var(--vp-c-divider); border-radius: 4px; color: var(--vp-c-text-2); font-size: 12px; }
.hero-example { min-width: 0; overflow: hidden; border: 1px solid var(--vp-c-divider); border-radius: 12px; background: var(--vp-code-block-bg); box-shadow: 0 16px 50px rgba(50, 30, 25, .05); }
.example-bar { display: flex; justify-content: space-between; padding: 15px 20px; border-bottom: 1px solid var(--vp-c-divider); color: var(--vp-c-text-2); font-size: 12px; }
.example-bar > span:first-child { display: flex; align-items: center; gap: 9px; }
.status-dot { width: 7px; height: 7px; border-radius: 50%; background: var(--vp-c-brand-1); }
.hero-example :deep(div[class*='language-']) { margin: 0; border: none; border-radius: 0; }
.hero-example :deep(pre) { padding: 24px 0; }
.hero-example :deep(code) { font-size: 13px; }
.example-result { border-top: 1px solid var(--vp-c-divider); padding: 13px 20px; font-size: 12px; color: var(--vp-c-text-2); }
.example-result > span { color: var(--vp-c-brand-1); margin-right: 7px; }
.home-paths { padding: 40px 0; border-top: 1px solid var(--vp-c-divider); }
.paths-heading h2 { margin: 12px 0 28px; font-size: 26px; line-height: 1.3; letter-spacing: -.03em; }
.path-grid { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 16px; }
.path-grid a { padding: 24px; border: 1px solid var(--vp-c-divider); border-radius: 8px; background: var(--vp-c-bg-elv); }
.path-grid a:hover { border-color: var(--vp-c-brand-1); }
.path-number { color: var(--vp-c-text-3); font-size: 10px; letter-spacing: .1em; }
.path-grid h3 { display: flex; justify-content: space-between; gap: 10px; margin: 16px 0 8px; font-size: 18px; font-weight: 600; letter-spacing: -.025em; }
.path-grid h3 span { color: var(--vp-c-brand-1); }
.path-grid p { color: var(--vp-c-text-2); font-size: 14px; line-height: 1.7; }
.home-more { display: flex; flex-wrap: wrap; gap: 16px 28px; border-top: 1px solid var(--vp-c-divider); padding: 28px 0 56px; font-size: 13px; }
.home-more p { color: var(--vp-c-text-3); margin-right: auto; }
.home-more a:hover { color: var(--vp-c-brand-1); }
@media (max-width: 959px) { .home-hero { gap: 32px; padding: 64px 0; } .path-grid a { padding: 18px; } }
@media (max-width: 767px) { .home-hero { grid-template-columns: 1fr; } .hero-description { max-width: 520px; } .path-grid { grid-template-columns: 1fr; } .acanthis-home { padding: 0 24px; } .home-hero { padding-top: 48px; } .home-more p { width: 100%; } }
</style>
