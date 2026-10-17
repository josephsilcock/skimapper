import { expect, test } from 'claude-code/testing'

import type { AgentContext, ContextInfo, Run } from '../types'
import {
  inFlightFromSpecs,
  nextUpFromBacklog,
  parseReport,
  pipelineCommands,
  runsFor,
  stageFromAgentPrompt,
  testRole,
  timeline,
} from './pipeline'

function only<T>(list: readonly T[]): T {
  const [head] = list
  if (head === undefined || list.length !== 1) throw new Error(`expected one item, got ${list.length}`)
  return head
}

const statuses = (rows: { status: string }[]) => rows.map(row => row.status)

const run = (fields: Partial<Run> & Pick<Run, 'skill' | 'step'>): Run => ({
  featureId: 'F1',
  slug: 'resort-list',
  startedAtMs: 1,
  status: 'done',
  costUsd: 0,
  tests: [],
  ...fields,
})

test('a spec alone marks backlog and spec done and design next', () => {
  const item = only(inFlightFromSpecs([
    { name: 'README.md', mtimeMs: 1 },
    { name: 'F1-resort-list.md', mtimeMs: 2 },
  ]))
  const rows = timeline({ id: item.id, item, isFinished: false }, [], [])

  expect(statuses(rows)).toEqual(['done', 'done', 'todo', 'todo', 'todo'])
  expect(rows[2]?.isNext).toBe(true)
  expect(rows[2]?.detail).toBe('next → /design-feature @specs/F1-resort-list.md')
})

test('a design and slice commits put implement next, with the slices under it', () => {
  const item = only(inFlightFromSpecs([
    { name: 'F5-resort-map-design.md', mtimeMs: 3 },
    { name: 'F5-resort-map.md', mtimeMs: 2 },
  ]))
  const rows = timeline({ id: item.id, item, isFinished: false }, [{ sha: 'abc1234', subject: 'Slice 1', atMs: 5 }], [])

  expect(statuses(rows)).toEqual(['done', 'done', 'done', 'todo', 'todo'])
  expect(rows[3]?.detail).toBe('next → /implement @specs/F5-resort-map-design.md')
  expect(rows[3]?.children).toEqual([{ status: 'done', text: 'abc1234 Slice 1', atMs: 5 }])
})

test('the newest run shows its own status and passes the steps before it', () => {
  const rows = timeline({ id: 'F1', item: null, isFinished: false }, [], [
    run({ skill: 'implement', step: 'implement', startedAtMs: 9, status: 'needs-you' }),
  ])

  expect(statuses(rows)).toEqual(['done', 'done', 'done', 'needs-you', 'todo'])
  expect(rows[3]?.atMs).toBe(9)
  expect(rows.some(row => row.isNext)).toBe(false)
})

test('each stage costs what its runs spent', () => {
  const rows = timeline({ id: 'F1', item: null, isFinished: false }, [], [
    run({ skill: 'new-feature', step: 'spec', costUsd: 1.5 }),
    run({ skill: 'design-feature', step: 'design', costUsd: 2 }),
    run({ skill: 'implement', step: 'implement', costUsd: 3, status: 'running' }),
    run({ skill: 'ux-iterate', step: 'implement', costUsd: 0.25, status: 'running' }),
  ])

  expect(rows.map(row => row.costUsd)).toEqual([0, 1.5, 2, 3.25, 0])
})

test('a failed full sweep fails its stage; a failing fast test only shows under it', () => {
  const rows = timeline({ id: 'F1', item: null, isFinished: false }, [], [
    run({ skill: 'implement', step: 'implement', tests: [{ role: 'fast tests', isPassed: false, atMs: 2 }] }),
    run({ skill: 'finish-feature', step: 'finish', status: 'needs-you', tests: [{ role: 'full sweep', isPassed: false, atMs: 3 }] }),
  ])

  expect(statuses(rows)).toEqual(['done', 'done', 'done', 'done', 'failed'])
  expect(rows[3]?.children).toEqual([{ status: 'failed', text: 'fast tests failed', atMs: 2 }])
  expect(rows[4]?.children).toEqual([{ status: 'failed', text: 'full sweep failed', atMs: 3 }])
})

test("each stage lists the subagents spawned while it was live, with how full each one's context is", () => {
  const spec = run({ skill: 'new-feature', step: 'spec', startedAtMs: 10 })
  const design = run({ skill: 'design-feature', step: 'design', startedAtMs: 20, status: 'running' })
  const agents: AgentContext[] = [
    { id: 'a1', description: 'C4 spec stage', runStartedAtMs: 10, startedAtMs: 11, model: 'claude-opus-5-5', tokens: 150_000, isBusy: false },
    { id: 'a2', description: 'C4 design stage', runStartedAtMs: 20, startedAtMs: 21, model: 'claude-opus-5-5', tokens: 42_000, isBusy: true },
    { id: 'a3', description: 'Design skeptic', runStartedAtMs: 20, startedAtMs: 22, model: 'claude-haiku-5-5', tokens: 9_400, isBusy: true },
  ]
  const context: ContextInfo = { mainModel: 'claude-opus-5-5', window: 200_000, percent: 12 }
  const rows = timeline({ id: 'C4', item: null, isFinished: false }, [], [spec, design], agents, context)

  expect(rows[1]?.children).toEqual([{ status: 'done', text: 'C4 spec stage · ctx 75%', atMs: 11 }])
  expect(rows[2]?.children).toEqual([
    { status: 'running', text: 'C4 design stage · ctx 21%', atMs: 21 },
    { status: 'running', text: 'Design skeptic · ctx 9k tokens', atMs: 22 },
  ])
})

test('a finished feature reads done all the way along, with nothing next', () => {
  const rows = timeline({ id: 'F1', item: null, isFinished: true }, [], [
    run({ skill: 'finish-feature', step: 'finish', status: 'done' }),
  ])

  expect(statuses(rows)).toEqual(['done', 'done', 'done', 'done', 'done'])
  expect(rows[4]?.detail).toBe('signed off and merged')
  expect(rows.some(row => row.isNext)).toBe(false)
})

test('a timeline reads its own feature runs, and the newest run until it has a feature', () => {
  const mine = run({ skill: 'design-feature', step: 'design' })
  const other = run({ skill: 'new-feature', step: 'spec', featureId: 'F5' })
  const unbound = run({ skill: 'new-feature', step: 'spec', featureId: null })

  expect(runsFor({ id: 'F1', item: null, isFinished: false }, [mine, other, unbound])).toEqual([mine, unbound])
  expect(runsFor({ id: 'F1', item: null, isFinished: false }, [unbound, mine])).toEqual([mine])
})

test('a queued item that has not started has the new-feature command next', () => {
  const rows = timeline({ id: 'C4', item: null, isFinished: false }, [], [])

  expect(statuses(rows)).toEqual(['done', 'todo', 'todo', 'todo', 'todo'])
  expect(rows[1]?.detail).toBe('next → /new-feature C4')
})

test('a completion report names its skill and feature', () => {
  const report = '━━━━\n✓ /design-feature — F1 resort-list: decisions, seams and risks agreed\nPipeline: spec ✓ · [design]'

  expect(parseReport(report)).toEqual({ skill: 'design-feature', featureId: 'F1', slug: 'resort-list' })
  expect(parseReport('✓ /implement — 3 vertical slices built test-first')).toEqual({ skill: 'implement', featureId: null, slug: null })
  expect(parseReport('just chatting')).toBeNull()
})

test("a /run-pipeline stage brief names the stage's skill and feature", () => {
  const spec = 'Run the `new-feature` stage of this project\'s feature pipeline. Read `.claude/skills/new-feature/SKILL.md` and follow it exactly.\n\nYour input: backlog ID **C4** (in `docs/BACKLOG.md`).'
  const design = 'Run the `design-feature` stage of this project\'s feature pipeline.\n\nYour input: `specs/F1-resort-list.md`.'

  expect(stageFromAgentPrompt(spec)).toEqual({ skill: 'new-feature', featureId: 'C4' })
  expect(stageFromAgentPrompt(design)).toEqual({ skill: 'design-feature', featureId: 'F1' })
  expect(stageFromAgentPrompt('Run the `review-last-commit` stage')).toBeNull()
  expect(stageFromAgentPrompt('Review this spec adversarially')).toBeNull()
})

test('the trunk and the configured test commands are read from PIPELINE.md', () => {
  const pipeline = [
    '| Role | Command |',
    '|---|---|',
    '| fast tests | `pnpm test` |',
    '| feature-scoped E2E | TBD |',
    '| full sweep | pnpm test:all |',
    '| trunk | trunk |',
  ].join('\n')
  const { trunk, tests } = pipelineCommands(pipeline)

  expect(trunk).toBe('trunk')
  expect(tests).toEqual([
    { role: 'fast tests', command: 'pnpm test' },
    { role: 'full sweep', command: 'pnpm test:all' },
  ])
  expect(testRole('cd app && pnpm test:all 2>&1', tests)).toBe('full sweep')
  expect(testRole('pnpm test -- --watch=false', tests)).toBe('fast tests')
  expect(testRole('git status', tests)).toBeNull()
})

test('the next-up queue is read from the backlog', () => {
  const backlog = '# Backlog\n\n## Next up\n\nintro\n\n1. **C4** Initial technical decisions\n2. **F1** Resort list\n\n---\n\n3. **F9** not this'

  expect(nextUpFromBacklog(backlog)).toEqual([
    { id: 'C4', title: 'Initial technical decisions' },
    { id: 'F1', title: 'Resort list' },
  ])
})
