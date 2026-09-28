<script setup>
import { computed, onBeforeUnmount, ref } from 'vue'

const email = ref('ada@example.com')
const state = ref('valid')
let timer
const message = computed(() => state.value === 'pending'
  ? 'Checking your edit…'
  : state.value === 'valid' ? 'Email looks good.' : 'Enter a complete email address.')

function check(value) {
  email.value = value
  clearTimeout(timer)
  state.value = 'pending'
  timer = setTimeout(() => {
    state.value = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value) ? 'valid' : 'invalid'
  }, 650)
}
onBeforeUnmount(() => clearTimeout(timer))
</script>

<template>
  <section class="live-showcase" aria-labelledby="live-title">
    <div class="live-copy">
      <p class="eyebrow">MEET ACANTHIS 2.0</p>
      <h2 id="live-title">An edit.<br>A check.<br><em>A clear answer.</em></h2>
      <p>Keep validation close to the field. Live sessions track edits, async checks, and useful errors as your data changes.</p>
      <a href="/live-validation.html">Explore live validation <span aria-hidden="true">↗</span></a>
    </div>
    <div class="live-panel" :data-state="state">
      <div class="panel-heading"><span class="panel-dot" aria-hidden="true"></span> A little room to experiment <span class="preview-tag">PREVIEW</span></div>
      <div class="field-area">
        <label for="preview-email">Email address</label>
        <div class="input-wrap">
          <input id="preview-email" type="email" :value="email" spellcheck="false" autocomplete="off"
            :aria-invalid="state === 'invalid'" aria-describedby="preview-message"
            @input="check($event.target.value)" />
          <span class="field-symbol" aria-hidden="true">{{ state === 'pending' ? '…' : state === 'valid' ? '✓' : '!' }}</span>
        </div>
        <p id="preview-message" class="field-message" role="status" aria-live="polite">{{ message }}</p>
        <div class="examples"><span>Try an example</span><button type="button" @click="check('ada@')">Incomplete email</button><button type="button" @click="check('ada@example.com')">Valid email</button></div>
      </div>
      <div class="result-area" :aria-busy="state === 'pending'">
        <div class="result-heading"><span>FIELD RESULT</span><span class="state-label">{{ state === 'pending' ? 'Checking' : state === 'valid' ? 'Valid' : 'Needs attention' }}</span></div>
        <div class="result-line"><code>/account/email</code><span class="result-connector" aria-hidden="true"></span><span class="result-icon" aria-hidden="true">{{ state === 'pending' ? '· · ·' : state === 'valid' ? '✓' : '!' }}</span></div>
        <p>{{ state === 'pending' ? 'Waiting for the check to finish.' : state === 'valid' ? 'This field is ready to use.' : 'A precise path. A message you can act on.' }}</p>
      </div>
      <p class="preview-note">Illustrative preview with a simulated async check.</p>
    </div>
  </section>
</template>

<style scoped>
.live-showcase { display: grid; grid-template-columns: .85fr 1.15fr; gap: 80px; align-items: center; padding: 72px 0 80px; border-top: 1px solid var(--vp-c-divider); }
.eyebrow { color: var(--vp-c-brand-1); font-size: 11px; font-weight: 700; letter-spacing: .13em; }
h2 { margin: 20px 0; font: 400 clamp(36px, 4vw, 52px)/1.12 Georgia, serif; letter-spacing: -.035em; }
h2 em { color: var(--vp-c-brand-1); }
.live-copy > p:not(.eyebrow) { max-width: 370px; color: var(--vp-c-text-2); font-size: 16px; line-height: 1.8; }
.live-copy > a { display: inline-block; margin-top: 24px; color: var(--vp-c-brand-1); font-size: 14px; font-weight: 600; }
.live-panel { min-width: 0; border: 1px solid var(--vp-c-divider); border-radius: 16px; background: var(--vp-c-bg-elv); box-shadow: 0 20px 60px #302b2908; --result-color: #34745b; }
.live-panel[data-state='invalid'] { --result-color: var(--vp-c-brand-1); }
.live-panel[data-state='pending'] { --result-color: var(--vp-c-text-2); }
:global(.dark) .live-panel[data-state='valid'] { --result-color: #92cdb1; }
.panel-heading { display: flex; align-items: center; gap: 8px; padding: 18px 22px; border-bottom: 1px solid var(--vp-c-divider); font-size: 12px; }
.panel-dot { width: 6px; height: 6px; border-radius: 50%; background: var(--vp-c-brand-1); }
.preview-tag { margin-left: auto; color: var(--vp-c-text-3); font-size: 9px; letter-spacing: .08em; }
.field-area { padding: 28px; }
label { display: block; margin-bottom: 9px; font-size: 13px; font-weight: 600; }
.input-wrap { position: relative; }
input { width: 100%; min-width: 0; padding: 13px 42px 13px 14px; border: 1px solid var(--result-color); border-radius: 6px; background: var(--vp-c-bg); color: var(--vp-c-text-1); font: inherit; font-size: 16px; }
.field-symbol { position: absolute; right: 15px; top: 12px; color: var(--result-color); font-weight: 700; }
.field-message { margin-top: 8px; font-size: 12px; color: var(--result-color); }
.examples { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; margin-top: 24px; font-size: 11px; }
.examples > span { color: var(--vp-c-text-3); margin-right: 3px; }
button { padding: 7px 10px; border: 1px solid var(--vp-c-divider); border-radius: 5px; cursor: pointer; color: var(--vp-c-text-2); }
button:hover { border-color: var(--vp-c-brand-1); color: var(--vp-c-brand-1); }
.result-area { margin: 0 28px; padding: 20px; background: var(--vp-c-bg-alt); border: 1px solid var(--vp-c-divider); border-radius: 8px; }
.result-heading { display: flex; justify-content: space-between; align-items: center; gap: 12px; color: var(--vp-c-text-3); font-size: 10px; letter-spacing: .06em; }
.state-label { color: var(--result-color); letter-spacing: 0; font-size: 11px; }
.result-line { display: flex; gap: 12px; align-items: center; margin: 20px 0 12px; }
.result-line code { font-size: 13px; overflow-wrap: anywhere; }
.result-connector { flex: 1; height: 1px; background: var(--vp-c-divider); }
.result-icon { color: var(--result-color); font-weight: 700; white-space: nowrap; }
.result-area p { font-size: 12px; color: var(--vp-c-text-2); }
.preview-note { margin: 16px 28px 20px; color: var(--vp-c-text-3); font-size: 11px; }
@media (max-width: 767px) { .live-showcase { grid-template-columns: 1fr; gap: 32px; padding: 48px 0; } .live-copy > p:not(.eyebrow) { max-width: none; } }
@media (max-width: 420px) { .field-area { padding: 20px; } .result-area { margin: 0 20px; padding: 16px; } .panel-heading { padding: 16px; flex-wrap: wrap; } .preview-tag { display: none; } }
</style>
