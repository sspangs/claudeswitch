import { db } from "@/lib/db";
import { generateImage, loreToImagePrompt } from "@/lib/fal";
import { anthropic, MODEL, hasAnthropicKey } from "@/lib/anthropic";

export const runtime = "nodejs";
export const maxDuration = 120;

export async function POST(
  _req: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;

  const entry = await db.loreEntry.findUnique({
    where: { id },
    include: { project: true },
  });
  if (!entry) return new Response("Not found", { status: 404 });

  let prompt = await loreToImagePrompt({
    name: entry.name,
    kind: entry.kind,
    description: entry.description,
    styleNote: entry.project.styleNote,
  });

  // If Anthropic is available, let Claude refine the image prompt.
  const client = anthropic();
  if (client && hasAnthropicKey()) {
    try {
      const res = await client.messages.create({
        model: MODEL,
        max_tokens: 200,
        system:
          "You write tight, vivid image-generation prompts. Reply with the prompt only — no preamble, no quotes, one paragraph.",
        messages: [
          {
            role: "user",
            content: `Turn this lore entry into an image prompt.\n\nKind: ${entry.kind}\nName: ${entry.name}\nDescription: ${entry.description}\nProject style: ${entry.project.styleNote || "(none)"}\n\nDraft prompt: ${prompt}`,
          },
        ],
      });
      const text = res.content
        .map((c) => (c.type === "text" ? c.text : ""))
        .join("")
        .trim();
      if (text) prompt = text;
    } catch {
      // fall back to the heuristic prompt
    }
  }

  const { path, placeholder } = await generateImage(prompt);

  await db.loreEntry.update({
    where: { id },
    data: { imagePath: path, imagePrompt: prompt },
  });

  return Response.json({ imagePath: path, prompt, placeholder });
}
