import { NextResponse } from 'next/server';
import { withAuth } from '@/lib/server/auth';
import { createDoc, listDocs } from '@/lib/server/store';

export const GET = withAuth(async (_req, user) => {
  const docs = await listDocs(user.id);
  return NextResponse.json({ docs });
});

export const POST = withAuth(async (req, user) => {
  const body = await req.json();
  const title = typeof body.title === 'string' ? body.title.trim() : '';
  const tagNames = Array.isArray(body.tagNames) ? body.tagNames.map(String) : [];
  if (!title) return NextResponse.json({ error: 'title is required.' }, { status: 400 });
  const doc = await createDoc(user.id, title, tagNames, typeof body.content === 'string' ? body.content : '');
  return NextResponse.json({ doc }, { status: 201 });
});
