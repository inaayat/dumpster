import { NextResponse } from 'next/server';
import { withAuth } from '@/lib/server/auth';
import { exportAll, importAll } from '@/lib/server/backup';

// Download a backup in the iOS AppBackup JSON shape.
export const GET = withAuth(async (_req, user) => {
  const backup = await exportAll(user.id);
  return new NextResponse(JSON.stringify(backup, null, 2), {
    headers: {
      'Content-Type': 'application/json',
      'Content-Disposition': `attachment; filename="dumpster-backup-${new Date().toISOString().slice(0, 10)}.json"`,
    },
  });
});

// Import a backup (web or iOS export). REPLACES all existing data, same
// as the iOS restore.
export const POST = withAuth(async (req, user) => {
  const backup = await req.json();
  if (!backup || typeof backup !== 'object') {
    return NextResponse.json({ error: 'Body must be a backup JSON object.' }, { status: 400 });
  }
  const summary = await importAll(user.id, backup);
  return NextResponse.json({ summary });
});
