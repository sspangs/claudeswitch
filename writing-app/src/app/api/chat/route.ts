import { loadProjectContext } from "@/lib/context";
import { streamAnthropic } from "@/lib/stream";

export const runtime = "nodejs";

export async function POST(req: Request) {
  const { projectId, messages } = (await req.json()) as {
    projectId: string;
    messages: { role: "user" | "assistant"; content: string }[];
  };

  const ctx = await loadProjectContext(projectId);
  const stream = await streamAnthropic({
    ctx,
    messages,
    placeholderLabel: "chat",
    maxTokens: 1024,
  });

  return new Response(stream, {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
}
