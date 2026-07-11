import { NextResponse } from 'next/server';
import { withAuth } from '@/lib/server/auth';
import { insertUnderHeading } from '@/lib/markdown';
import { getDoc, getItem, hideBullet, updateDoc, updateItem } from '@/lib/server/store';

type Ctx = { params: Promise<{ id: string }> };

// Adds an inbox entry to the doc under a heading (or at the end when
// heading is null). Accepts either an itemId (marks the item
// incorporated) or a raw bulletText from a dump. `dismiss: true` removes
// the entry from the inbox without touching the doc.
export const POST = withAuth<Ctx>(async (req, user, ctx) => {
  const { id } = await ctx.params;
  const body = await req.json();
  const doc = await getDoc(user.id, id);
  if (!doc) return NextResponse.json({ error: 'Doc not found.' }, { status: 404 });

  const heading = typeof body.heading === 'string' ? body.heading : null;
  const dismiss = body.dismiss === true;

  let text: string | null = null;
  if (typeof body.itemId === 'string') {
    const item = await getItem(user.id, body.itemId);
    if (!item) return NextResponse.json({ error: 'Item not found.' }, { status: 404 });
    text = item.text;
    await updateItem(user.id, item.id, dismiss ? { dismissedFromDoc: true } : { incorporatedIntoDoc: true });
  } else if (typeof body.bulletText === 'string' && body.bulletText.trim()) {
    const bulletText: string = body.bulletText.trim();
    text = bulletText;
    if (dismiss) await hideBullet(user.id, bulletText);
  } else {
    return NextResponse.json({ error: 'itemId or bulletText is required.' }, { status: 400 });
  }

  if (dismiss) return NextResponse.json({ ok: true, doc });

  const content = insertUnderHeading(doc.content, heading, text!);
  const updated = await updateDoc(user.id, id, { content });
  return NextResponse.json({ ok: true, doc: updated });
});
