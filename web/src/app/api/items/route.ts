import { NextResponse } from 'next/server';
import { withAuth } from '@/lib/server/auth';
import { extractTags, stripTags } from '@/lib/magic';
import { createItem, listItems, tagItemWithNames, getItem } from '@/lib/server/store';
import type { Category, Priority } from '@/lib/types';

export const GET = withAuth(async (_req, user) => {
  const items = await listItems(user.id);
  return NextResponse.json({ items });
});

// Creates an item. #tags inside the text become tag associations and are
// stripped from the stored title, matching the apps' edit behavior.
export const POST = withAuth(async (req, user) => {
  const body = await req.json();
  const rawText = typeof body.text === 'string' ? body.text.trim() : '';
  if (!rawText) return NextResponse.json({ error: 'text is required.' }, { status: 400 });

  const tagNames = [...extractTags(rawText), ...(Array.isArray(body.tagNames) ? body.tagNames : [])];
  const item = await createItem(user.id, {
    text: stripTags(rawText) || rawText,
    category: body.category as Category | undefined,
    priority: body.priority as Priority | undefined,
    dueDate: body.dueDate ?? null,
    url: body.url ?? null,
    urlTitle: body.urlTitle ?? null,
    notes: body.notes ?? null,
  });
  if (tagNames.length) await tagItemWithNames(user.id, item.id, tagNames);
  return NextResponse.json({ item: await getItem(user.id, item.id) }, { status: 201 });
});
