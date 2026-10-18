export type ScheduledRun = { id: number; head_sha: string; html_url: string };
export type Marker = { expired: boolean; workflow_run: { id: number } };

export type SweepDecision = { swept: true; sweptBy: string } | { swept: false; checkedRuns: number };

// C5 skip rule: a nightly is skipped when an earlier scheduled run on the same head left a
// nightly-verdict marker, i.e. carried that commit to a per-layer verdict, green or red.
export function nightlySweep(options: { headSha: string; currentRunId: number; runs: ScheduledRun[]; markers: Marker[] }): SweepDecision {
  const earlierRuns = options.runs.filter((run) => run.head_sha === options.headSha && run.id !== options.currentRunId);
  const markedRunIds = new Set(options.markers.filter((marker) => !marker.expired).map((marker) => marker.workflow_run.id));
  const sweeper = earlierRuns.find((run) => markedRunIds.has(run.id));
  return sweeper ? { swept: true, sweptBy: sweeper.html_url } : { swept: false, checkedRuns: earlierRuns.length };
}
