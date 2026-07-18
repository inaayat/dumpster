'use client';

// Settings: account, backup export/import (iOS-compatible JSON), sign
// out, install hint.
import { useEffect, useRef, useState } from 'react';
import { api, downloadBackup, importBackup } from '@/lib/client/api';
import { useAuth } from '@/lib/client/auth';
import { PrimaryButton, useToast } from '@/components/ui';

export default function SettingsPage() {
  const { user, signOut } = useAuth();
  const toast = useToast();
  const fileRef = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);

  // Keeps the shared users table fresh (same sync point as inaayat.xyz).
  useEffect(() => {
    api('/api/me').catch(() => {});
  }, []);

  const onImportFile = async (file: File) => {
    setBusy(true);
    try {
      const parsed = JSON.parse(await file.text());
      const counts = Object.entries(parsed)
        .filter(([, v]) => Array.isArray(v))
        .map(([k, v]) => `${(v as unknown[]).length} ${k}`)
        .join(', ');
      if (
        !confirm(
          `Import this backup? It REPLACES everything currently in the web app.\n\nContains: ${counts}`,
        )
      ) {
        setBusy(false);
        return;
      }
      const summary = await importBackup(parsed);
      toast(
        `Imported ${summary.items} items, ${summary.tags} tags, ${summary.masterDocs} docs, ${summary.dailyDumps} dumps`,
        'success',
      );
    } catch (err) {
      toast(err instanceof Error ? err.message : 'Import failed', 'error');
    } finally {
      setBusy(false);
      if (fileRef.current) fileRef.current.value = '';
    }
  };

  return (
    <div className="mx-auto max-w-3xl px-4 py-6 md:px-8">
      <h1 className="mb-5 text-xl font-bold">Settings</h1>

      <section className="mb-5 rounded-xl border border-edge bg-card p-4">
        <h2 className="mb-2 text-sm font-bold">Account</h2>
        <p className="text-sm">{user?.name || '—'}</p>
        <p className="text-xs" style={{ color: 'var(--color-ink-muted)' }}>
          {user?.email}
        </p>
        <p className="mt-1 text-[11px]" style={{ color: 'var(--color-ink-muted)' }}>
          Same account as inaayat.xyz (Neon Auth)
        </p>
        <button
          type="button"
          onClick={signOut}
          className="mt-3 rounded-lg border border-edge px-3 py-1.5 text-xs font-semibold"
          style={{ color: 'var(--color-danger)' }}
        >
          Log out
        </button>
      </section>

      <section className="mb-5 rounded-xl border border-edge bg-card p-4">
        <h2 className="mb-1 text-sm font-bold">Backup</h2>
        <p className="mb-3 text-xs" style={{ color: 'var(--color-ink-muted)' }}>
          Same JSON format as the iOS app&apos;s Backup &amp; Restore — export there, import
          here (and back).
        </p>
        <div className="flex gap-2">
          <PrimaryButton
            disabled={busy}
            onClick={() => downloadBackup().catch(() => toast('Export failed', 'error'))}
          >
            Export JSON
          </PrimaryButton>
          <button
            type="button"
            disabled={busy}
            onClick={() => fileRef.current?.click()}
            className="rounded-lg border border-edge px-4 py-2 text-sm font-semibold"
            style={{ color: 'var(--color-ink-secondary)' }}
          >
            {busy ? 'Importing…' : 'Import JSON'}
          </button>
          <input
            ref={fileRef}
            type="file"
            accept="application/json,.json"
            className="hidden"
            onChange={(e) => e.target.files?.[0] && onImportFile(e.target.files[0])}
          />
        </div>
      </section>

      <section className="rounded-xl border border-edge bg-card p-4">
        <h2 className="mb-1 text-sm font-bold">Install as app</h2>
        <p className="text-xs" style={{ color: 'var(--color-ink-muted)' }}>
          On iPhone: Share → “Add to Home Screen”. On desktop Chrome: install icon in the
          address bar. Dumpster runs standalone, full screen.
        </p>
      </section>

      <p className="mt-6 text-center text-[11px]" style={{ color: 'var(--color-ink-muted)' }}>
        Dumpster web · rebuilt from the macOS + iOS apps · magic tags: #action #prio
        #brainstorm #resource #win #save #delete #backlog
      </p>
    </div>
  );
}
