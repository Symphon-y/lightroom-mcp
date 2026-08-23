import net from "node:net";
import { EventEmitter } from "node:events";
import { HOST, REQUEST_PORT, RESPONSE_PORT } from "./ports.js";

export interface JsonMessage {
  [key: string]: unknown;
}

/**
 * Two localhost-only TCP client connections to the Lightroom plugin's
 * LrSocket servers: one to send requests, one to receive responses. Only
 * ever connects to 127.0.0.1 — this is the local-only guarantee the whole
 * design rests on, so don't parameterize the host beyond that.
 */
export class PluginSocket extends EventEmitter {
  private requestSocket: net.Socket | null = null;
  private responseSocket: net.Socket | null = null;
  private responseBuffer = "";
  private connected = false;

  connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      let pending = 2;
      let settled = false;
      const succeed = () => {
        pending -= 1;
        if (pending === 0 && !settled) {
          settled = true;
          this.connected = true;
          resolve();
        }
      };
      const fail = (err: Error) => {
        if (!settled) {
          settled = true;
          reject(err);
        }
      };

      this.requestSocket = net.createConnection({ host: HOST, port: REQUEST_PORT }, succeed);
      this.requestSocket.on("error", fail);
      this.requestSocket.on("close", () => this.handleDisconnect());

      this.responseSocket = net.createConnection({ host: HOST, port: RESPONSE_PORT }, succeed);
      this.responseSocket.on("error", fail);
      this.responseSocket.on("close", () => this.handleDisconnect());
      this.responseSocket.on("data", (chunk) => this.handleResponseData(chunk));
    });
  }

  private handleDisconnect() {
    if (this.connected) {
      this.connected = false;
      this.emit("disconnected");
    }
  }

  private handleResponseData(chunk: Buffer) {
    this.responseBuffer += chunk.toString("utf8");
    let newlineIndex: number;
    while ((newlineIndex = this.responseBuffer.indexOf("\n")) !== -1) {
      const line = this.responseBuffer.slice(0, newlineIndex);
      this.responseBuffer = this.responseBuffer.slice(newlineIndex + 1);
      if (line.length === 0) continue;
      try {
        this.emit("message", JSON.parse(line) as JsonMessage);
      } catch {
        this.emit("error", new Error(`Failed to parse response line: ${line}`));
      }
    }
  }

  send(message: JsonMessage): void {
    if (!this.requestSocket) {
      throw new Error("PluginSocket: not connected");
    }
    this.requestSocket.write(JSON.stringify(message) + "\n");
  }

  close(): void {
    this.requestSocket?.destroy();
    this.responseSocket?.destroy();
    this.connected = false;
  }
}
