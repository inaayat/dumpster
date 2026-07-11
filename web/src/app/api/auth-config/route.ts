// Public (unauthenticated) — hands the Neon Auth base URL to the browser
// at request time, mirroring inaayat.xyz's api/auth-config.js. Same trust
// level as an OAuth client id; the real gate is JWT verification.
import { NextResponse } from 'next/server';

export function GET() {
  return NextResponse.json(
    { url: process.env.NEON_AUTH_BASE_URL || null },
    { headers: { 'Cache-Control': 'public, max-age=300' } },
  );
}
