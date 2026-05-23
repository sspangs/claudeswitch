# Scriptorium

A creative writing assistant for long-form fiction. Quiet, Apple-flavored UI on top
of Claude and an image model — for drafting, brainstorming, editing, and
worldbuilding in one place.

## Stack

- **Next.js 16** (App Router) + TypeScript
- **Tailwind v4** with custom Apple-style design tokens
- **SQLite** via **Prisma 6**
- **Tiptap** for the editor
- **Anthropic SDK** — Claude Sonnet 4.6, streaming + prompt caching
- **fal.ai** + Flux Schnell for portrait / location image generation
- No auth — single-user, runs on localhost

## Getting started

```bash
npm install
cp .env.example .env.local      # optional, fill in keys when you have them
npm run db:push                 # creates dev.db
npm run dev
```

Open <http://localhost:3000>.

The app works without any API keys — AI endpoints return placeholder text,
and the image generator returns a deterministic SVG placeholder. Add
`ANTHROPIC_API_KEY` and `FAL_KEY` to `.env.local` to get the real thing.

## What's here

- `/` — project list, create new projects
- `/projects/[id]` — three-column workspace
  - Sidebar: chapters and lore entries
  - Center: Tiptap editor with "Continue from here" and "Critique selection"
  - Right: streaming chat panel with full project context

Project context (synopsis, style notes, lore entries) is injected into every
Claude call as a cached system prompt — so adding more lore costs almost
nothing on subsequent turns.

## Layout

```
prisma/schema.prisma      # Project, Chapter, LoreEntry
src/
  app/
    page.tsx              # project list
    projects/[id]/page.tsx
    api/
      chat/route.ts       # streaming chat
      continue/route.ts   # editor continuation
      critique/route.ts   # selection critique
      chapters/...        # CRUD
      lore/...            # CRUD + image generation
  components/
    project-shell.tsx     # three-column client wrapper
    sidebar.tsx
    editor.tsx            # Tiptap + AI actions
    chat-panel.tsx
    lore-modal.tsx        # name/kind/description + portrait
  lib/
    db.ts                 # Prisma singleton
    anthropic.ts          # client + system prompt builder
    fal.ts                # image generation + SVG placeholder
    stream.ts             # ReadableStream wrapper around Claude streaming
    context.ts            # loads ProjectContext from DB
```

## Roadmap (post-MVP)

- Outline view with per-beat drafting
- Tag-based lore injection so projects can outgrow the context window
- Consistency check action (current scene vs. lore)
- Export to Markdown / EPUB
- Multi-user + cloud storage
