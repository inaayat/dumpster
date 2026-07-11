import { NextResponse } from 'next/server';
import { withAuth } from '@/lib/server/auth';
import { processLine } from '@/lib/server/processor';

type Ctx = { params: Promise<{ date: string }> };

// Runs magic-tag processing for one completed dump line (fired on Enter,
// like the apps). Returns what was created so the UI can toast it.
export const POST = withAuth<Ctx>(async (req, user) => {
  const body = await req.json();
  if (typeof body.line !== 'string' || !body.line.trim()) {
    return NextResponse.json({ error: 'line (string) is required.' }, { status: 400 });
  }
  const result = await processLine(user.id, body.line);
  return NextResponse.json({ result });
});
