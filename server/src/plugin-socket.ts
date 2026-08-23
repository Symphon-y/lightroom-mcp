import net from "node:net";
import { EventEmitter } from "node:events";
import { HOST, REQUEST_PORT, RESPONSE_PORT } from "./ports.js";

export interface JsonMessage {
  [key: string]: unknown;
}

const RECONNECT_BASE_DELAY_MS = 1000;
const RECONNECT_MAX_DELAY_MS = 10_000;

/**
 * A single reconnecting TCP client connection. Manages its own connection
 * state independently -- it does not know or care about any other socket.
 *
 * This independence matters: an earlier version coupled the request and
 * response sockets together (tearing down both whenever either one's
 * connection attempt failed). That raced against the Lightroom plugin's
 * own behavior of rebinding its response socket every time a fresh
 * request connection arrives, and the two sides ended up fighting each
 * other into a self-sustaining connect/disconnect loop that never
 * settled. Automaat/lightroom-mcp's real client keeps these fully
 * independent for the same reason -- confirmed by reading their actual
 * socket-handling source after hitting this live.
 */
class ManagedSocket extends EventEmitter {
  private socket: net.Socket | null = null;
  private connected = false;
  private explicitlyClosed = false;
  private reconnectAttempt = 0;
  private reconnectTimer: NodeJS.Timeout | null = null;

  constructor(
    private readonly label: string,
    private readonly port: number
  ) {
    super();
  }

  connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      let settled = false;
      this.open(
        () => {
          if (!settled) {
            settled = true;
            resolve();
          }
        },
        (err) => {
          if (!settled) {
            settled = true;
            reject(err);
          }
        }
      );
    });
  }

  private open(onFirstConnect?: () => void, onFirstError?: (err: Error) => void): void {
    const sock = net.createConnection({ host: HOST, port: this.port }, () => {
      this.connected = true;
      this.reconnectAttempt = 0;
      this.emit("connected");
      onFirstConnect?.();
    });
    this.socket = sock;
    sock.on("error", (err) => onFirstError?.(err as Error));
    sock.on("close", () => this.handleClosed());
    sock.on("data", (chunk: Buffer) => this.emit("data", chunk));
  }

  private handleClosed(): void {
    const wasConnected = this.connected;
    this.connected = false;
    this.socket = null;
    if (wasConnected) {
      this.emit("disconnected");
    }
    this.scheduleReconnect();
  }

  private scheduleReconnect(): void {
    if (this.explicitlyClosed || this.reconnectTimer) return;
    const delay = Math.min(RECONNECT_BASE_DELAY_MS * 2 ** this.reconnectAttempt, RECONNECT_MAX_DELAY_MS);
    this.reconnectAttempt += 1;
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      if (this.explicitlyClosed) return;
      this.open();
    }, delay);
  }

  get isConnected(): boolean {
    return this.connected;
  }

  write(data: string): void {
    if (!this.connected || !this.socket) {
      throw new Error(`${this.label} socket: not currently connected to the Lightroom plugin`);
    }
    this.socket.write(data);
  }

  close(): void {
    this.explicitlyClosed = true;
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    this.socket?.destroy();
    this.connected = false;
  }
}

/**
 * Two independent localhost-only TCP client connections to the Lightroom
 * plugin's LrSocket servers: one to send requests, one to receive
 * responses. Only ever connects to 127.0.0.1 -- this is the local-only
 * guarantee the whole design rests on, so don't parameterize the host
 * beyond that.
 */
export class PluginSocket extends EventEmitter {
  private readonly requestSocket = new ManagedSocket("request", REQUEST_PORT);
  private readonly responseSocket = new ManagedSocket("response", RESPONSE_PORT);
  private responseBuffer = "";

  constructor() {
    super();
    this.responseSocket.on("connected", () => {
      this.responseBuffer = "";
    });
    this.responseSocket.on("data", (chunk: Buffer) => this.handleResponseData(chunk));

    // A request in flight needs both sides working (write the request,
    // read the response), so either socket dropping means in-flight calls
    // should be treated as lost. Dispatcher listens for this to fail them
    // fast instead of waiting out their timeout.
    this.requestSocket.on("disconnected", () => this.emit("disconnected"));
    this.responseSocket.on("disconnected", () => this.emit("disconnected"));
  }

  async connect(): Promise<void> {
    await Promise.all([this.requestSocket.connect(), this.responseSocket.connect()]);
  }

  private handleResponseData(chunk: Buffer): void {
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

  get isConnected(): boolean {
    return this.requestSocket.isConnected && this.responseSocket.isConnected;
  }

  send(message: JsonMessage): void {
    this.requestSocket.write(JSON.stringify(message) + "\n");
  }

  close(): void {
    this.requestSocket.close();
    this.responseSocket.close();
  }
}
