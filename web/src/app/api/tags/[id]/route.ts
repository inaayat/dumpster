import { NextResponse } from 'next/server';
import { withAuth } from '@/lib/server/auth';
import { deleteTag, renameTag } from '@/lib/server/store';

type Ctx = { params: Promise<{ id: string }> };

// Rename. Renaming onto an existing tag merges them (returns the id the
// tag ended up as, so the client can re-point selection).
export const PATCH = withAuth<Ctx>(async (req, user, ctx) => {
  const { id } = await ctx.params;
  const body = await req.json();
  if (typeof body.name !== 'string' || !body.name.trim()) {
    return NextResponse.json({ error: 'name is required.' }, { status: 400 });
  }
  const resultingId = await renameTag(user.id, id, body.name);
  return NextResponse.json({ id: resultingId, merged: resultingId !== id });
});

export const DELETE = withAuth<Ctx>(async (_req, user, ctx) => {
  const { id } = await ctx.params;
  await deleteTag(user.id, id);
  return NextResponse.json({ ok: true });
});
