import { loadProjectContext } from "@/lib/context";
import { streamAnthropic } from "@/lib/stream";

export const runtime = "nodejs";

export async function POST(req: Request) {
  const { projectId, before } = (await req.json()) as {
    projectId: string;
    before: string;
  };

  const ctx = await loadProjectContext(projectId);
  const tail = before.slice(-2000);

  const stream = await streamAnthropic({
    ctx,
    messages: [
      {
        role: "user",
        content: [
          "Continue the prose below in the same voice and tense.",
          "Write 2–4 paragraphs. Output only the continuation — no preamble, no quotes.",
          "",
          "--- text so far ---",
          tail,
        ].join("\n"),
      },
    ],
    placeholderLabel: "continue",
    maxTokens: 600,
  });

  return new Response(stream, {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
}
