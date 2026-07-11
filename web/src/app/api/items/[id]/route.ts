import { NextResponse } from 'next/server';
import { withAuth } from '@/lib/server/auth';
import { extractTags, stripTags } from '@/lib/magic';
import {
  deleteItem,
  getItem,
  tagItemWithNames,
  updateItem,
  type ItemPatch,
} from '@/lib/server/store';

type Ctx = { params: Promise<{ id: string }> };

export const PATCH = withAuth<Ctx>(async (req, user, ctx) => {
  const { id } = await ctx.params;
  const body = (await req.json()) as ItemPatch & { text?: string };

  // Editing text with #tags in it strips them from the title and adds
  // them as tag associations (same as the apps' edit sheet). Inline tags
  // are additive; an explicit tagNames array replaces the item's tags.
  let inlineTags: string[] = [];
  if (typeof body.text === 'string') {
    inlineTags = extractTags(body.text);
    if (inlineTags.length) body.text = stripTags(body.text) || body.text;
  }

  const item = await updateItem(user.id, id, body);
  if (!item) return NextResponse.json({ error: 'Item not found.' }, { status: 404 });

  if (inlineTags.length) {
    await tagItemWithNames(user.id, id, inlineTags);
    return NextResponse.json({ item: await getItem(user.id, id) });
  }
  return NextResponse.json({ item });
});

export const DELETE = withAuth<Ctx>(async (_req, user, ctx) => {
  const { id } = await ctx.params;
  await deleteItem(user.id, id);
  return NextResponse.json({ ok: true });
});
