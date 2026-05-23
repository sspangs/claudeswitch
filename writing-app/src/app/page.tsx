import Link from "next/link";
import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { db } from "@/lib/db";

async function createProject(formData: FormData) {
  "use server";
  const title = String(formData.get("title") || "").trim() || "Untitled";
  const project = await db.project.create({
    data: {
      title,
      chapters: { create: { title: "Chapter 1", order: 0 } },
    },
  });
  revalidatePath("/");
  redirect(`/projects/${project.id}`);
}

export default async function Home() {
  const projects = await db.project.findMany({
    orderBy: { updatedAt: "desc" },
    include: { _count: { select: { chapters: true, loreEntries: true } } },
  });

  return (
    <div className="mx-auto w-full max-w-3xl px-8 pt-24 pb-32">
      <header className="mb-12">
        <h1 className="text-4xl font-semibold tracking-tight">Scriptorium</h1>
        <p className="mt-2 text-fg-muted">
          A quiet place to draft long-form fiction with a collaborator.
        </p>
      </header>

      <section className="mb-10">
        <form action={createProject} className="flex gap-2">
          <input
            name="title"
            placeholder="New project title"
            autoComplete="off"
            className="flex-1 rounded-md bg-bg-elev border border-border px-4 py-3 text-fg placeholder:text-fg-subtle focus:outline-none focus:border-border-strong transition-colors"
          />
          <button
            type="submit"
            className="rounded-md bg-accent px-5 py-3 font-medium text-accent-fg hover:opacity-90 transition-opacity"
          >
            Create
          </button>
        </form>
      </section>

      <section>
        <h2 className="text-sm font-medium text-fg-muted mb-3 uppercase tracking-wider">
          Projects
        </h2>
        {projects.length === 0 ? (
          <p className="text-fg-subtle text-sm py-8">
            No projects yet. Start one above.
          </p>
        ) : (
          <ul className="divide-y divide-border rounded-lg border border-border overflow-hidden bg-bg-elev">
            {projects.map((p) => (
              <li key={p.id}>
                <Link
                  href={`/projects/${p.id}`}
                  className="flex items-baseline justify-between px-5 py-4 hover:bg-[var(--surface-hover)] transition-colors"
                >
                  <div>
                    <div className="font-medium">{p.title}</div>
                    <div className="mt-0.5 text-xs text-fg-subtle">
                      {p._count.chapters} chapter
                      {p._count.chapters === 1 ? "" : "s"} ·{" "}
                      {p._count.loreEntries} lore entr
                      {p._count.loreEntries === 1 ? "y" : "ies"}
                    </div>
                  </div>
                  <div className="text-xs text-fg-subtle">
                    {new Date(p.updatedAt).toLocaleDateString()}
                  </div>
                </Link>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
