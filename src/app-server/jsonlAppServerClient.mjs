import { spawn } from 'node:child_process';

export class JsonlAppServerClient {
  #buffer = '';
  #child = null;
  #nextId = 1;
  #pending = new Map();
  #stderr = [];
  #onLog = null;

  constructor({ command, args = [], env = process.env, onLog = null }) {
    this.command = command;
    this.args = args;
    this.env = env;
    this.#onLog = onLog;
  }

  async start() {
    if (this.#child) {
      return;
    }

    this.#child = spawn(this.command, this.args, {
      env: this.env,
      stdio: ['pipe', 'pipe', 'pipe']
    });

    this.#child.stdout.on('data', (chunk) => this.#handleData(chunk));
    this.#child.stderr.on('data', (chunk) => {
      const text = String(chunk);
      this.#stderr.push(text);
      this.#log(`stderr ${text.trim()}`);
    });
    this.#child.on('spawn', () => {
      this.#log(`spawned pid=${this.#child?.pid ?? 'unknown'}`);
    });
    this.#child.on('error', (error) => {
      this.#failPending(`Failed to start app-server: ${error.message}`);
    });
    this.#child.on('exit', (code, signal) => {
      const reason = signal
        ? `app-server exited via ${signal}`
        : `app-server exited with code ${code ?? 'unknown'}`;
      this.#log(reason);
      this.#failPending(this.#buildErrorMessage(reason));
      this.#child = null;
    });
  }

  request(method, params = {}) {
    const id = this.#nextId++;

    return new Promise((resolve, reject) => {
      this.#pending.set(id, { resolve, reject, method });
      this.#writeMessage({
        id,
        method,
        params
      });
    });
  }

  notify(method, params = {}) {
    this.#writeMessage({
      method,
      params
    });
  }

  async close() {
    if (!this.#child) {
      return;
    }

    this.#child.kill('SIGTERM');
    this.#child = null;
  }

  #writeMessage(message) {
    if (!this.#child) {
      throw new Error('app-server is not started');
    }

    const serialized = `${JSON.stringify(message)}\n`;
    this.#child.stdin.write(serialized);
    this.#log(`sent ${serialized.trim()}`);
  }

  #handleData(chunk) {
    this.#buffer += chunk.toString('utf8');

    while (true) {
      const newlineIndex = this.#buffer.indexOf('\n');
      if (newlineIndex === -1) {
        return;
      }

      const line = this.#buffer.slice(0, newlineIndex).trim();
      this.#buffer = this.#buffer.slice(newlineIndex + 1);

      if (!line) {
        continue;
      }

      this.#log(`recv ${line}`);

      let message;
      try {
        message = JSON.parse(line);
      } catch (error) {
        this.#failPending(this.#buildErrorMessage(`Invalid JSON from app-server: ${error.message}`));
        return;
      }

      this.#dispatchMessage(message);
    }
  }

  #dispatchMessage(message) {
    if (message.id === undefined) {
      return;
    }

    const pendingRequest = this.#pending.get(message.id);
    if (!pendingRequest) {
      return;
    }

    this.#pending.delete(message.id);

    if (message.error) {
      const errorMessage = message.error.message || JSON.stringify(message.error);
      pendingRequest.reject(new Error(this.#buildErrorMessage(errorMessage)));
      return;
    }

    pendingRequest.resolve(message.result);
  }

  #failPending(message) {
    for (const pendingRequest of this.#pending.values()) {
      pendingRequest.reject(new Error(message));
    }

    this.#pending.clear();
  }

  #buildErrorMessage(message) {
    const stderrOutput = this.#stderr.join('').trim();
    if (!stderrOutput) {
      return message;
    }

    return `${message}\n${stderrOutput}`;
  }

  #log(message) {
    this.#onLog?.(message);
  }
}
