import { spawnSync } from "node:child_process";

const maxAttempts = 3;
const retryDelayMs = 5_000;
const retryableCodes = new Set([
  "EAI_AGAIN",
  "ECONNRESET",
  "ECONNREFUSED",
  "ENETUNREACH",
  "ETIMEDOUT",
]);

function parseReport(stdout) {
  try {
    return JSON.parse(stdout);
  } catch {
    return null;
  }
}

function isRetryableFailure(report, stderr) {
  const code = String(report?.error?.code ?? "").toUpperCase();
  if (retryableCodes.has(code) || /^E5\d\d$/.test(code)) {
    return true;
  }

  const summary = String(report?.error?.summary ?? "");
  return /\b5\d\d\b|service unavailable|timed? out|network/i.test(
    `${summary}\n${stderr}`,
  );
}

function printResult(result) {
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
}

for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
  const result = spawnSync(
    "npm",
    [
      "audit",
      "--json",
      "--audit-level=moderate",
      "--fetch-retries=0",
      "--fetch-timeout=30000",
    ],
    { encoding: "utf8", maxBuffer: 10 * 1024 * 1024 },
  );

  if (result.error) {
    throw result.error;
  }

  if (result.status === 0) {
    printResult(result);
    process.exit(0);
  }

  const report = parseReport(result.stdout);
  if (!isRetryableFailure(report, result.stderr)) {
    printResult(result);
    process.exit(result.status ?? 1);
  }

  const code = report?.error?.code ?? "registry unavailable";
  if (attempt < maxAttempts) {
    console.warn(
      `::warning::npm audit attempt ${attempt}/${maxAttempts} failed (${code}); retrying.`,
    );
    await new Promise((resolve) => setTimeout(resolve, retryDelayMs));
  } else {
    printResult(result);
    console.error(
      `::error::npm audit could not reach the advisory service after ${maxAttempts} attempts. Refusing to continue without a completed audit.`,
    );
    process.exit(result.status ?? 1);
  }
}
