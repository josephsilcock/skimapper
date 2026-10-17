import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Run, Slice, Snapshot, Status, TimelineRow } from '../types'
import type { Subject } from './pipeline'
import {
  GLYPHS,
  SKILL_STEPS,
  clockTime,
  dollars,
  inFlightFromSpecs,
  nextUpFromBacklog,
  parseReport,
  pipelineCommands,
  runsFor,
  stageFromAgentPrompt,
  testRole,
  timeline,
  withTestResult,
} from './pipeline'

const PANE = 'pipeline'
const MAX_SLICES_SHOWN = 8
const MAX_RUNS_KEPT = 100
const MAIN_LOOP = 'main'
const snapshot = atom({ plugin: 'feature-pipeline', key: 'snapshot' } as const, null)
const runs = atom({ plugin: 'feature-pipeline', key: 'runs' } as const, [])

const COLORS: Record<Status, string> = {
  done: 'success',
  running: 'warning',
  'needs-you': 'magenta',
  failed: 'error',
  todo: 'inactive',
}

const EMPTY: Snapshot = { inFlight: [], nextUp: [], branch: null, slices: [], trunk: 'main', tests: [] }

// Only repos that carry the pipeline skills get the pane and the command.
const isPipelineRepo = ($: EngineInterface) =>
  $.fs.exists('.claude/skills/new-feature/SKILL.md').catch(() => false)

const readText = ($: EngineInterface, path: string) => $.fs.read(path).catch(() => '')

async function readSpecs($: EngineInterface) {
  const entries = await $.fs.list('specs').catch(() => [])
  return inFlightFromSpecs(entries.filter(entry => entry.kind === 'file'))
}

async function git($: EngineInterface, args: string[]) {
  const ran = await $.process.run(['git', ...args]).catch(() => undefined)
  return ran?.exitCode === 0 ? ran.stdout.trim() : null
}

async function readSlices($: EngineInterface, branch: string | null, trunk: string): Promise<Slice[]> {
  if (branch === null || branch === trunk) return []

  const log = await git($, ['log', '--reverse', '--format=%h%x09%ct%x09%s', `${trunk}..HEAD`])
  return (log ?? '').split('\n').filter(Boolean).map(line => {
    const [sha = '', seconds = '0', ...subject] = line.split('\t')
    return { sha, subject: subject.join('\t'), atMs: Number(seconds) * 1000 }
  })
}

async function refresh($: EngineInterface) {
  const { trunk, tests } = pipelineCommands(await readText($, 'docs/PIPELINE.md'))
  const branch = await git($, ['rev-parse', '--abbrev-ref', 'HEAD'])
  const next: Snapshot = {
    inFlight: await readSpecs($),
    nextUp: nextUpFromBacklog(await readText($, 'docs/BACKLOG.md')),
    branch,
    slices: await readSlices($, branch, trunk),
    trunk,
    tests,
  }
  await update($, snapshot, () => next)
  return next
}

// The live stage's feature comes first; then the newest spec; then the head of the queue.
function subjectOf(snap: Snapshot, list: readonly Run[]): Subject | null {
  const latest = list.at(-1)
  if (latest !== undefined && latest.status !== 'done') {
    const id = latest.featureId ?? ''
    const item = snap.inFlight.find(one => one.id === id) ?? null
    return { id, item, isFinished: latest.step === 'finish' && id !== '' && item === null }
  }

  const item = snap.inFlight[0]
  if (item !== undefined) return { id: item.id, item, isFinished: false }

  const head = snap.nextUp[0]
  return head === undefined ? null : { id: head.id, item: null, isFinished: false }
}

function headline(snap: Snapshot, subject: Subject, list: readonly Run[]) {
  if (subject.id === '') return 'new item · no spec yet'

  const slug = subject.item?.slug ?? list.findLast(run => run.featureId === subject.id && run.slug !== null)?.slug
  if (subject.isFinished) return `${subject.id} · ${slug ?? ''} · finished`
  if (slug !== undefined && slug !== null) return `${subject.id} · ${slug}`

  const title = snap.nextUp.find(one => one.id === subject.id)?.title
  const hasStarted = list.some(run => run.featureId === subject.id)
  return [subject.id, title, hasStarted ? undefined : 'not started'].filter(Boolean).join(' · ')
}

const totalCost = (rows: readonly TimelineRow[]) => rows.reduce((sum, row) => sum + row.costUsd, 0)

function settleLatest(list: Run[], from: Run['status'][], to: Run['status']): Run[] {
  return changeLatest(list, latest => (from.includes(latest.status) ? { ...latest, status: to } : latest))
}

function changeLatest(list: Run[], change: (latest: Run) => Run): Run[] {
  const latest = list.at(-1)
  return latest === undefined ? list : [...list.slice(0, -1), change(latest)]
}

// Every change to the runs is kept across sessions, under this repo's folder.
async function changeRuns($: EngineInterface, storeKey: string, change: (list: Run[]) => Run[]) {
  const list = await update($, runs, current => change(current).slice(-MAX_RUNS_KEPT))
  if (storeKey !== '') await $.store.set(storeKey, list)
}

// A stage starting settles the one before it. Its feature is the one named, else the
// newest spec for a stage past spec; a completion report corrects it later.
async function startRun($: EngineInterface, storeKey: string, skill: string, named: string | null) {
  const step = SKILL_STEPS[skill]
  if (step === undefined) return

  const snap = (await read($, snapshot)) ?? EMPTY
  const guessed = step === 'backlog' || step === 'spec' ? undefined : snap.inFlight[0]
  const featureId = named ?? guessed?.id ?? null
  const run: Run = {
    skill,
    step,
    featureId,
    slug: snap.inFlight.find(one => one.id === featureId)?.slug ?? null,
    startedAtMs: await $.clock.now(),
    status: 'running',
    costUsd: 0,
    tests: [],
  }
  await changeRuns($, storeKey, list => [...settleLatest(list, ['running', 'needs-you', 'failed'], 'done'), run])
}

function summary(snap: Snapshot, rows: TimelineRow[], subject: Subject, list: readonly Run[]) {
  const lines = [`${headline(snap, subject, list)}  ${dollars(totalCost(rows))}`, '']
  for (const row of rows) {
    const at = row.atMs === null ? '     ' : clockTime(row.atMs)
    lines.push(`${at} ${GLYPHS[row.status]} ${row.step.padEnd(10)} ${row.detail}  ${dollars(row.costUsd)}`.trimEnd())
  }
  return lines.join('\n')
}

export const register: Register = on => {
  let isEnabled = false
  let storeKey = ''
  let lastCostUsd: number | null = null
  const busyLoops = new Set<string>()

  on('session.start', async ($, e, next) => {
    const started = await next(e)
    isEnabled = await isPipelineRepo($)
    if (!isEnabled) return started

    storeKey = `runs:${e.cwd}`
    const kept = await $.store.get(storeKey)
    if ((await read($, runs)).length === 0 && Array.isArray(kept)) await update($, runs, () => kept as Run[])
    lastCostUsd = (await $.session.usage()).cost?.usd ?? null

    await $.command.register({
      name: 'pipeline',
      description: 'Open the feature pipeline pane',
    })
    await refresh($)
    void $.ui.open({ id: PANE, title: 'Pipeline' })
    return started
  })

  on('skill.prompt', async ($, e, next) => {
    if (SKILL_STEPS[e.skill] !== undefined) await startRun($, storeKey, e.skill, null)
    return next(e)
  })

  on('tool.call', { tool: 'Agent' }, async ($, e, next) => {
    const stage = stageFromAgentPrompt(e.prompt)
    if (stage !== null) await startRun($, storeKey, stage.skill, stage.featureId)
    return next(e)
  })

  on('turn.start', async ($, e, next) => {
    busyLoops.add(e.agentId ?? MAIN_LOOP)
    await changeRuns($, storeKey, list => settleLatest(list, ['needs-you', 'failed'], 'running'))
    return next(e)
  })

  // A completion report names the run's feature. Every loop idle mid-stage (the main one and
  // any background stage subagent) means the stage is at its gate, waiting on the person.
  on('turn.complete', async ($, e, next) => {
    const report = parseReport(e.answer)
    if (report?.featureId != null) {
      await changeRuns($, storeKey, list => changeLatest(list, latest =>
        latest.skill === report.skill ? { ...latest, featureId: report.featureId, slug: report.slug } : latest))
    }
    busyLoops.delete(e.agentId ?? MAIN_LOOP)
    if (busyLoops.size === 0) {
      const outcome = e.reason === 'error' ? 'failed' : 'needs-you'
      await changeRuns($, storeKey, list => settleLatest(list, ['running'], outcome))
    }
    if (isEnabled) await refresh($)
    return next(e)
  })

  // What the session spends while a stage is live is that stage's cost.
  on('session.measure', async ($, e, next) => {
    const usd = e.cost?.usd
    if (usd !== undefined) {
      const spent = lastCostUsd === null ? 0 : usd - lastCostUsd
      lastCostUsd = usd
      if (spent > 0) {
        await changeRuns($, storeKey, list => changeLatest(list, latest =>
          latest.status === 'done' ? latest : { ...latest, costUsd: latest.costUsd + spent }))
      }
    }
    return next(e)
  })

  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    const snap = await read($, snapshot)
    const role = snap === null ? null : testRole(e.command, snap.tests)
    const ran = await next(e)
    if (role !== null && ran.deny === undefined) {
      const result = { role, isPassed: ran.isError !== true, atMs: await $.clock.now() }
      await changeRuns($, storeKey, list => changeLatest(list, latest => ({ ...latest, tests: withTestResult(latest.tests, result) })))
    }
    return ran
  })

  on('command.run', { command: 'pipeline' }, async $ => {
    const snap = await refresh($)
    const opened = await $.ui.open({ id: PANE, title: 'Pipeline' })
    if (opened.isPlaced) return { text: 'Pipeline pane opened.' }

    const list = await read($, runs)
    const subject = subjectOf(snap, list)
    if (subject === null) return { text: 'Nothing in flight and the queue is empty.' }
    return { text: summary(snap, timeline(subject, snap.slices, runsFor(subject, list)), subject, list) }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    const snap = (await read($, snapshot)) ?? EMPTY
    const list = await read($, runs)
    const subject = subjectOf(snap, list)

    if (subject === null) {
      return <Text dimColor>Nothing in flight and the Next-up queue is empty.</Text>
    }

    const rows = timeline(subject, subject.isFinished ? [] : snap.slices, runsFor(subject, list))
    const others = snap.inFlight.filter(one => one.id !== subject.id)
    const queue = snap.nextUp.filter(one => one.id !== subject.id).slice(0, 3)

    return (
      <Box flexDirection="column">
        <Box flexDirection="row">
          <Box flexGrow={1} flexShrink={1}>
            <Text bold wrap="truncate-end">{headline(snap, subject, list)}</Text>
          </Box>
          <Text dimColor>{dollars(totalCost(rows))}</Text>
        </Box>
        <Text dimColor>{snap.branch === null ? '' : `on ${snap.branch}`}</Text>
        <Text> </Text>
        {rows.map((row, i) => (
          <Box key={row.step} flexDirection="column">
            <Box flexDirection="row">
              <Box width={6}>
                <Text dimColor>{row.atMs === null ? '' : clockTime(row.atMs)}</Text>
              </Box>
              <Text color={COLORS[row.status]}>{GLYPHS[row.status]} </Text>
              <Box width={11}>
                <Text bold={row.status !== 'done' && row.status !== 'todo'} dimColor={row.status === 'todo' && !row.isNext}>
                  {row.step}
                </Text>
              </Box>
              <Box flexGrow={1} flexShrink={1}>
                <Text color={row.status === 'todo' ? undefined : COLORS[row.status]} dimColor={row.status === 'done' || row.status === 'todo'} wrap="truncate-end">
                  {row.detail}
                </Text>
              </Box>
              <Text dimColor> {dollars(row.costUsd)}</Text>
            </Box>
            {row.children.length > MAX_SLICES_SHOWN && (
              <Box marginLeft={6}>
                <Text dimColor>│ … {row.children.length - MAX_SLICES_SHOWN} earlier</Text>
              </Box>
            )}
            {row.children.slice(-MAX_SLICES_SHOWN).map(child => (
              <Box flexDirection="row" marginLeft={6}>
                <Text dimColor>│ ├ </Text>
                <Text color={COLORS[child.status]}>{GLYPHS[child.status]} </Text>
                <Box flexShrink={1}>
                  <Text wrap="truncate-end">{child.text}</Text>
                </Box>
                <Text dimColor> {clockTime(child.atMs)}</Text>
              </Box>
            ))}
            {i < rows.length - 1 && (
              <Box marginLeft={6}>
                <Text dimColor>│</Text>
              </Box>
            )}
          </Box>
        ))}
        <Text> </Text>
        {others.length > 0 && (
          <Text dimColor wrap="truncate-end">
            also in flight: {others.map(one => `${one.id} ${one.slug}`).join(', ')}
          </Text>
        )}
        {queue.length > 0 && (
          <Text dimColor wrap="truncate-end">
            next up: {queue.map(one => `${one.id} ${one.title}`).join(' · ')}
          </Text>
        )}
        <Text> </Text>
        <Box flexDirection="row" flexWrap="wrap" columnGap={2}>
          {(['done', 'running', 'needs-you', 'failed', 'todo'] as const).map(status => (
            <Text color={COLORS[status]}>
              {GLYPHS[status]} {status === 'needs-you' ? 'needs you' : status === 'todo' ? 'to come' : status}
            </Text>
          ))}
        </Box>
      </Box>
    )
  })
}
