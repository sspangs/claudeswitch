import { db } from "./db";
import type { ProjectContext } from "./anthropic";

export async function loadProjectContext(
  projectId: string
): Promise<ProjectContext> {
  const project = await db.project.findUnique({
    where: { id: projectId },
    include: { loreEntries: true },
  });
  if (!project) throw new Error("Project not found");
  return {
    title: project.title,
    synopsis: project.synopsis,
    styleNote: project.styleNote,
    lore: project.loreEntries.map((l) => ({
      name: l.name,
      kind: l.kind,
      description: l.description,
    })),
  };
}
