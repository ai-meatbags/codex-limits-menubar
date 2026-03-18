#!/usr/bin/env node

import { JsonlAppServerClient } from '../app-server/jsonlAppServerClient.mjs';
import { createErrorSnapshot, createMenubarSnapshot } from '../rate-limits/menubarSnapshot.mjs';
import { appendFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

const CODEX_BINARY = process.env.CODEX_LIMITS_CODEX_BIN ?? 'codex';
const REQUEST_TIMEOUT_MS = Number(process.env.CODEX_LIMITS_TIMEOUT_MS ?? '15000');
const LOG_FILE = process.env.CODEX_LIMITS_LOG_FILE ?? '';

async function main() {
  log(`snapshot start codex=${CODEX_BINARY}`);
  const client = new JsonlAppServerClient({
    command: CODEX_BINARY,
    args: ['app-server'],
    onLog: (message) => log(`[app-server] ${message}`)
  });

  try {
    await client.start();
    log('app-server process spawned');
    await withTimeout(
      client.request('initialize', {
        clientInfo: {
          name: 'codex-limits-menubar',
          version: '0.1.0'
        }
      }),
      'initialize'
    );

    client.notify('initialized', {});
    log('app-server initialized');

    const [accountPayload, rateLimitsPayload] = await Promise.all([
      withTimeout(client.request('account/read', {}), 'account/read').catch(() => ({})),
      withTimeout(client.request('account/rateLimits/read', {}), 'account/rateLimits/read')
    ]);

    log('rate limits fetched');
    console.log(
      JSON.stringify(
        createMenubarSnapshot({
          accountPayload,
          rateLimitsPayload
        }),
        null,
        2
      )
    );
  } catch (error) {
    log(`snapshot error: ${error.message}`);
    console.log(JSON.stringify(createErrorSnapshot(error.message), null, 2));
    process.exitCode = 1;
  } finally {
    await client.close();
    log('snapshot end');
  }
}

function withTimeout(promise, label) {
  return Promise.race([
    promise,
    new Promise((_, reject) => {
      setTimeout(() => {
        reject(new Error(`${label} timed out after ${REQUEST_TIMEOUT_MS}ms`));
      }, REQUEST_TIMEOUT_MS);
    })
  ]);
}

function log(message) {
  if (!LOG_FILE) {
    return;
  }

  try {
    mkdirSync(dirname(LOG_FILE), { recursive: true });
    appendFileSync(LOG_FILE, `[${new Date().toISOString()}] [node] ${message}\n`);
  } catch {}
}

main();
