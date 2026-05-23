"use client";

import { useRef, useState } from "react";
import { Send } from "lucide-react";
import { cn } from "@/lib/utils";

type Message = { role: "user" | "assistant"; content: string };

export function ChatPanel({ projectId }: { projectId: string }) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [streaming, setStreaming] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);

  async function send() {
    const text = input.trim();
    if (!text || streaming) return;
    const next: Message[] = [...messages, { role: "user", content: text }];
    setMessages(next);
    setInput("");
    setStreaming(true);
    try {
      const res = await fetch("/api/chat", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ projectId, messages: next }),
      });
      if (!res.body) return;
      const reader = res.body.getReader();
      const decoder = new TextDecoder();
      let acc = "";
      setMessages([...next, { role: "assistant", content: "" }]);
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        acc += decoder.decode(value, { stream: true });
        setMessages([...next, { role: "assistant", content: acc }]);
        requestAnimationFrame(() => {
          scrollRef.current?.scrollTo({
            top: scrollRef.current.scrollHeight,
          });
        });
      }
    } finally {
      setStreaming(false);
    }
  }

  return (
    <div className="flex-1 min-h-0 flex flex-col">
      <div ref={scrollRef} className="flex-1 overflow-auto px-4 py-4 space-y-4">
        {messages.length === 0 ? (
          <div className="text-xs text-fg-subtle px-1 py-8 text-center">
            Ask for ideas, feedback, or to brainstorm what happens next.
          </div>
        ) : (
          messages.map((m, i) => (
            <div
              key={i}
              className={cn(
                "text-sm leading-relaxed",
                m.role === "user" ? "text-fg" : "text-fg-muted"
              )}
            >
              <div className="text-[10px] uppercase tracking-wider text-fg-subtle font-semibold mb-1">
                {m.role === "user" ? "You" : "Collaborator"}
              </div>
              <div className="whitespace-pre-wrap">{m.content}</div>
            </div>
          ))
        )}
      </div>
      <div className="border-t border-border p-3">
        <div className="flex items-end gap-2 rounded-lg border border-border bg-[var(--surface)] focus-within:border-border-strong transition-colors">
          <textarea
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && !e.shiftKey) {
                e.preventDefault();
                send();
              }
            }}
            placeholder="Message…"
            rows={1}
            className="flex-1 bg-transparent resize-none px-3 py-2.5 text-sm focus:outline-none placeholder:text-fg-subtle max-h-40"
          />
          <button
            onClick={send}
            disabled={!input.trim() || streaming}
            className="m-1 h-7 w-7 rounded-md bg-accent text-accent-fg flex items-center justify-center disabled:opacity-30 disabled:cursor-not-allowed hover:opacity-90"
            aria-label="Send"
          >
            <Send size={13} />
          </button>
        </div>
      </div>
    </div>
  );
}
