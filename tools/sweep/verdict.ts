export type LayerVerdict = { id: string; label: string; verdict: "green" | "red"; reason?: string };

export type RunVerdict = { ok: boolean; rows: LayerVerdict[] };

type ExpectedLayer = { id: string; label: string };

// The one run-level green rule, for a local sweep and for a CI run combining several jobs' sweeps.
export function runVerdict(expected: ExpectedLayer[], verdicts: LayerVerdict[]): RunVerdict {
  const rows = expected.map((layer) => verdicts.find((verdict) => verdict.id === layer.id) ?? noResult(layer));
  return { ok: rows.every((row) => row.verdict === "green"), rows };
}

const noResult = (layer: ExpectedLayer): LayerVerdict => ({
  id: layer.id,
  label: layer.label,
  verdict: "red",
  reason: "no result (its job did not run or did not finish)",
});
