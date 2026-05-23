import { loadProjectContext } from "@/lib/context";
import { streamAnthropic } from "@/lib/stream";

export const runtime = "nodejs";

export async function POST(req: Request) {
  const { projectId, selection } = (await req.json()) as {
    projectId: string;
    selection: string;
  };

  const ctx = await loadProjectContext(projectId);
  const stream = await streamAnthropic({
    ctx,
    messages: [
      {
        role: "user",
        content: [
          "Critique the passage below. Be specific and useful — call out exact words or sentences.",
          "Cover: clarity, pacing, voice, and any worldbuilding inconsistencies with the lore.",
          "Keep it under 200 words. Skip generic praise.",
          "",
          "--- passage ---",
          selection,
        ].join("\n"),
      },
    ],
    placeholderLabel: "critique",
    maxTokens: 500,
  });

  return new Response(stream, {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
}
