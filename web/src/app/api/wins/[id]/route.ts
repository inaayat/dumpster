import { NextResponse } from 'next/server';
import { withAuth } from '@/lib/server/auth';
import { deleteWin, updateWin } from '@/lib/server/store';

type Ctx = { params: Promise<{ id: string }> };

export const PATCH = withAuth<Ctx>(async (req, user, ctx) => {
  const { id } = await ctx.params;
  const body = await req.json();
  const win = await updateWin(user.id, id, {
    text: typeof body.text === 'string' ? body.text : undefined,
    artifact: body.artifact !== undefined ? body.artifact : undefined,
  });
  if (!win) return NextResponse.json({ error: 'Win not found.' }, { status: 404 });
  return NextResponse.json({ win });
});

export const DELETE = withAuth<Ctx>(async (_req, user, ctx) => {
  const { id } = await ctx.params;
  await deleteWin(user.id, id);
  return NextResponse.json({ ok: true });
});
