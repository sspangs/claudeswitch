import { db } from "@/lib/db";

export async function POST(req: Request) {
  const { projectId, title } = (await req.json()) as {
    projectId: string;
    title?: string;
  };

  const last = await db.chapter.findFirst({
    where: { projectId },
    orderBy: { order: "desc" },
  });
  const order = (last?.order ?? -1) + 1;

  const chapter = await db.chapter.create({
    data: {
      projectId,
      title: title || `Chapter ${order + 1}`,
      order,
    },
  });

  return Response.json({ id: chapter.id });
}
