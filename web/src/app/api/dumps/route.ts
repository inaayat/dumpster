import { NextResponse } from 'next/server';
import { withAuth } from '@/lib/server/auth';
import { listDumps } from '@/lib/server/store';

export const GET = withAuth(async (req, user) => {
  const limit = Number(req.nextUrl.searchParams.get('limit') || 30);
  const dumps = await listDumps(user.id, Math.min(Math.max(limit, 1), 365));
  return NextResponse.json({ dumps });
});
