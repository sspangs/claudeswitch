import Anthropic from "@anthropic-ai/sdk";

export const MODEL = "claude-sonnet-4-6";

export function hasAnthropicKey() {
  return Boolean(process.env.ANTHROPIC_API_KEY);
}

let client: Anthropic | null = null;

export function anthropic() {
  if (!hasAnthropicKey()) return null;
  if (!client) client = new Anthropic();
  return client;
}

export type ProjectContext = {
  title: string;
  synopsis: string;
  styleNote: string;
  lore: { name: string; kind: string; description: string }[];
};

export function buildSystemPrompt(ctx: ProjectContext) {
  const loreBlock = ctx.lore.length
    ? ctx.lore
        .map(
          (l) =>
            `- [${l.kind}] ${l.name}: ${l.description.trim() || "(no description)"}`
        )
        .join("\n")
    : "(no lore entries yet)";

  return [
    "You are a thoughtful creative writing collaborator for a long-form fiction project.",
    "You help the author draft prose, brainstorm, edit, and keep worldbuilding consistent.",
    "Stay in the author's voice. Be specific and concrete. Avoid generic fantasy filler.",
    "",
    `# Project: ${ctx.title}`,
    "",
    "## Synopsis",
    ctx.synopsis.trim() || "(none yet)",
    "",
    "## Author's style notes",
    ctx.styleNote.trim() || "(none yet)",
    "",
    "## Lore",
    loreBlock,
  ].join("\n");
}

// Placeholder responses when no key is configured. Keeps the UI usable.
export function placeholderStream(label: string): ReadableStream<Uint8Array> {
  const text = `[${label} placeholder — add ANTHROPIC_API_KEY to .env.local for real output.]`;
  const encoder = new TextEncoder();
  return new ReadableStream({
    async start(controller) {
      for (const chunk of text.match(/.{1,4}/g) ?? []) {
        controller.enqueue(encoder.encode(chunk));
        await new Promise((r) => setTimeout(r, 25));
      }
      controller.close();
    },
  });
}
