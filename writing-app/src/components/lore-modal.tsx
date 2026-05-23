"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import * as Dialog from "@radix-ui/react-dialog";
import { ImagePlus, X, LoaderCircle } from "lucide-react";
import { Button } from "./ui/button";
import type { LoreMeta } from "./project-shell";

const KINDS = ["character", "location", "faction", "other"];

export function LoreModal({
  projectId,
  entry,
  onClose,
}: {
  projectId: string;
  entry: LoreMeta | null;
  onClose: () => void;
}) {
  const router = useRouter();
  const [name, setName] = useState(entry?.name ?? "");
  const [kind, setKind] = useState(entry?.kind ?? "character");
  const [description, setDescription] = useState(entry?.description ?? "");
  const [imagePath, setImagePath] = useState<string | null>(
    entry?.imagePath ?? null
  );
  const [saving, setSaving] = useState(false);
  const [generating, setGenerating] = useState(false);
  const [open, setOpen] = useState(true);

  useEffect(() => {
    if (!open) onClose();
  }, [open, onClose]);

  async function save() {
    setSaving(true);
    try {
      const method = entry ? "PATCH" : "POST";
      const url = entry ? `/api/lore/${entry.id}` : "/api/lore";
      await fetch(url, {
        method,
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ projectId, name, kind, description }),
      });
      router.refresh();
      setOpen(false);
    } finally {
      setSaving(false);
    }
  }

  async function generatePortrait() {
    if (!entry) {
      await save();
      return;
    }
    setGenerating(true);
    try {
      const res = await fetch(`/api/lore/${entry.id}/image`, {
        method: "POST",
      });
      const data = (await res.json()) as { imagePath?: string };
      if (data.imagePath) setImagePath(data.imagePath);
      router.refresh();
    } finally {
      setGenerating(false);
    }
  }

  async function remove() {
    if (!entry) return;
    await fetch(`/api/lore/${entry.id}`, { method: "DELETE" });
    router.refresh();
    setOpen(false);
  }

  return (
    <Dialog.Root open={open} onOpenChange={setOpen}>
      <Dialog.Portal>
        <Dialog.Overlay className="fixed inset-0 z-40 bg-black/50 backdrop-blur-sm data-[state=open]:animate-in data-[state=open]:fade-in-0" />
        <Dialog.Content className="fixed left-1/2 top-1/2 z-50 -translate-x-1/2 -translate-y-1/2 w-[640px] max-w-[92vw] rounded-xl border border-border bg-bg-elev shadow-[var(--shadow-soft)]">
          <div className="flex items-center justify-between px-5 h-12 border-b border-border">
            <Dialog.Title className="text-sm font-medium">
              {entry ? "Edit lore entry" : "New lore entry"}
            </Dialog.Title>
            <Dialog.Close asChild>
              <button className="text-fg-subtle hover:text-fg p-1 rounded-md hover:bg-[var(--surface)]">
                <X size={16} />
              </button>
            </Dialog.Close>
          </div>

          <div className="grid grid-cols-[200px_1fr] gap-5 p-5">
            <div>
              <div className="aspect-square rounded-lg border border-border bg-[var(--surface)] overflow-hidden flex items-center justify-center">
                {imagePath ? (
                  <img
                    src={imagePath}
                    alt={name}
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <div className="text-xs text-fg-subtle">No image yet</div>
                )}
              </div>
              <button
                onClick={generatePortrait}
                disabled={generating || !entry}
                className="mt-2 w-full inline-flex items-center justify-center gap-1.5 h-8 text-xs rounded-md border border-border text-fg-muted hover:text-fg hover:bg-[var(--surface)] hover:border-border-strong transition-colors disabled:opacity-50"
              >
                {generating ? (
                  <>
                    <LoaderCircle size={12} className="animate-spin" /> Generating…
                  </>
                ) : (
                  <>
                    <ImagePlus size={12} /> Generate image
                  </>
                )}
              </button>
              {!entry && (
                <p className="mt-1.5 text-[10px] text-fg-subtle">
                  Save first to enable image generation.
                </p>
              )}
            </div>

            <div className="space-y-3">
              <Field label="Name">
                <input
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="Elara Vance"
                  className="w-full rounded-md bg-[var(--surface)] border border-border px-3 py-2 text-sm focus:outline-none focus:border-border-strong"
                />
              </Field>
              <Field label="Type">
                <div className="flex gap-1.5">
                  {KINDS.map((k) => (
                    <button
                      key={k}
                      onClick={() => setKind(k)}
                      className={
                        "text-xs px-2.5 h-7 rounded-md border transition-colors " +
                        (kind === k
                          ? "bg-accent text-accent-fg border-accent"
                          : "border-border text-fg-muted hover:text-fg hover:bg-[var(--surface)]")
                      }
                    >
                      {k}
                    </button>
                  ))}
                </div>
              </Field>
              <Field label="Description">
                <textarea
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="Appearance, personality, background…"
                  rows={6}
                  className="w-full rounded-md bg-[var(--surface)] border border-border px-3 py-2 text-sm focus:outline-none focus:border-border-strong resize-y"
                />
              </Field>
            </div>
          </div>

          <div className="flex items-center justify-between px-5 h-12 border-t border-border">
            <div>
              {entry && (
                <Button variant="ghost" size="sm" onClick={remove}>
                  Delete
                </Button>
              )}
            </div>
            <div className="flex gap-2">
              <Dialog.Close asChild>
                <Button variant="ghost" size="sm">
                  Cancel
                </Button>
              </Dialog.Close>
              <Button
                variant="primary"
                size="sm"
                onClick={save}
                disabled={saving || !name.trim()}
              >
                {saving ? "Saving…" : "Save"}
              </Button>
            </div>
          </div>
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}

function Field({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <div>
      <div className="text-[10px] uppercase tracking-wider text-fg-subtle font-semibold mb-1">
        {label}
      </div>
      {children}
    </div>
  );
}
