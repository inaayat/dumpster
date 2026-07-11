import { NextResponse } from 'next/server';
import { withAuth } from '@/lib/server/auth';
import { createWin, listWins } from '@/lib/server/store';

export const GET = withAuth(async (_req, user) => {
  const wins = await listWins(user.id);
  return NextResponse.json({ wins });
});

export const POST = withAuth(async (req, user) => {
  const body = await req.json();
  const text = typeof body.text === 'string' ? body.text.trim() : '';
  if (!text) return NextResponse.json({ error: 'text is required.' }, { status: 400 });
  const win = await createWin(user.id, text, typeof body.artifact === 'string' ? body.artifact : null);
  return NextResponse.json({ win }, { status: 201 });
});
