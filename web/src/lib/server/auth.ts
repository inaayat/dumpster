// Verifies Neon Auth session JWTs, same trust model as inaayat.xyz's
// lib/neon-auth.js: the browser talks to the hosted Neon Auth service
// directly and hands us a JWT via `Authorization: Bearer <token>`, which
// we verify statelessly against the service's public JWKS.
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { NextRequest, NextResponse } from 'next/server';

let _jwks: ReturnType<typeof createRemoteJWKSet> | null = null;

function jwks() {
  if (!_jwks) _jwks = createRemoteJWKSet(new URL('/jwks', process.env.NEON_AUTH_BASE_URL));
  return _jwks;
}

export interface AuthUser {
  id: string;
  email: string | null;
  name: string | null;
}

export async function getAuth(req: NextRequest): Promise<AuthUser | null> {
  const header = req.headers.get('authorization') || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token || !process.env.NEON_AUTH_BASE_URL) return null;
  try {
    const { payload } = await jwtVerify(token, jwks(), {
      issuer: process.env.NEON_AUTH_BASE_URL,
      audience: process.env.NEON_AUTH_BASE_URL,
    });
    if (!payload.sub) return null;
    return {
      id: payload.sub,
      email: typeof payload.email === 'string' ? payload.email : null,
      name: typeof payload.name === 'string' ? payload.name : null,
    };
  } catch {
    return null;
  }
}

type Handler<Ctx> = (req: NextRequest, user: AuthUser, ctx: Ctx) => Promise<NextResponse>;

// Wraps a route handler with auth + uniform error handling. Routes only
// ever see a verified user.
export function withAuth<Ctx = unknown>(handler: Handler<Ctx>) {
  return async (req: NextRequest, ctx: Ctx): Promise<NextResponse> => {
    if (!process.env.NEON_AUTH_BASE_URL || !process.env.DATABASE_URL) {
      return NextResponse.json(
        { error: 'Server not configured: set NEON_AUTH_BASE_URL and DATABASE_URL.' },
        { status: 503 },
      );
    }
    const user = await getAuth(req);
    if (!user) {
      return NextResponse.json({ error: 'Not signed in.' }, { status: 401 });
    }
    try {
      return await handler(req, user, ctx);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unexpected error';
      return NextResponse.json({ error: message }, { status: 500 });
    }
  };
}
