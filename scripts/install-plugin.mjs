#!/usr/bin/env node
// Best-effort copy of the plugin bundle into Lightroom's default plugin
// search location. The reliable, documented path is still to open
// Lightroom Classic > File > Plug-in Manager > Add and point it at
// plugin/LightroomMCP.lrplugin directly -- this script is a convenience,
// not a replacement for that.
import { cpSync, existsSync, mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const source = join(__dirname, "..", "plugin", "LightroomMCP.lrplugin");

let defaultDest;
if (process.platform === "win32") {
  defaultDest = join(process.env.APPDATA ?? join(homedir(), "AppData", "Roaming"), "Adobe", "Lightroom", "Modules");
} else if (process.platform === "darwin") {
  defaultDest = join(homedir(), "Library", "Application Support", "Adobe", "Lightroom", "Modules");
} else {
  console.log(`Unsupported platform for auto-install (${process.platform}).`);
  console.log(`Manually add this plugin via Lightroom's Plug-in Manager: ${source}`);
  process.exit(0);
}

if (!existsSync(defaultDest)) {
  mkdirSync(defaultDest, { recursive: true });
}

const dest = join(defaultDest, "LightroomMCP.lrplugin");
cpSync(source, dest, { recursive: true });

console.log(`Copied plugin to: ${dest}`);
console.log(`Open Lightroom Classic > File > Plug-in Manager, click "Add" if it isn't already listed, then "Start Server".`);
