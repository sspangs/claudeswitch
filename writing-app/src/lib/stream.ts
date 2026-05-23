import {
  anthropic,
  buildSystemPrompt,
  MODEL,
  placeholderStream,
  type ProjectContext,
} from "./anthropic";

type Message = { role: "user" | "assistant"; content: string };

export async function streamAnthropic(opts: {
  ctx: ProjectContext;
  messages: Message[];
  placeholderLabel: string;
  maxTokens?: number;
}): Promise<ReadableStream<Uint8Array>> {
  const client = anthropic();
  if (!client) return placeholderStream(opts.placeholderLabel);

  const system = buildSystemPrompt(opts.ctx);
  const stream = await client.messages.stream({
    model: MODEL,
    max_tokens: opts.maxTokens ?? 1024,
    system: [
      {
        type: "text",
        text: system,
        cache_control: { type: "ephemeral" },
      },
    ],
    messages: opts.messages.map((m) => ({ role: m.role, content: m.content })),
  });

  const encoder = new TextEncoder();
  return new ReadableStream<Uint8Array>({
    async start(controller) {
      try {
        for await (const event of stream) {
          if (
            event.type === "content_block_delta" &&
            event.delta.type === "text_delta"
          ) {
            controller.enqueue(encoder.encode(event.delta.text));
          }
        }
        controller.close();
      } catch (err) {
        controller.error(err);
      }
    },
  });
}
