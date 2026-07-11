import { NextResponse } from 'next/server';
import { withAuth } from '@/lib/server/auth';
import { addSubTag, removeSubTag } from '@/lib/server/store';

export const POST = withAuth(async (req, user) => {
  const body = await req.json();
  if (typeof body.parentId !== 'string' || typeof body.childId !== 'string') {
    return NextResponse.json({ error: 'parentId and childId are required.' }, { status: 400 });
  }
  await addSubTag(user.id, body.parentId, body.childId);
  return NextResponse.json({ ok: true });
});

export const DELETE = withAuth(async (req, user) => {
  const body = await req.json();
  if (typeof body.parentId !== 'string' || typeof body.childId !== 'string') {
    return NextResponse.json({ error: 'parentId and childId are required.' }, { status: 400 });
  }
  await removeSubTag(user.id, body.parentId, body.childId);
  return NextResponse.json({ ok: true });
});
