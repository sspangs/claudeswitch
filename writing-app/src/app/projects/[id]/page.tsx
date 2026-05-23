import { notFound } from "next/navigation";
import Link from "next/link";
import { db } from "@/lib/db";
import { ProjectShell } from "@/components/project-shell";

export default async function ProjectPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ chapter?: string }>;
}) {
  const { id } = await params;
  const { chapter: chapterParam } = await searchParams;

  const project = await db.project.findUnique({
    where: { id },
    include: {
      chapters: { orderBy: { order: "asc" } },
      loreEntries: { orderBy: { name: "asc" } },
    },
  });

  if (!project) notFound();

  const activeChapter =
    project.chapters.find((c) => c.id === chapterParam) ?? project.chapters[0];

  return (
    <div className="flex flex-col flex-1 min-h-screen">
      <header className="vibrancy sticky top-0 z-20 border-b border-border">
        <div className="flex items-center justify-between px-5 h-12">
          <div className="flex items-center gap-3 text-sm">
            <Link
              href="/"
              className="text-fg-muted hover:text-fg transition-colors"
            >
              ← Projects
            </Link>
            <span className="text-fg-subtle">/</span>
            <span className="font-medium">{project.title}</span>
          </div>
          <div className="text-xs text-fg-subtle">
            {activeChapter ? `Editing: ${activeChapter.title}` : ""}
          </div>
        </div>
      </header>

      <ProjectShell
        project={{
          id: project.id,
          title: project.title,
          synopsis: project.synopsis,
          styleNote: project.styleNote,
        }}
        chapters={project.chapters.map((c) => ({
          id: c.id,
          title: c.title,
          order: c.order,
        }))}
        loreEntries={project.loreEntries.map((l) => ({
          id: l.id,
          name: l.name,
          kind: l.kind,
          description: l.description,
          imagePath: l.imagePath,
        }))}
        activeChapter={
          activeChapter
            ? {
                id: activeChapter.id,
                title: activeChapter.title,
                content: activeChapter.content,
              }
            : null
        }
      />
    </div>
  );
}
