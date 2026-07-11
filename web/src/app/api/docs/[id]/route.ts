import { NextResponse } from 'next/server';
import { withAuth } from '@/lib/server/auth';
import { parseBullets, stripTags } from '@/lib/magic';
import { extractHeadings } from '@/lib/markdown';
import {
  deleteDoc,
  getDoc,
  listDumps,
  listHiddenBullets,
  listItems,
  listTags,
  updateDoc,
  type DocPatch,
} from '@/lib/server/store';

type Ctx = { params: Promise<{ id: string }> };

// A doc plus its inbox: unincorporated items tagged with any of the
// doc's tags, and dump bullets carrying those tags that aren't in the
// doc yet (iOS's "all tagged content flows into the inbox").
export const GET = withAuth<Ctx>(async (_req, user, ctx) => {
  const { id } = await ctx.params;
  const doc = await getDoc(user.id, id);
  if (!doc) return NextResponse.json({ error: 'Doc not found.' }, { status: 404 });

  const [items, tags, dumps, hidden] = await Promise.all([
    listItems(user.id),
    listTags(user.id),
    listDumps(user.id, 90),
    listHiddenBullets(user.id),
  ]);

  const docTagIds = new Set(doc.tagIds);
  const docTagNames = new Set(
    tags.filter((t) => docTagIds.has(t.id)).map((t) => t.name),
  );

  const inboxItems = items.filter(
    (item) =>
      !item.incorporatedIntoDoc &&
      !item.dismissedFromDoc &&
      item.tagIds.some((tid) => docTagIds.has(tid)),
  );
  const allItems = items.filter((item) => item.tagIds.some((tid) => docTagIds.has(tid)));

  const hiddenSet = new Set(hidden);
  const seen = new Set<string>();
  const inboxBullets: { text: string; date: string }[] = [];
  for (const dump of dumps) {
    for (const bullet of parseBullets(dump.content)) {
      if (!bullet.tags.some((t) => docTagNames.has(t))) continue;
      const clean = stripTags(bullet.text);
      if (!clean || hiddenSet.has(clean) || seen.has(clean)) continue;
      if (doc.content.includes(clean)) continue;
      seen.add(clean);
      inboxBullets.push({ text: clean, date: dump.date });
    }
  }

  return NextResponse.json({
    doc,
    headings: extractHeadings(doc.content),
    inboxItems,
    inboxBullets,
    allItems,
  });
});

export const PATCH = withAuth<Ctx>(async (req, user, ctx) => {
  const { id } = await ctx.params;
  const body = (await req.json()) as DocPatch;
  const doc = await updateDoc(user.id, id, body);
  if (!doc) return NextResponse.json({ error: 'Doc not found.' }, { status: 404 });
  return NextResponse.json({ doc });
});

export const DELETE = withAuth<Ctx>(async (_req, user, ctx) => {
  const { id } = await ctx.params;
  await deleteDoc(user.id, id);
  return NextResponse.json({ ok: true });
});
