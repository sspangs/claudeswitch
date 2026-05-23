"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Plus, FileText, BookOpen } from "lucide-react";
import { cn } from "@/lib/utils";
import type { ChapterMeta, LoreMeta } from "./project-shell";

export function Sidebar({
  projectId,
  chapters,
  loreEntries,
  activeChapterId,
  onEditLore,
  onNewLore,
}: {
  projectId: string;
  chapters: ChapterMeta[];
  loreEntries: LoreMeta[];
  activeChapterId: string | null;
  onEditLore: (id: string) => void;
  onNewLore: () => void;
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  async function addChapter() {
    setBusy(true);
    try {
      const res = await fetch("/api/chapters", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          projectId,
          title: `Chapter ${chapters.length + 1}`,
        }),
      });
      const { id } = await res.json();
      router.push(`/projects/${projectId}?chapter=${id}`);
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  return (
    <nav className="w-64 shrink-0 border-r border-border vibrancy flex flex-col">
      <Section
        title="Chapters"
        action={
          <button
            onClick={addChapter}
            disabled={busy}
            className="text-fg-subtle hover:text-fg p-1 rounded-md hover:bg-[var(--surface)]"
            aria-label="Add chapter"
          >
            <Plus size={14} />
          </button>
        }
      >
        {chapters.length === 0 ? (
          <Empty label="No chapters" />
        ) : (
          <ul className="space-y-0.5">
            {chapters.map((c) => (
              <li key={c.id}>
                <Link
                  href={`/projects/${projectId}?chapter=${c.id}`}
                  className={cn(
                    "flex items-center gap-2 px-2.5 py-1.5 rounded-md text-sm transition-colors",
                    c.id === activeChapterId
                      ? "bg-[var(--surface-hover)] text-fg"
                      : "text-fg-muted hover:text-fg hover:bg-[var(--surface)]"
                  )}
                >
                  <FileText size={14} className="shrink-0 opacity-70" />
                  <span className="truncate">{c.title}</span>
                </Link>
              </li>
            ))}
          </ul>
        )}
      </Section>

      <Section
        title="Lore"
        action={
          <button
            onClick={onNewLore}
            className="text-fg-subtle hover:text-fg p-1 rounded-md hover:bg-[var(--surface)]"
            aria-label="Add lore entry"
          >
            <Plus size={14} />
          </button>
        }
      >
        {loreEntries.length === 0 ? (
          <Empty label="No lore yet" />
        ) : (
          <ul className="space-y-0.5">
            {loreEntries.map((l) => (
              <li key={l.id}>
                <button
                  onClick={() => onEditLore(l.id)}
                  className="w-full flex items-center gap-2 px-2.5 py-1.5 rounded-md text-sm text-left text-fg-muted hover:text-fg hover:bg-[var(--surface)] transition-colors"
                >
                  {l.imagePath ? (
                    <img
                      src={l.imagePath}
                      alt=""
                      className="w-5 h-5 rounded-sm object-cover shrink-0"
                    />
                  ) : (
                    <BookOpen size={14} className="shrink-0 opacity-70" />
                  )}
                  <span className="truncate">{l.name}</span>
                  <span className="ml-auto text-[10px] text-fg-subtle uppercase tracking-wider">
                    {l.kind.slice(0, 4)}
                  </span>
                </button>
              </li>
            ))}
          </ul>
        )}
      </Section>
    </nav>
  );
}

function Section({
  title,
  action,
  children,
}: {
  title: string;
  action?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <div className="border-b border-border p-3">
      <div className="flex items-center justify-between px-1.5 mb-1.5">
        <h3 className="text-[10px] font-semibold uppercase tracking-wider text-fg-subtle">
          {title}
        </h3>
        {action}
      </div>
      {children}
    </div>
  );
}

function Empty({ label }: { label: string }) {
  return <div className="px-2.5 py-2 text-xs text-fg-subtle">{label}</div>;
}
