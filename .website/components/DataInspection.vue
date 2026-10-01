<template>
  <section class="inspection" aria-labelledby="inspection-title">
    <div class="inspection-grid" aria-hidden="true"></div>
    <div class="inspector">
      <img src="/acanthis-logo.png" alt="" width="160" height="160" loading="lazy" />
      <div><p class="eyebrow">FROM INPUT TO CONFIDENCE</p><h2 id="inspection-title">Every detail.<br><em>Checked.</em></h2><p class="inspection-description">Give your data a shape. Get validated values or an issue that points to what needs fixing.</p></div>
    </div>
    <div class="inspection-diagram" role="img" aria-label="Incoming data passes through a schema to produce validated data or a precise field issue.">
    <div class="inspection-flow" aria-hidden="true">
      <div class="input-stack"><span class="tiny-label">YOUR INPUT</span><div class="data-card"><i></i><code>name: "Ada"</code><code>email: "ada@"</code></div></div>
      <div class="flow-track"><span></span></div>
      <div class="schema-stamp"><span>{ }</span><small>schema</small></div>
      <svg class="flow-fork" viewBox="0 0 60 100" fill="none"><path d="M0 50H20Q30 50 30 40V20Q30 12 40 12H60M20 50Q30 50 30 60V80Q30 88 40 88H60" stroke="currentColor" stroke-width="1.5"/><circle r="3" cx="30" cy="50" fill="currentColor"/></svg>
      <div class="outcomes"><div class="outcome good"><span>✓</span> Validated data</div><div class="outcome issue"><span>!</span> A useful issue</div></div>
    </div>
    <p class="inspection-caption"><span>01 / DESCRIBE</span><span>02 / CHECK</span><span>03 / USE WITH CONFIDENCE</span></p>
    </div>
  </section>
</template>

<style scoped>
.inspection { position: relative; overflow: hidden; isolation: isolate; display: grid; grid-template-columns: 1fr 1.15fr; align-items: center; gap: 64px; padding: 56px 0; border-top: 1px solid var(--vp-c-divider); }
.inspection-grid { position: absolute; inset: 0; z-index: -1; opacity: .4; background-image: radial-gradient(var(--vp-c-divider) 1px, transparent 1px); background-size: 16px 16px; mask-image: linear-gradient(to bottom, #000, transparent); }
.inspector { display: flex; align-items: center; gap: 24px; }
.inspector img { flex: 0 0 auto; width: 100px; height: 100px; object-fit: contain; border-radius: 50%; background: #fff; transform: rotate(-7deg); }
.eyebrow { color: var(--vp-c-brand-1); font-size: 10px; font-weight: 700; letter-spacing: .1em; }
h2 { margin: 14px 0; font: 400 36px/1.12 Georgia, serif; letter-spacing: -.035em; }
h2 em { color: var(--vp-c-brand-1); }
.inspection-description { max-width: 280px; font-size: 14px; line-height: 1.75; color: var(--vp-c-text-2); }
.inspection-diagram { min-width: 0; padding: 12px 8px; }
.inspection-flow { display: flex; align-items: center; min-height: 140px; }
.input-stack { width: 32%; }
.tiny-label { display: block; margin-bottom: 7px; font-size: 10px; letter-spacing: .12em; color: var(--vp-c-text-3); }
.data-card { position: relative; padding: 13px 10px; border: 1px solid var(--vp-c-divider); border-radius: 6px; background: var(--vp-c-bg-elv); box-shadow: -4px 4px 0 var(--vp-c-bg-alt), -5px 5px 0 var(--vp-c-divider); }
.data-card code { display: block; font-size: 11px; white-space: nowrap; line-height: 1.9; }
.data-card i { display: block; width: 20px; height: 3px; margin-bottom: 7px; border-radius: 3px; background: var(--vp-c-brand-1); opacity: .5; }
.flow-track { flex: 1; position: relative; height: 1px; background: var(--vp-c-divider); }
.flow-track span { position: absolute; width: 5px; height: 5px; top: -2px; border-radius: 50%; background: var(--vp-c-brand-1); animation: inspect 3s ease-in-out infinite; }
.schema-stamp { flex: 0 0 65px; height: 76px; display: flex; flex-direction: column; justify-content: center; align-items: center; border: 1px solid var(--vp-c-brand-1); border-radius: 12px; color: var(--vp-c-brand-1); background: var(--vp-c-bg); box-shadow: 0 0 0 5px var(--vp-c-brand-soft); }
.schema-stamp > span { font: 26px Georgia, serif; }
.schema-stamp small { font-size: 10px; margin-top: 3px; }
.flow-fork { width: 12%; height: 90px; color: var(--vp-c-brand-1); opacity: .5; }
.outcomes { display: grid; gap: 48px; }
.outcome { display: flex; align-items: center; gap: 7px; font-size: 11px; white-space: nowrap; }
.outcome > span { display: grid; place-items: center; width: 19px; height: 19px; border: 1px solid currentColor; border-radius: 50%; font-size: 11px; }
.good > span { color: #34745b; }
:global(.dark) .good > span { color: #92cdb1; }
.issue > span { color: var(--vp-c-brand-1); }
.inspection-caption { display: flex; justify-content: space-between; gap: 8px; padding-top: 22px; font-size: 9px; letter-spacing: .06em; color: var(--vp-c-text-3); }
@keyframes inspect { 0% { left: 0; opacity: 0; } 20% { opacity: 1; } 80% { opacity: 1; } 100% { left: 95%; opacity: 0; } }
@media (prefers-reduced-motion: reduce) { .flow-track span { animation: none; left: 50%; } }
@media (max-width: 1100px) { .inspection { gap: 32px; grid-template-columns: .85fr 1.15fr; } .inspector { gap: 16px; } .inspector img { width: 72px; height: 72px; } }
@media (max-width: 959px) { .inspection { grid-template-columns: 1fr; gap: 24px; padding: 40px 0; } .inspection-diagram { width: 100%; max-width: 600px; margin: 0 auto; } .inspection-description { max-width: 440px; } h2 br { display: none; } h2 em::before { content: ' '; } }
@media (max-width: 420px) { .schema-stamp { flex-basis: 48px; height: 64px; } .outcome { font-size: 9px; gap: 4px; } .data-card { padding: 10px 6px; } .data-card code { font-size: 8px; } .inspection-caption { font-size: 7px; } .tiny-label { font-size: 8px; } .inspector { align-items: flex-start; } h2 { font-size: 30px; } }
</style>
