"use client";

import { useEditor, EditorContent } from "@tiptap/react";
import StarterKit from "@tiptap/starter-kit";
import { useEffect, useRef, useState } from "react";
import { Sparkles, Pencil, ArrowRight } from "lucide-react";

const SAVE_DEBOUNCE_MS = 800;

export function Editor({
  chapterId,
  initialTitle,
  initialContent,
  projectId,
}: {
  chapterId: string;
  initialTitle: string;
  initialContent: string;
  projectId: string;
}) {
  const [title, setTitle] = useState(initialTitle);
  const [savedAt, setSavedAt] = useState<Date | null>(null);
  const [actionBusy, setActionBusy] = useState<null | "continue" | "critique">(
    null
  );
  const [critique, setCritique] = useState<string | null>(null);
  const [hasSelection, setHasSelection] = useState(false);
  const saveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const editor = useEditor({
    extensions: [
      StarterKit.configure({
        heading: { levels: [1, 2, 3] },
      }),
    ],
    content: initialContent || "<p></p>",
    editorProps: {
      attributes: {
        class: "outline-none",
      },
    },
    immediatelyRender: false,
    onUpdate: () => scheduleSave(),
    onSelectionUpdate: ({ editor: e }) => {
      const { from, to } = e.state.selection;
      setHasSelection(from !== to);
    },
  });

  function scheduleSave() {
    if (saveTimer.current) clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(save, SAVE_DEBOUNCE_MS);
  }

  async function save() {
    if (!editor) return;
    const content = editor.getHTML();
    await fetch(`/api/chapters/${chapterId}`, {
      method: "PATCH",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ title, content }),
    });
    setSavedAt(new Date());
  }

  useEffect(() => {
    return () => {
      if (saveTimer.current) clearTimeout(saveTimer.current);
    };
  }, []);

  async function continueWriting() {
    if (!editor || actionBusy) return;
    setActionBusy("continue");
    try {
      const before = editor.getText();
      const res = await fetch("/api/continue", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ projectId, before }),
      });
      if (!res.body) return;
      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      editor.chain().focus().insertContent(" ").run();
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        const chunk = decoder.decode(value, { stream: true });
        editor.chain().focus().insertContent(chunk).run();
      }
      scheduleSave();
    } finally {
      setActionBusy(null);
    }
  }

  async function critiqueSelection() {
    if (!editor || actionBusy) return;
    const { from, to } = editor.state.selection;
    if (from === to) return;
    const selected = editor.state.doc.textBetween(from, to, " ");
    setActionBusy("critique");
    setCritique("");
    try {
      const res = await fetch("/api/critique", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ projectId, selection: selected }),
      });
      if (!res.body) return;
      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let acc = "";
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        acc += decoder.decode(value, { stream: true });
        setCritique(acc);
      }
    } finally {
      setActionBusy(null);
    }
  }

  return (
    <div className="flex flex-col flex-1 min-h-0">
      <div className="border-b border-border px-12 py-6 flex items-baseline gap-4">
        <input
          value={title}
          onChange={(e) => {
            setTitle(e.target.value);
            scheduleSave();
          }}
          className="flex-1 bg-transparent text-2xl font-semibold tracking-tight focus:outline-none"
        />
        <div className="text-xs text-fg-subtle shrink-0">
          {savedAt ? `Saved ${savedAt.toLocaleTimeString()}` : "Unsaved"}
        </div>
      </div>

      <div className="flex-1 overflow-auto px-12 py-8">
        <div className="max-w-2xl mx-auto">
          <EditorContent editor={editor} />
          <div className="mt-6 flex gap-2">
            <button
              onClick={continueWriting}
              disabled={actionBusy !== null}
              className="inline-flex items-center gap-2 px-3.5 h-9 text-sm rounded-md border border-border text-fg-muted hover:text-fg hover:bg-[var(--surface)] hover:border-border-strong transition-colors disabled:opacity-50"
            >
              <Sparkles size={14} />
              {actionBusy === "continue" ? "Continuing…" : "Continue from here"}
              <ArrowRight size={12} className="opacity-50" />
            </button>
            {hasSelection && (
              <button
                onClick={critiqueSelection}
                disabled={actionBusy !== null}
                className="inline-flex items-center gap-2 px-3.5 h-9 text-sm rounded-md border border-border text-fg-muted hover:text-fg hover:bg-[var(--surface)] hover:border-border-strong transition-colors disabled:opacity-50"
              >
                <Pencil size={14} />
                {actionBusy === "critique"
                  ? "Critiquing…"
                  : "Critique selection"}
              </button>
            )}
          </div>
        </div>
      </div>

      {critique !== null && (
        <div className="border-t border-border vibrancy px-12 py-4">
          <div className="max-w-2xl mx-auto">
            <div className="flex items-center justify-between mb-2">
              <div className="text-[10px] uppercase tracking-wider text-fg-subtle font-semibold">
                Critique
              </div>
              <button
                onClick={() => setCritique(null)}
                className="text-xs text-fg-subtle hover:text-fg"
              >
                Dismiss
              </button>
            </div>
            <div className="text-sm text-fg-muted whitespace-pre-wrap">
              {critique || (actionBusy === "critique" ? "Thinking…" : "")}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
