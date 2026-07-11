'use client';

// Wins — the chronological brag doc (macOS feature). Log directly here
// or via #win in the daily dump.
import { useState } from 'react';
import { createWin, patchWin, removeWin, useWins } from '@/lib/client/api';
import { EmptyState, Modal, PrimaryButton, Spinner, inputClass, useToast } from '@/components/ui';
import type { Win } from '@/lib/types';

export default function WinsPage() {
  const { data, isLoading } = useWins();
  const toast = useToast();
  const [text, setText] = useState('');
  const [artifact, setArtifact] = useState('');
  const [editing, setEditing] = useState<Win | null>(null);

  if (isLoading) return <Spinner />;

  const add = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!text.trim()) return;
    try {
      await createWin(text, artifact || undefined);
      setText('');
      setArtifact('');
      toast('Win logged 🏆', 'success');
    } catch {
      toast('Failed to log win', 'error');
    }
  };

  const byMonth = new Map<string, Win[]>();
  for (const win of data?.wins ?? []) {
    const month = new Date(win.createdAt).toLocaleDateString(undefined, {
      month: 'long',
      year: 'numeric',
    });
    if (!byMonth.has(month)) byMonth.set(month, []);
    byMonth.get(month)!.push(win);
  }

  return (
    <div className="mx-auto max-w-3xl px-4 py-6 md:px-8">
      <header className="mb-4">
        <h1 className="text-xl font-bold">Wins</h1>
        <p className="text-xs" style={{ color: 'var(--color-ink-muted)' }}>
          Your brag doc — also fed by #win in the daily dump
        </p>
      </header>

      <form onSubmit={add} className="mb-6 flex flex-col gap-2 rounded-xl border border-edge bg-card p-3">
        <input
          className={inputClass}
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="What did you crush?"
        />
        <div className="flex gap-2">
          <input
            className={inputClass}
            value={artifact}
            onChange={(e) => setArtifact(e.target.value)}
            placeholder="Artifact URL (optional)"
            inputMode="url"
          />
          <PrimaryButton type="submit" disabled={!text.trim()}>
            Log 🏆
          </PrimaryButton>
        </div>
      </form>

      {byMonth.size === 0 ? (
        <EmptyState title="No wins yet" hint="They add up faster than you think." />
      ) : (
        [...byMonth.entries()].map(([month, wins]) => (
          <section key={month} className="mb-5">
            <h2 className="mb-2 text-xs font-bold uppercase tracking-wide" style={{ color: 'var(--color-win)' }}>
              {month}
            </h2>
            <ul className="flex flex-col gap-2">
              {wins.map((win) => (
                <li key={win.id}>
                  <button
                    type="button"
                    onClick={() => setEditing(win)}
                    className="w-full rounded-xl border bg-card px-3 py-2.5 text-left"
                    style={{ borderColor: 'var(--color-win)' }}
                  >
                    <p className="text-sm">🏆 {win.text}</p>
                    <p className="mt-0.5 text-[11px]" style={{ color: 'var(--color-ink-muted)' }}>
                      {new Date(win.createdAt).toLocaleDateString(undefined, {
                        weekday: 'short',
                        month: 'short',
                        day: 'numeric',
                      })}
                      {win.artifact && (
                        <a
                          href={win.artifact}
                          target="_blank"
                          rel="noreferrer"
                          onClick={(e) => e.stopPropagation()}
                          className="ml-2 underline"
                          style={{ color: 'var(--color-resource)' }}
                        >
                          artifact ↗
                        </a>
                      )}
                    </p>
                  </button>
                </li>
              ))}
            </ul>
          </section>
        ))
      )}

      {editing && (
        <EditWinModal
          win={editing}
          onClose={() => setEditing(null)}
          onError={() => toast('Failed', 'error')}
        />
      )}
    </div>
  );
}

function EditWinModal({
  win,
  onClose,
  onError,
}: {
  win: Win;
  onClose: () => void;
  onError: () => void;
}) {
  const [text, setText] = useState(win.text);
  const [artifact, setArtifact] = useState(win.artifact ?? '');
  const [busy, setBusy] = useState(false);

  return (
    <Modal title="Edit win" onClose={onClose}>
      <div className="flex flex-col gap-3">
        <textarea
          className={`${inputClass} min-h-[70px] resize-y`}
          value={text}
          onChange={(e) => setText(e.target.value)}
        />
        <input
          className={inputClass}
          value={artifact}
          onChange={(e) => setArtifact(e.target.value)}
          placeholder="Artifact URL"
        />
        <div className="flex items-center justify-between">
          <button
            type="button"
            onClick={async () => {
              if (!confirm('Delete this win?')) return;
              await removeWin(win.id);
              onClose();
            }}
            className="text-xs font-semibold"
            style={{ color: 'var(--color-danger)' }}
          >
            Delete
          </button>
          <PrimaryButton
            disabled={busy || !text.trim()}
            onClick={async () => {
              setBusy(true);
              try {
                await patchWin(win.id, { text, artifact: artifact.trim() || null });
                onClose();
              } catch {
                onError();
                setBusy(false);
              }
            }}
          >
            Save
          </PrimaryButton>
        </div>
      </div>
    </Modal>
  );
}
