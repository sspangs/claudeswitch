"use client";

import { useState } from "react";
import { Sidebar } from "./sidebar";
import { Editor } from "./editor";
import { ChatPanel } from "./chat-panel";
import { LoreModal } from "./lore-modal";
import { MessageSquare, X } from "lucide-react";
import { cn } from "@/lib/utils";

export type ProjectMeta = {
  id: string;
  title: string;
  synopsis: string;
  styleNote: string;
};

export type ChapterMeta = {
  id: string;
  title: string;
  order: number;
};

export type LoreMeta = {
  id: string;
  name: string;
  kind: string;
  description: string;
  imagePath: string | null;
};

export type ActiveChapter = {
  id: string;
  title: string;
  content: string;
};

export function ProjectShell({
  project,
  chapters,
  loreEntries,
  activeChapter,
}: {
  project: ProjectMeta;
  chapters: ChapterMeta[];
  loreEntries: LoreMeta[];
  activeChapter: ActiveChapter | null;
}) {
  const [chatOpen, setChatOpen] = useState(true);
  const [editingLoreId, setEditingLoreId] = useState<string | null>(null);
  const [creatingLore, setCreatingLore] = useState(false);

  const editingLore =
    editingLoreId === "__new__"
      ? null
      : loreEntries.find((l) => l.id === editingLoreId) ?? null;

  return (
    <div className="flex flex-1 min-h-0">
      <Sidebar
        projectId={project.id}
        chapters={chapters}
        loreEntries={loreEntries}
        activeChapterId={activeChapter?.id ?? null}
        onEditLore={(id) => setEditingLoreId(id)}
        onNewLore={() => setCreatingLore(true)}
      />

      <main className="flex-1 min-w-0 flex flex-col">
        {activeChapter ? (
          <Editor
            key={activeChapter.id}
            chapterId={activeChapter.id}
            initialTitle={activeChapter.title}
            initialContent={activeChapter.content}
            projectId={project.id}
          />
        ) : (
          <div className="flex-1 flex items-center justify-center text-fg-subtle">
            No chapters yet.
          </div>
        )}
      </main>

      <aside
        className={cn(
          "border-l border-border vibrancy transition-[width] duration-200 flex flex-col",
          chatOpen ? "w-[380px]" : "w-12"
        )}
      >
        {chatOpen ? (
          <>
            <div className="h-11 px-3 flex items-center justify-between border-b border-border">
              <div className="text-sm font-medium">Collaborator</div>
              <button
                onClick={() => setChatOpen(false)}
                className="text-fg-subtle hover:text-fg p-1 rounded-md hover:bg-[var(--surface)]"
                aria-label="Collapse chat"
              >
                <X size={16} />
              </button>
            </div>
            <ChatPanel projectId={project.id} />
          </>
        ) : (
          <button
            onClick={() => setChatOpen(true)}
            className="h-11 flex items-center justify-center text-fg-muted hover:text-fg"
            aria-label="Open chat"
          >
            <MessageSquare size={18} />
          </button>
        )}
      </aside>

      {(creatingLore || editingLoreId) && (
        <LoreModal
          projectId={project.id}
          entry={editingLore}
          onClose={() => {
            setEditingLoreId(null);
            setCreatingLore(false);
          }}
        />
      )}
    </div>
  );
}
