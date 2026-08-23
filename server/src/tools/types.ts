import type { z } from "zod";

export interface ToolDefinition<Shape extends z.ZodRawShape> {
  name: string;
  description: string;
  inputShape: Shape;
  action: string;
}

export function defineTool<Shape extends z.ZodRawShape>(def: ToolDefinition<Shape>): ToolDefinition<Shape> {
  return def;
}
