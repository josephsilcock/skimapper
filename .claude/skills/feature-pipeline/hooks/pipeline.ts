import type {
  InFlight,
  QueueItem,
  Run,
  Slice,
  Station,
  Status,
  Step,
  TestCommand,
  TestResult,
  TimelineRow,
} from '../types'

export const STEPS: readonly Step[] = ['backlog', 'spec', 'design', 'implement', 'finish']

export const SKILL_STEPS: Record<string, Step> = {
  'add-backlog-item': 'backlog',
  'new-feature': 'spec',
  'design-feature': 'design',
  implement: 'implement',
  'ux-iterate': 'implement',
  'finish-feature': 'finish',
}

const SPEC_FILE = /^([FBC]\d+)-(.+?)(-design|-ui)?\.(md|html)$/
const TEST_ROLES = ['fast tests', 'feature-scoped slow tests', 'feature-scoped E2E', 'full sweep']
const SWEEP = 'full sweep'

type SpecEntry = { name: string; mtimeMs: number }

// A spec on its own means design is next; a design beside it means implement is.
export function inFlightFromSpecs(entries: readonly SpecEntry[]): InFlight[] {
  const byId = new Map<string, InFlight>()

  for (const entry of entries) {
    const match = SPEC_FILE.exec(entry.name)
    if (match === null) continue

    const [, id = '', slug = '', suffix] = match
    const item = byId.get(id) ?? {
      id,
      slug,
      station: 'design',
      specMtimeMs: 0,
      designMtimeMs: null,
      hasUi: false,
      mtimeMs: 0,
    }
    if (suffix === undefined) {
      item.slug = slug
      item.specMtimeMs = entry.mtimeMs
    }
    if (suffix === '-design') item.designMtimeMs = entry.mtimeMs
    if (suffix === '-ui') item.hasUi = true
    item.station = item.designMtimeMs === null ? 'design' : 'implement'
    item.mtimeMs = Math.max(item.mtimeMs, entry.mtimeMs)
    byId.set(id, item)
  }

  return [...byId.values()].sort((a, b) => b.mtimeMs - a.mtimeMs)
}

export function nextUpFromBacklog(markdown: string): QueueItem[] {
  const section = markdown.split(/^## Next up\s*$/m)[1]?.split(/^---\s*$/m)[0] ?? ''

  return [...section.matchAll(/^\d+\.\s+\*\*([A-Z]\d+)\*\*\s+(.+)$/gm)].map(
    ([, id = '', title = '']) => ({ id, title: title.trim() }),
  )
}

// docs/PIPELINE.md's role table: the trunk, and each test command once it is no longer TBD.
export function pipelineCommands(markdown: string): { trunk: string; tests: TestCommand[] } {
  const roles = new Map<string, string>()
  for (const [, role = '', command = ''] of markdown.matchAll(/^\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|\s*$/gm)) {
    roles.set(role, command.replace(/^`|`$/g, ''))
  }
  const isSet = (command: string | undefined): command is string =>
    command !== undefined && command !== '' && command !== 'TBD'
  const trunk = roles.get('trunk')

  return {
    trunk: isSet(trunk) ? trunk : 'main',
    tests: TEST_ROLES.flatMap(role => {
      const command = roles.get(role)
      return isSet(command) ? [{ role, command }] : []
    }),
  }
}

// The longest configured command a shell command runs, so a sweep is not mistaken for its fast subset.
export function testRole(command: string, tests: readonly TestCommand[]): string | null {
  const matches = tests.filter(test => command.includes(test.command))
  matches.sort((a, b) => b.command.length - a.command.length)
  return matches[0]?.role ?? null
}

export function withTestResult(results: readonly TestResult[], result: TestResult): TestResult[] {
  return [...results.filter(one => one.role !== result.role), result]
}

export type Report = { skill: string; featureId: string | null; slug: string | null }

// The header line every pipeline skill's completion report opens with.
export function parseReport(answer: string): Report | null {
  const header = /^✓ \/([a-z-]+) — (.*)$/m.exec(answer)
  if (header === null) return null

  const [, skill = '', rest = ''] = header
  const feature = /\b([FBC]\d+) ([a-z0-9][a-z0-9-]*)\b/.exec(rest)
  return { skill, featureId: feature?.[1] ?? null, slug: feature?.[2] ?? null }
}

// /run-pipeline starts a stage by briefing a subagent to follow the skill's file, not by invoking the skill.
export function stageFromAgentPrompt(prompt: string): { skill: string; featureId: string | null } | null {
  const stage = /^Run the `([a-z-]+)` stage of this project's feature pipeline/m.exec(prompt)
  const skill = stage?.[1]
  if (skill === undefined || SKILL_STEPS[skill] === undefined) return null

  const input = /^Your input:(.*)$/m.exec(prompt)?.[1] ?? ''
  return { skill, featureId: /\b([FBC]\d+)\b/.exec(input)?.[1] ?? null }
}

export function nextCommand(id: string, item: InFlight | null, station: Station): string {
  const spec = item === null ? '' : `specs/${item.id}-${item.slug}`

  switch (station) {
    case 'spec':
      return `/new-feature ${id}`
    case 'design':
      return `/design-feature @${spec}.md`
    case 'implement':
      return `/implement @${spec}-design.md`
    case 'finish':
      return '/finish-feature'
  }
}

export type Subject = { id: string; item: InFlight | null; isFinished: boolean }

// The runs a subject's timeline reads: its own, and the newest run while it has no feature yet.
export function runsFor(subject: Subject, runs: readonly Run[]): Run[] {
  const latest = runs.at(-1)
  return runs.filter(run => run.featureId === subject.id || (run.featureId === null && run === latest))
}

// One row per step: the newest run speaks for its own step, the files and
// earlier runs say what is already done, and the first undone step is next.
export function timeline(subject: Subject, slices: readonly Slice[], runs: readonly Run[]): TimelineRow[] {
  const latest = runs.at(-1)
  const reached = latest === undefined ? -1 : STEPS.indexOf(latest.step)
  const rows = STEPS.map((step, i): TimelineRow => {
    const own = runs.filter(one => one.step === step)
    const run = own.at(-1)
    const isLive = run !== undefined && run === latest && run.status !== 'done'
    const isDone = isFileDone(step, subject.item) || i < reached || run?.status === 'done'
    const tests = latestTests(own)
    const hasFailedSweep = tests.some(test => test.role === SWEEP && !test.isPassed)
    const status: Status = isLive ? run.status : isDone ? 'done' : 'todo'

    return {
      step,
      status: hasFailedSweep && status !== 'running' ? 'failed' : status,
      atMs: own[0]?.startedAtMs ?? fileTime(step, subject.item, slices),
      detail: isLive ? liveDetail(run) : doneDetail(step, subject, slices, isDone),
      isNext: false,
      costUsd: own.reduce((sum, one) => sum + one.costUsd, 0),
      children: [
        ...(step === 'implement' ? slices.map(sliceChild) : []),
        ...tests.map(testChild),
      ],
    }
  })

  return markNext(rows, subject)
}

function latestTests(runs: readonly Run[]): TestResult[] {
  return runs.reduce<TestResult[]>((all, run) => run.tests.reduce(withTestResult, all), [])
}

const sliceChild = (slice: Slice) => ({ status: 'done' as const, text: `${slice.sha} ${slice.subject}`, atMs: slice.atMs })

const testChild = (test: TestResult) => ({
  status: test.isPassed ? ('done' as const) : ('failed' as const),
  text: `${test.role} ${test.isPassed ? 'passed' : 'failed'}`,
  atMs: test.atMs,
})

function markNext(rows: TimelineRow[], subject: Subject): TimelineRow[] {
  if (subject.isFinished || rows.some(row => row.status !== 'done' && row.status !== 'todo')) return rows

  const next = rows.find(row => row.status === 'todo')
  if (next === undefined || next.step === 'backlog') return rows

  next.isNext = true
  next.detail = `next → ${nextCommand(subject.id, subject.item, next.step)}`
  return rows
}

function isFileDone(step: Step, item: InFlight | null): boolean {
  switch (step) {
    case 'backlog':
      return true
    case 'spec':
      return item !== null
    case 'design':
      return item?.designMtimeMs != null
    default:
      return false
  }
}

function fileTime(step: Step, item: InFlight | null, slices: readonly Slice[]): number | null {
  switch (step) {
    case 'spec':
      return item?.specMtimeMs || null
    case 'design':
      return item?.designMtimeMs ?? null
    case 'implement':
      return slices[0]?.atMs ?? null
    default:
      return null
  }
}

function liveDetail(run: Run): string {
  switch (run.status) {
    case 'running':
      return `running · /${run.skill}`
    case 'needs-you':
      return `at the gate · /${run.skill} waits on you`
    default:
      return `/${run.skill} ended in an error`
  }
}

function doneDetail(step: Step, subject: Subject, slices: readonly Slice[], isDone: boolean): string {
  const { id, item } = subject
  if (!isDone) return ''

  switch (step) {
    case 'backlog':
      return `${id} in docs/BACKLOG.md`
    case 'spec':
      return item === null ? '' : `specs/${item.id}-${item.slug}.md`
    case 'design':
      return item === null ? '' : `${item.id}-${item.slug}-design.md${item.hasUi ? ' + UI sketch' : ''}`
    case 'implement':
      return slices.length === 0 ? '' : `${slices.length} slice commit${slices.length === 1 ? '' : 's'}`
    default:
      return subject.isFinished ? 'signed off and merged' : ''
  }
}

export const GLYPHS: Record<Status, string> = {
  done: '✓',
  running: '●',
  'needs-you': '◆',
  failed: '✗',
  todo: '○',
}

export function clockTime(ms: number): string {
  const at = new Date(ms)
  return `${String(at.getHours()).padStart(2, '0')}:${String(at.getMinutes()).padStart(2, '0')}`
}

export function dollars(usd: number): string {
  return usd === 0 ? '' : usd < 0.01 ? '<$0.01' : `$${usd.toFixed(2)}`
}
