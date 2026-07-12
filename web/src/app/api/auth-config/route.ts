// Public (unauthenticated) — tells the browser where to reach Neon Auth.
// We hand back our own /api/auth proxy path (see api/auth/[...path])
// rather than the raw cross-origin service URL: Safari — and iOS
// standalone PWAs in particular — silently drop the session cookie when
// it's set by a cross-site fetch, so the client must talk to Neon Auth
// as same-origin. Same trust level as an OAuth client id either way; the
// real gate is JWT verification.
import { NextResponse } from 'next/server';

export function GET() {
  return NextResponse.json(
    { url: process.env.NEON_AUTH_BASE_URL ? '/api/auth' : null },
    { headers: { 'Cache-Control': 'public, max-age=300' } },
  );
}
