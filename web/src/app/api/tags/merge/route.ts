import { NextResponse } from 'next/server';
import { withAuth } from '@/lib/server/auth';
import { mergeTags } from '@/lib/server/store';

// Merge one tag into another (drag a pill onto another in the apps).
export const POST = withAuth(async (req, user) => {
  const body = await req.json();
  if (typeof body.fromId !== 'string' || typeof body.toId !== 'string') {
    return NextResponse.json({ error: 'fromId and toId are required.' }, { status: 400 });
  }
  await mergeTags(user.id, body.fromId, body.toId);
  return NextResponse.json({ ok: true });
});
