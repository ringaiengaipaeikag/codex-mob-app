#!/usr/bin/env node
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const key = argv[i];
    if (!key.startsWith('--')) continue;
    const name = key.slice(2).replace(/-([a-z])/g, (_, c) => c.toUpperCase());
    const next = argv[i + 1];
    if (!next || next.startsWith('--')) {
      args[name] = true;
    } else {
      args[name] = next;
      i += 1;
    }
  }
  return args;
}

function usage() {
  return `Usage:
  node record_playwright_cdp.mjs --authorized --url <url> --out <run-dir> [options]

Options:
  --action-label <text>       Human label for the recorded action.
  --capture-depth <mode>      browser-cdp or browser-cdp-proxy.
  --click-selector <selector> Click after initial page load.
  --wait-for-selector <sel>   Wait for selector before finishing.
  --wait-for-url <pattern>    Wait for a URL pattern before finishing.
  --wait-ms <ms>              Extra wait before stopping capture. Default 1000.
  --timeout-ms <ms>           Navigation/action timeout. Default 45000.
  --headed                    Run headed browser.
  --include-sources           Include Playwright trace source files.
  --js-runtime-observer       Inject sanitized JS API observer and export js-runtime-events.json.
  --js-coverage               Collect sanitized CDP precise JavaScript coverage.
  --chrome-path <path>        Browser executable override.
  --dry-run                   Validate args and write manifest/capture-plan only.
`;
}

function runId() {
  const stamp = new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 14);
  const suffix = crypto.randomBytes(3).toString('hex');
  return `${stamp}-${suffix}`;
}

function defaultChromePath() {
  const candidates = [
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
    '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
  ];
  for (const item of candidates) {
    if (fs.existsSync(item)) return item;
  }
  return '';
}

function writeJson(file, value) {
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
}

function ndjsonWriter(file) {
  return (value) => {
    fs.appendFileSync(file, `${JSON.stringify(value)}\n`, 'utf8');
  };
}

const sensitiveKey = /(authorization|cookie|set-cookie|token|secret|password|passwd|api[-_]?key|csrf|session)/i;

function redactValue(value) {
  if (value === null || value === undefined) return value;
  if (typeof value === 'string') {
    return value
      .replace(/bearer\s+[a-z0-9._+/=-]{12,}/ig, 'Bearer [REDACTED]')
      .replace(/\b\d{3}-\d{2}-\d{4}\b/g, '[REDACTED-SSN]');
  }
  if (Array.isArray(value)) return value.map(redactValue);
  if (typeof value === 'object') {
    const out = {};
    for (const [key, item] of Object.entries(value)) {
      out[key] = sensitiveKey.test(key) && key !== 'authorization_confirmed' ? '[REDACTED]' : redactValue(item);
    }
    return out;
  }
  return value;
}

function safeUrl(raw) {
  try {
    const parsed = new URL(raw);
    parsed.username = '';
    parsed.password = '';
    parsed.search = parsed.search ? '?[REDACTED_QUERY]' : '';
    parsed.hash = '';
    return parsed.toString();
  } catch {
    return String(raw || '');
  }
}

function originOf(raw) {
  try {
    return new URL(raw).origin;
  } catch {
    return '';
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(usage());
    return 0;
  }
  if (!args.authorized) {
    console.error('FAIL --authorized is required for any capture run, including dry-run.');
    return 2;
  }
  if (!args.url) {
    console.error('FAIL --url is required.');
    console.error(usage());
    return 2;
  }

  const id = args.runId || runId();
  const outDir = path.resolve(args.out || path.join(process.cwd(), '.baza', 'web-re', id));
  fs.mkdirSync(outDir, { recursive: true });

  const manifestPath = path.join(outDir, 'manifest.json');
  const manifest = {
    run_id: id,
    created_at: new Date().toISOString(),
    status: 'planned',
    tool: 'record_playwright_cdp.mjs',
    target_origin: originOf(args.url),
    target_url_redacted: safeUrl(args.url),
    action_label: args.actionLabel || 'web action capture',
    authorization_confirmed: true,
    capture_depth: args.captureDepth || 'browser-cdp',
    isolated_profile: true,
    traffic_modification: false,
    raw_artifacts_sensitive: true,
    js_runtime_observer: Boolean(args.jsRuntimeObserver),
    js_coverage: Boolean(args.jsCoverage),
    artifacts: {},
  };
  writeJson(manifestPath, manifest);

  if (args.dryRun) {
    const planPath = path.join(outDir, 'capture-plan.json');
    writeJson(planPath, {
      run_id: id,
      mode: 'dry-run',
      would_record: [
        'playwright-trace.zip',
        'network.har',
        'cdp-events.ndjson',
        'requests.ndjson',
        'responses.ndjson',
        'console.ndjson',
        'runtime-exceptions.ndjson',
        'scripts.ndjson',
        'workers.ndjson',
        ...(args.jsRuntimeObserver ? ['js-runtime-events.json'] : []),
        ...(args.jsCoverage ? ['js-coverage.json'] : []),
      ],
    });
    manifest.status = 'dry-run';
    manifest.artifacts.capture_plan = 'capture-plan.json';
    writeJson(manifestPath, manifest);
    console.log(JSON.stringify({ ok: true, dry_run: true, out_dir: outDir, manifest: manifestPath }, null, 2));
    return 0;
  }

  let playwright;
  try {
    playwright = await import('playwright');
  } catch (err) {
    manifest.status = 'failed';
    manifest.error = 'Node package `playwright` is not installed or not resolvable.';
    writeJson(manifestPath, manifest);
    console.error('FAIL Node package `playwright` is not installed. Run dependency setup before live capture.');
    return 3;
  }

  const cdpEvents = ndjsonWriter(path.join(outDir, 'cdp-events.ndjson'));
  const requests = ndjsonWriter(path.join(outDir, 'requests.ndjson'));
  const responses = ndjsonWriter(path.join(outDir, 'responses.ndjson'));
  const consoleEvents = ndjsonWriter(path.join(outDir, 'console.ndjson'));
  const exceptions = ndjsonWriter(path.join(outDir, 'runtime-exceptions.ndjson'));
  const scripts = ndjsonWriter(path.join(outDir, 'scripts.ndjson'));
  const workers = ndjsonWriter(path.join(outDir, 'workers.ndjson'));

  const tracePath = path.join(outDir, 'playwright-trace.zip');
  const harPath = path.join(outDir, 'network.har');
  const jsRuntimeEventsPath = path.join(outDir, 'js-runtime-events.json');
  const jsCoveragePath = path.join(outDir, 'js-coverage.json');
  const timeout = Number(args.timeoutMs || 45000);
  const waitMs = Number(args.waitMs || 1000);
  const executablePath = args.chromePath || defaultChromePath() || undefined;

  let browser;
  try {
    browser = await playwright.chromium.launch({
      headless: !args.headed,
      executablePath,
    });
    const context = await browser.newContext({
      ignoreHTTPSErrors: true,
      recordHar: {
        path: harPath,
        mode: 'full',
        content: 'omit',
      },
    });
    if (args.jsRuntimeObserver) {
      const observerPath = path.join(SCRIPT_DIR, 'js_runtime_observer.js');
      await context.addInitScript({ content: fs.readFileSync(observerPath, 'utf8') });
    }
    await context.tracing.start({
      screenshots: true,
      snapshots: true,
      sources: Boolean(args.includeSources),
    });

    const page = await context.newPage();
    context.on('serviceworker', (worker) => {
      workers({
        ts: new Date().toISOString(),
        source: 'playwright',
        event: 'serviceworker',
        type: 'serviceworker',
        url: safeUrl(worker.url()),
      });
    });
    page.on('worker', (worker) => {
      workers({
        ts: new Date().toISOString(),
        source: 'playwright',
        event: 'worker',
        type: 'worker',
        url: safeUrl(worker.url()),
      });
      worker.on('close', () => {
        workers({
          ts: new Date().toISOString(),
          source: 'playwright',
          event: 'worker-close',
          type: 'worker',
          url: safeUrl(worker.url()),
        });
      });
    });
    const client = await context.newCDPSession(page);
    for (const domain of ['Network', 'Runtime', 'Page', 'Log', 'Performance', 'Debugger', 'Profiler', 'Target']) {
      try {
        await client.send(`${domain}.enable`);
      } catch {
        // Some domains may be unavailable in a browser build; capture continues.
      }
    }

    const captureCdp = (method) => (params) => {
      cdpEvents({ ts: new Date().toISOString(), source: 'cdp', method, params: redactValue(params) });
    };
    client.on('Network.requestWillBeSent', captureCdp('Network.requestWillBeSent'));
    client.on('Network.responseReceived', captureCdp('Network.responseReceived'));
    client.on('Network.loadingFinished', captureCdp('Network.loadingFinished'));
    client.on('Network.webSocketCreated', captureCdp('Network.webSocketCreated'));
    client.on('Network.webSocketFrameSent', captureCdp('Network.webSocketFrameSent'));
    client.on('Network.webSocketFrameReceived', captureCdp('Network.webSocketFrameReceived'));
    client.on('Runtime.consoleAPICalled', captureCdp('Runtime.consoleAPICalled'));
    client.on('Runtime.exceptionThrown', (params) => {
      exceptions({ ts: new Date().toISOString(), source: 'cdp', method: 'Runtime.exceptionThrown', params: redactValue(params) });
    });
    client.on('Log.entryAdded', captureCdp('Log.entryAdded'));
    client.on('Target.targetCreated', (params) => {
      const info = params.targetInfo || {};
      if (['worker', 'service_worker', 'shared_worker'].includes(info.type)) {
        workers({
          ts: new Date().toISOString(),
          source: 'cdp',
          event: 'Target.targetCreated',
          type: info.type,
          targetId: info.targetId,
          url: safeUrl(info.url),
        });
      }
      cdpEvents({ ts: new Date().toISOString(), source: 'cdp', method: 'Target.targetCreated', params: redactValue(params) });
    });
    client.on('Debugger.scriptParsed', (params) => {
      scripts({
        ts: new Date().toISOString(),
        source: 'cdp',
        method: 'Debugger.scriptParsed',
        url: safeUrl(params.url),
        scriptId: params.scriptId,
        hash: params.hash,
        startLine: params.startLine,
        endLine: params.endLine,
      });
    });
    client.on('Page.lifecycleEvent', captureCdp('Page.lifecycleEvent'));

    let coverageStarted = false;
    if (args.jsCoverage) {
      try {
        await client.send('Profiler.startPreciseCoverage', {
          callCount: true,
          detailed: true,
        });
        coverageStarted = true;
      } catch (err) {
        cdpEvents({
          ts: new Date().toISOString(),
          source: 'cdp',
          method: 'Profiler.startPreciseCoverage.error',
          params: { message: redactValue(err && err.message ? err.message : String(err)) },
        });
      }
    }

    page.on('request', (request) => {
      requests({
        ts: new Date().toISOString(),
        source: 'playwright',
        event: 'request',
        url: safeUrl(request.url()),
        method: request.method(),
        resourceType: request.resourceType(),
        headers: redactValue(request.headers()),
        postDataLength: request.postData() ? request.postData().length : 0,
      });
    });
    page.on('response', (response) => {
      responses({
        ts: new Date().toISOString(),
        source: 'playwright',
        event: 'response',
        url: safeUrl(response.url()),
        status: response.status(),
        statusText: response.statusText(),
        headers: redactValue(response.headers()),
      });
    });
    page.on('console', (msg) => {
      consoleEvents({
        ts: new Date().toISOString(),
        source: 'playwright',
        event: 'console',
        type: msg.type(),
        text: redactValue(msg.text()),
      });
    });
    page.on('pageerror', (err) => {
      exceptions({ ts: new Date().toISOString(), source: 'playwright', event: 'pageerror', message: redactValue(err.message) });
    });

    await page.goto(args.url, { waitUntil: args.waitUntil || 'load', timeout });
    if (args.clickSelector) {
      await page.click(args.clickSelector, { timeout });
    }
    if (args.waitForSelector) {
      await page.waitForSelector(args.waitForSelector, { timeout });
    }
    if (args.waitForUrl) {
      await page.waitForURL(args.waitForUrl, { timeout });
    }
    if (waitMs > 0) {
      await page.waitForTimeout(waitMs);
    }

    if (args.jsCoverage) {
      try {
        const coverage = coverageStarted
          ? await client.send('Profiler.takePreciseCoverage')
          : { result: [], error: 'coverage did not start' };
        if (coverageStarted) {
          try {
            await client.send('Profiler.stopPreciseCoverage');
          } catch {
            // Ignore stop errors after data collection.
          }
        }
        writeJson(jsCoveragePath, {
          schema: 'baza-js-coverage-v1',
          collected_at: new Date().toISOString(),
          source: 'cdp.Profiler.takePreciseCoverage',
          result: redactValue(coverage.result || []),
          error: coverage.error || '',
        });
      } catch (err) {
        writeJson(jsCoveragePath, {
          schema: 'baza-js-coverage-v1',
          collected_at: new Date().toISOString(),
          source: 'cdp.Profiler.takePreciseCoverage',
          result: [],
          error: redactValue(err && err.message ? err.message : String(err)),
        });
      }
    }

    if (args.jsRuntimeObserver) {
      let jsRuntimeEvents = [];
      try {
        jsRuntimeEvents = await page.evaluate(() => (
          Array.isArray(window.__BAZA_JS_EVENTS__) ? window.__BAZA_JS_EVENTS__ : []
        ));
      } catch (err) {
        jsRuntimeEvents = [{
          ts: new Date().toISOString(),
          type: 'observer.export_error',
          data: { message: redactValue(err && err.message ? err.message : String(err)) },
        }];
      }
      writeJson(jsRuntimeEventsPath, redactValue(jsRuntimeEvents));
    }

    await context.tracing.stop({ path: tracePath });
    await context.close();
    await browser.close();

    manifest.status = 'completed';
    manifest.completed_at = new Date().toISOString();
    manifest.artifacts = {
      manifest: 'manifest.json',
      trace: 'playwright-trace.zip',
      har: 'network.har',
      cdp_events: 'cdp-events.ndjson',
      requests: 'requests.ndjson',
      responses: 'responses.ndjson',
      console: 'console.ndjson',
      runtime_exceptions: 'runtime-exceptions.ndjson',
      scripts: 'scripts.ndjson',
      workers: 'workers.ndjson',
    };
    if (args.jsRuntimeObserver) {
      manifest.artifacts.js_runtime_events = 'js-runtime-events.json';
    }
    if (args.jsCoverage) {
      manifest.artifacts.js_coverage = 'js-coverage.json';
    }
    writeJson(manifestPath, manifest);
    console.log(JSON.stringify({ ok: true, out_dir: outDir, manifest: manifestPath }, null, 2));
    return 0;
  } catch (err) {
    if (browser) {
      try {
        await browser.close();
      } catch {
        // Ignore cleanup failures after primary capture error.
      }
    }
    manifest.status = 'failed';
    manifest.error = redactValue(err && err.message ? err.message : String(err));
    writeJson(manifestPath, manifest);
    console.error(`FAIL ${manifest.error}`);
    return 4;
  }
}

main().then((code) => process.exit(code)).catch((err) => {
  console.error(err && err.stack ? err.stack : String(err));
  process.exit(1);
});
