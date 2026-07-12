// Reverse proxy for Neon Auth. The browser talks to Neon Auth at this
// same-origin path instead of the raw cross-origin service URL (see
// /api/auth-config) so the session cookie Neon Auth sets is first-party —
// Safari, and iOS standalone PWAs especially, silently drop cookies set
// by a cross-site fetch, which broke sign-in there while it worked fine
// in a regular browser tab.
//
// This has to be a route handler, not a next.config.ts rewrite: a
// rewrite preserves the browser's original Host header, and Better
// Auth's server rejects requests whose Host doesn't match its own
// hostname. Making our own outbound fetch sets Host correctly from the
// destination URL instead.
import { NextRequest, NextResponse } from 'next/server';

// Headers that must not be copied across the proxy boundary: connection
// management is per-hop, content-encoding/content-length can go stale
// because fetch() transparently decompresses the upstream body, and the
// x-forwarded-* family (which Next.js/Vercel inject on the inbound
// request) leaks our own hostname upstream — Neon Auth checks those
// against its own hostname and 400s the request if they don't match.
const STRIP_REQUEST_HEADERS = new Set([
  'host',
  'connection',
  'content-length',
  'forwarded',
  'x-forwarded-host',
  'x-forwarded-proto',
  'x-forwarded-for',
  'x-forwarded-port',
]);
const STRIP_RESPONSE_HEADERS = new Set([
  'connection',
  'content-encoding',
  'content-length',
  'transfer-encoding',
]);

async function proxy(req: NextRequest, ctx: { params: Promise<{ path: string[] }> }) {
  const base = process.env.NEON_AUTH_BASE_URL;
  if (!base) return NextResponse.json({ error: 'Not configured' }, { status: 503 });

  const { path } = await ctx.params;
  const upstreamUrl = `${base.replace(/\/$/, '')}/${path.join('/')}${req.nextUrl.search}`;

  const headers = new Headers();
  req.headers.forEach((value, key) => {
    if (!STRIP_REQUEST_HEADERS.has(key.toLowerCase())) headers.set(key, value);
  });

  const hasBody = !['GET', 'HEAD'].includes(req.method);
  const upstream = await fetch(upstreamUrl, {
    method: req.method,
    headers,
    body: hasBody ? await req.arrayBuffer() : undefined,
    redirect: 'manual',
  });

  const resHeaders = new Headers();
  upstream.headers.forEach((value, key) => {
    if (!STRIP_RESPONSE_HEADERS.has(key.toLowerCase())) resHeaders.set(key, value);
  });
  for (const cookie of upstream.headers.getSetCookie()) {
    resHeaders.append('set-cookie', cookie);
  }

  return new NextResponse(upstream.body, { status: upstream.status, headers: resHeaders });
}

export {
  proxy as GET,
  proxy as POST,
  proxy as PUT,
  proxy as PATCH,
  proxy as DELETE,
  proxy as OPTIONS,
};
