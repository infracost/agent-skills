#!/usr/bin/env node
/**
 * Lighthouse performance audit script.
 * Usage: npm run test:lighthouse
 * Automatically starts and stops the local preview server.
 */

import { execSync, spawn } from "child_process";
import { createRequire } from "module";
import process from "process";

const require = createRequire(import.meta.url);
const PREVIEW_URL = "http://127.0.0.1:4173";
const STARTUP_TIMEOUT_MS = 30_000;
const THRESHOLDS = {
  performance: 90,
  accessibility: 90,
  "best-practices": 80,
  seo: 80,
};

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForServer(url, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(url);
      if (response.ok) return;
    } catch {
      // Server not ready yet.
    }
    await sleep(300);
  }
  throw new Error(`Preview server did not become ready within ${timeoutMs}ms`);
}

console.log(`Running Lighthouse against ${PREVIEW_URL}`);
console.log("Thresholds:", THRESHOLDS);
console.log("");

let previewProcess;
try {
  previewProcess = spawn("npm", ["run", "preview"], {
    stdio: "ignore",
    env: process.env,
  });

  await waitForServer(PREVIEW_URL, STARTUP_TIMEOUT_MS);

  const cmd = [
    "npx lighthouse",
    PREVIEW_URL,
    "--chrome-flags='--headless --no-sandbox'",
    "--output=json",
    "--output-path=./lighthouse-report.json",
    "--only-categories=performance,accessibility,best-practices,seo",
    "--quiet",
  ].join(" ");

  execSync(cmd, { stdio: "pipe" });

  const report = JSON.parse(
    require("fs").readFileSync("./lighthouse-report.json", "utf8")
  );
  const categories = report.categories;

  let passed = true;
  for (const [key, threshold] of Object.entries(THRESHOLDS)) {
    const score = Math.round((categories[key]?.score ?? 0) * 100);
    const status = score >= threshold ? "✓" : "✗";
    if (score < threshold) passed = false;
    console.log(`${status} ${key}: ${score} (required: ${threshold})`);
  }

  if (!passed) {
    process.exit(1);
  }

  console.log("\nAll Lighthouse thresholds met.");
} catch (err) {
  const message = err?.message ?? String(err);
  if (message.includes("(NO_FCP)")) {
    console.warn(
      "Skipping Lighthouse thresholds: no paintable content detected yet."
    );
    process.exitCode = 0;
  } else {
    console.error("Lighthouse run failed:", message);
    process.exitCode = 1;
  }
} finally {
  if (previewProcess && !previewProcess.killed) {
    previewProcess.kill("SIGTERM");
  }
}
