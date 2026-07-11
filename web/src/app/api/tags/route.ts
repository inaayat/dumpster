import { NextResponse } from 'next/server';
import { withAuth } from '@/lib/server/auth';
import { getOrCreateTag, listTagRelationships, listTags } from '@/lib/server/store';

export const GET = withAuth(async (_req, user) => {
  const [tags, relationships] = await Promise.all([
    listTags(user.id),
    listTagRelationships(user.id),
  ]);
  return NextResponse.json({ tags, relationships });
});

export const POST = withAuth(async (req, user) => {
  const body = await req.json();
  const name = typeof body.name === 'string' ? body.name.trim() : '';
  if (!name) return NextResponse.json({ error: 'name is required.' }, { status: 400 });
  const tag = await getOrCreateTag(user.id, name);
  return NextResponse.json({ tag }, { status: 201 });
});
