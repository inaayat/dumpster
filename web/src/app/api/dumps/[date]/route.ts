import { NextResponse } from 'next/server';
import { withAuth } from '@/lib/server/auth';
import { extractTags, isMagicTag } from '@/lib/magic';
import { getOrCreateTag, upsertDump } from '@/lib/server/store';

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

type Ctx = { params: Promise<{ date: string }> };

// Saves a day's dump content. Topic tags found anywhere in the content
// register immediately (the apps' "adding a #tag to any bullet at any
// time registers it" behavior) — magic-tag side effects only happen via
// the explicit /process call on Enter.
export const PUT = withAuth<Ctx>(async (req, user, ctx) => {
  const { date } = await ctx.params;
  if (!DATE_RE.test(date)) {
    return NextResponse.json({ error: 'Date must be yyyy-MM-dd.' }, { status: 400 });
  }
  const body = await req.json();
  if (typeof body.content !== 'string') {
    return NextResponse.json({ error: 'content (string) is required.' }, { status: 400 });
  }
  const dump = await upsertDump(user.id, date, body.content);
  for (const tag of new Set(extractTags(body.content).filter((t) => !isMagicTag(t)))) {
    await getOrCreateTag(user.id, tag);
  }
  return NextResponse.json({ dump });
});
