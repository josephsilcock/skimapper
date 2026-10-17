import type { SessionMeasureInput } from 'claude-code'
import { expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

const PANE = {
  component: 'Pane',
  requestId: 'pipeline',
  props: {
    title: 'Pipeline',
    isFocused: false,
    bodyColumns: 60,
    placement: 'dock',
    scroll: { offset: 0, bodyRows: 30 },
    view: {},
  },
} as const

const REPORT = '✓ /new-feature — spec written for F22 trail-grades\nPipeline: [spec] · design · implement · finish'
const TURN_END = { answer: REPORT, durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer' } as const

const measure = (usd: number): SessionMeasureInput => ({
  context: { window: 200000, tokens: 0 },
  rateLimits: [],
  cost: { usd },
  changed: ['cost'],
})

async function seesOnEverySurface($: Engine, texts: RegExp[]) {
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ plugin: 'feature-pipeline', surface, ...PANE })
    for (const text of texts) expect(await ui.find({ type: 'Text', text })).toBeDefined()
    await ui.unmount()
  }
}

test('a stage runs, costs what the session spends, and waits on the person at its gate', async ($, on) => {
  mock.clock(on)
  on('skill.prompt', (_, e) => ({ text: e.text }))
  on('turn.complete', () => ({ text: '' }))
  on('session.measure', (_, e) => ({ changed: e.changed }))

  await $.skill.prompt({ skill: 'new-feature', text: '' })
  await $.session.measure(measure(1))
  await $.session.measure(measure(2.5))
  await seesOnEverySurface($, [/new item · no spec yet/, /running · \/new-feature/, /\$1\.50/])

  await $.turn.complete(TURN_END)
  await seesOnEverySurface($, [/F22 · trail-grades/, /at the gate · \/new-feature waits on you/])
})
