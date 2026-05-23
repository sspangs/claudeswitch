import { fal } from "@fal-ai/client";
import { writeFile, mkdir } from "node:fs/promises";
import path from "node:path";

export function hasFalKey() {
  return Boolean(process.env.FAL_KEY);
}

let configured = false;
function ensureConfigured() {
  if (configured || !hasFalKey()) return;
  fal.config({ credentials: process.env.FAL_KEY });
  configured = true;
}

const UPLOAD_DIR = path.join(process.cwd(), "public", "uploads");

async function saveImage(buf: ArrayBuffer, ext = "webp") {
  await mkdir(UPLOAD_DIR, { recursive: true });
  const name = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}`;
  const filePath = path.join(UPLOAD_DIR, name);
  await writeFile(filePath, Buffer.from(buf));
  return `/uploads/${name}`;
}

export async function generateImage(prompt: string): Promise<{
  path: string;
  prompt: string;
  placeholder: boolean;
}> {
  if (!hasFalKey()) {
    return {
      path: placeholderImage(prompt),
      prompt,
      placeholder: true,
    };
  }

  ensureConfigured();
  const result = await fal.subscribe("fal-ai/flux/schnell", {
    input: {
      prompt,
      image_size: "square_hd",
      num_inference_steps: 4,
      num_images: 1,
      enable_safety_checker: true,
    },
  });

  const url = (result.data as { images?: { url: string }[] }).images?.[0]?.url;
  if (!url) throw new Error("fal.ai returned no image");

  const res = await fetch(url);
  const buf = await res.arrayBuffer();
  const stored = await saveImage(buf);
  return { path: stored, prompt, placeholder: false };
}

// Deterministic SVG placeholder so the UI looks complete without a key.
function placeholderImage(prompt: string): string {
  const seed = [...prompt].reduce((a, c) => (a * 31 + c.charCodeAt(0)) >>> 0, 7);
  const hue = seed % 360;
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
    <defs>
      <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0%" stop-color="hsl(${hue} 35% 25%)"/>
        <stop offset="100%" stop-color="hsl(${(hue + 40) % 360} 30% 12%)"/>
      </linearGradient>
    </defs>
    <rect width="512" height="512" fill="url(#g)"/>
    <text x="50%" y="50%" font-family="-apple-system,system-ui,sans-serif" font-size="22" fill="rgba(255,255,255,0.55)" text-anchor="middle">placeholder</text>
  </svg>`;
  return `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`;
}

export async function loreToImagePrompt(opts: {
  name: string;
  kind: string;
  description: string;
  styleNote: string;
}): Promise<string> {
  const { name, kind, description, styleNote } = opts;
  const subject =
    kind === "character"
      ? `portrait of ${name}`
      : kind === "location"
        ? `landscape view of ${name}`
        : `concept art of ${name}`;
  const style = styleNote.trim() || "painterly, muted palette, cinematic lighting";
  return [
    subject,
    description.trim(),
    style,
    "highly detailed, atmospheric",
  ]
    .filter(Boolean)
    .join(", ");
}
