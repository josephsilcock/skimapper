export type Station = 'spec' | 'design' | 'implement' | 'finish'

export type Step = 'backlog' | Station

export type Status = 'done' | 'running' | 'needs-you' | 'failed' | 'todo'

export type InFlight = {
  id: string
  slug: string
  station: Station
  specMtimeMs: number
  designMtimeMs: number | null
  hasUi: boolean
  mtimeMs: number
}

export type QueueItem = { id: string; title: string }

export type Slice = { sha: string; subject: string; atMs: number }

// A test command from docs/PIPELINE.md, by its role there ("full sweep").
export type TestCommand = { role: string; command: string }

export type TestResult = { role: string; isPassed: boolean; atMs: number }

export type Snapshot = {
  inFlight: InFlight[]
  nextUp: QueueItem[]
  branch: string | null
  slices: Slice[]
  trunk: string
  tests: TestCommand[]
}

// A pipeline skill run: kept across sessions, bound to its feature once known.
export type Run = {
  skill: string
  step: Step
  featureId: string | null
  slug: string | null
  startedAtMs: number
  status: 'running' | 'needs-you' | 'failed' | 'done'
  costUsd: number
  tests: TestResult[]
}

export type TimelineRow = {
  step: Step
  status: Status
  atMs: number | null
  detail: string
  isNext: boolean
  costUsd: number
  children: { status: Status; text: string; atMs: number }[]
}

declare module 'claude-code' {
  interface PluginState {
    'feature-pipeline': {
      snapshot: Snapshot | null
      runs: Run[]
    }
  }
}
