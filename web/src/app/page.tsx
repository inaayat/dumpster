'use client';

// Daily Dump — the home screen. Type freely; every line is a bullet;
// Enter processes the completed line's magic tags server-side.
import { useCallback, useEffect, useRef, useState } from 'react';
import { processDumpLine, saveDump, useDumps, useTags } from '@/lib/client/api';
import AttentionBar from '@/components/dump/AttentionBar';
import DumpEditor, { ColorizedDump } from '@/components/dump/DumpEditor';
import { Spinner, useToast } from '@/components/ui';

function todayStr(): string {
  const d = new Date();
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function displayDate(dateStr: string): string {
  const [y, m, d] = dateStr.split('-').map(Number);
  return new Date(y, m - 1, d).toLocaleDateString(undefined, {
    weekday: 'long',
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

export default function DumpPage() {
  const { data: dumpsData, isLoading } = useDumps();
  const { data: tagsData } = useTags();
  const toast = useToast();

  const today = todayStr();
  const [content, setContent] = useState<string | null>(null);
  const [expandedDay, setExpandedDay] = useState<string | null>(null);
  const saveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const latest = useRef('');

  // Adopt server content once per day-load (local state wins afterwards —
  // it's a single-user editor).
  useEffect(() => {
    if (content === null && dumpsData) {
      const todayDump = dumpsData.dumps.find((d) => d.date === today);
      setContent(todayDump?.content ?? '');
      latest.current = todayDump?.content ?? '';
    }
  }, [dumpsData, content, today]);

  const scheduleSave = useCallback(
    (next: string) => {
      latest.current = next;
      if (saveTimer.current) clearTimeout(saveTimer.current);
      saveTimer.current = setTimeout(() => {
        saveDump(today, latest.current).catch(() => toast('Save failed — check connection', 'error'));
      }, 800);
    },
    [today, toast],
  );

  // Flush pending saves when the tab hides (mobile especially).
  useEffect(() => {
    const flush = () => {
      if (saveTimer.current) {
        clearTimeout(saveTimer.current);
        saveTimer.current = null;
        saveDump(today, latest.current).catch(() => {});
      }
    };
    document.addEventListener('visibilitychange', flush);
    return () => {
      document.removeEventListener('visibilitychange', flush);
      flush();
    };
  }, [today]);

  const onLineCompleted = useCallback(
    async (line: string) => {
      try {
        const result = await processDumpLine(today, line);
        for (const item of result.createdItems) {
          toast(`Added ${item.category}${item.priority === 'high' ? ' (high prio)' : ''}: ${item.text}`, 'success');
        }
        if (result.createdWin) toast(`Win logged 🏆 ${result.createdWin}`, 'success');
        for (const title of result.savedToDocs) toast(`Saved to “${title}”`, 'success');
        if (result.deletedItems) toast(`Deleted ${result.deletedItems} item(s)`, 'info');
      } catch {
        toast('Processing failed', 'error');
      }
    },
    [today, toast],
  );

  if (isLoading || content === null) return <Spinner />;

  const pastDays = (dumpsData?.dumps ?? []).filter((d) => d.date !== today && d.content.trim());
  const knownTags = (tagsData?.tags ?? []).map((t) => t.name);

  return (
    <div className="mx-auto max-w-3xl px-4 py-6 md:px-8">
      <header className="mb-4">
        <h1 className="text-xl font-bold">Daily Dump</h1>
        <p className="text-xs" style={{ color: 'var(--color-ink-muted)' }}>
          {displayDate(today)} · #action #prio #brainstorm #resource #win #save #delete
        </p>
      </header>

      <AttentionBar />

      <DumpEditor
        value={content}
        onChange={(next) => {
          setContent(next);
          scheduleSave(next);
        }}
        onLineCompleted={onLineCompleted}
        knownTags={knownTags}
      />

      {pastDays.length > 0 && (
        <section className="mt-10">
          <h2 className="mb-3 text-sm font-bold" style={{ color: 'var(--color-ink-secondary)' }}>
            Past days
          </h2>
          <ul className="flex flex-col gap-2">
            {pastDays.map((d) => (
              <li key={d.id} className="rounded-xl border border-edge bg-card">
                <button
                  type="button"
                  onClick={() => setExpandedDay(expandedDay === d.date ? null : d.date)}
                  className="flex w-full items-center justify-between px-4 py-3 text-left text-sm font-medium"
                >
                  {displayDate(d.date)}
                  <span style={{ color: 'var(--color-ink-muted)' }}>
                    {expandedDay === d.date ? '▾' : '▸'}
                  </span>
                </button>
                {expandedDay === d.date && (
                  <div
                    className="border-t border-edge px-4 py-3 text-sm"
                    style={{ whiteSpace: 'pre-wrap', overflowWrap: 'break-word', lineHeight: 1.7 }}
                  >
                    <ColorizedDump text={d.content} />
                  </div>
                )}
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  );
}
