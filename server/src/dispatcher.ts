import { PluginSocket, type JsonMessage } from "./plugin-socket.js";
import { getToken } from "./token.js";

interface PendingCall {
  resolve: (value: unknown) => void;
  reject: (err: Error) => void;
  timer: NodeJS.Timeout;
}

const DEFAULT_TIMEOUT_MS = 30_000;
const SLOW_ACTION_TIMEOUT_MS: Record<string, number> = {
  search_photos: 60_000,
};

export class Dispatcher {
  private socket = new PluginSocket();
  private pending = new Map<string, PendingCall>();
  private counter = 0;

  async connect(): Promise<void> {
    this.socket.on("message", (message: JsonMessage) => this.handleResponse(message));
    this.socket.on("error", (err: Error) => {
      // Individual calls are protected by their own timeout; this is just
      // for diagnosing connection-level problems.
      console.error("[lightroom-mcp] plugin socket error:", err.message);
    });
    // The plugin rebinds/restarts its sockets periodically by design, so a
    // working connection can drop mid-session (PluginSocket reconnects
    // automatically). Fail in-flight calls immediately when that happens
    // instead of leaving them to hang until their own timeout -- the
    // caller can just retry once PluginSocket reconnects.
    this.socket.on("disconnected", () => this.rejectAllPending("Lost connection to the Lightroom plugin (it will reconnect automatically -- try again)"));
    await this.socket.connect();
  }

  async call(action: string, params: Record<string, unknown> = {}): Promise<unknown> {
    const id = `req_${Date.now()}_${this.counter++}`;
    const timeoutMs = SLOW_ACTION_TIMEOUT_MS[action] ?? DEFAULT_TIMEOUT_MS;

    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`Timed out waiting for Lightroom response to "${action}" after ${timeoutMs}ms`));
      }, timeoutMs);

      this.pending.set(id, { resolve, reject, timer });

      try {
        this.socket.send({ hello: getToken(), id, action, params });
      } catch (err) {
        clearTimeout(timer);
        this.pending.delete(id);
        reject(err as Error);
      }
    });
  }

  private handleResponse(message: JsonMessage) {
    const id = message.id as string | undefined;
    if (!id) return;
    const pending = this.pending.get(id);
    if (!pending) return;
    this.pending.delete(id);
    clearTimeout(pending.timer);

    if (message.ok) {
      pending.resolve(message.result);
    } else {
      pending.reject(new Error(String(message.error ?? "Unknown error from Lightroom plugin")));
    }
  }

  private rejectAllPending(reason: string) {
    for (const pending of this.pending.values()) {
      clearTimeout(pending.timer);
      pending.reject(new Error(reason));
    }
    this.pending.clear();
  }

  close(): void {
    this.socket.close();
  }
}
