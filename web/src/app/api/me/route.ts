// Upserts the signed-in user into the shared `users` table (the same one
// inaayat.xyz's /api/me maintains) so dumpster rows can always be joined
// back to a known account.
import { NextResponse } from 'next/server';
import { withAuth } from '@/lib/server/auth';
import { db } from '@/lib/server/db';

export const GET = withAuth(async (_req, user) => {
  const rows = await db()`
    INSERT INTO users (id, email, name)
    VALUES (${user.id}, ${user.email}, ${user.name})
    ON CONFLICT (id) DO UPDATE
      SET email = EXCLUDED.email, name = EXCLUDED.name, last_seen_at = now()
    RETURNING id, email, name, created_at`;
  return NextResponse.json({ user: (rows as Record<string, unknown>[])[0] });
});
