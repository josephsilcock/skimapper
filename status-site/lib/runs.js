import { readJunit } from "./junit.js";

// A test job's results artifact is named junit-<job id> (.github/workflows/sweep.yml).
const junitArtifact = (artifact) => artifact.name.startsWith("junit-");

// One run and the JUnit reports its test jobs uploaded.
export async function readRun(github, id) {
  const run = await github.run(id);
  const artifacts = (await github.artifacts(id)).filter(junitArtifact);
  const files = await Promise.all(artifacts.map((artifact) => github.files(artifact.id)));
  return {
    run: { id: run.id, number: run.run_number, url: run.html_url },
    reports: files.flatMap((byName) => Object.values(byName).map(readJunit)),
  };
}
