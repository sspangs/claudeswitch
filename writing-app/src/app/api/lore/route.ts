import { db } from "@/lib/db";

export async function POST(req: Request) {
  const { projectId, name, kind, description } = (await req.json()) as {
    projectId: string;
    name: string;
    kind?: string;
    description?: string;
  };

  const entry = await db.loreEntry.create({
    data: {
      projectId,
      name,
      kind: kind || "character",
      description: description || "",
    },
  });
  return Response.json({ id: entry.id });
}
