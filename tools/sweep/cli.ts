// A command line the tool cannot accept; the entry point reports it on one line rather than with a stack.
export class UsageError extends Error {}

// Runs an entry point's body. A UsageError becomes one `error:` line and exit 1, as Bash `fail` does;
// any other fault is rethrown so it keeps its stack.
export async function runCli(body: () => Promise<void> | void): Promise<void> {
  try {
    await body();
  } catch (error) {
    if (!(error instanceof UsageError)) throw error;
    process.stderr.write(`error: ${error.message}\n`);
    process.exitCode = 1;
  }
}
