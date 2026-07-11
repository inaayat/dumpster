'use client';

// High-priority + overdue items, always visible at the top of the dump
// (macOS's attention bar). Tapping the circle completes the item.
import { useMemo } from 'react';
import { useItems, patchItem } from '@/lib/client/api';
import { useToast } from '@/components/ui';
import type { Item } from '@/lib/types';

function isOverdue(item: Item): boolean {
  if (!item.dueDate || item.done) return false;
  const startOfToday = new Date();
  startOfToday.setHours(0, 0, 0, 0);
  return new Date(item.dueDate) < startOfToday;
}

export default function AttentionBar() {
  const { data } = useItems();
  const toast = useToast();

  const attention = useMemo(() => {
    const items = data?.items ?? [];
    return items.filter((i) => !i.done && (i.priority === 'high' || isOverdue(i)));
  }, [data]);

  if (!attention.length) return null;

  return (
    <div
      className="mb-4 rounded-xl border p-3"
      style={{ borderColor: 'var(--color-warn)', background: '#fdf3e3' }}
    >
      <p
        className="mb-2 text-[11px] font-bold uppercase tracking-wide"
        style={{ color: 'var(--color-warn)' }}
      >
        Needs attention ({attention.length})
      </p>
      <ul className="flex flex-col gap-1.5">
        {attention.map((item) => (
          <li key={item.id} className="flex items-start gap-2 text-sm">
            <button
              type="button"
              aria-label="Complete"
              onClick={async () => {
                await patchItem(item.id, { done: true });
                toast('Completed 🎉', 'success');
              }}
              className="mt-0.5 h-4 w-4 flex-shrink-0 rounded-full border-2"
              style={{ borderColor: 'var(--color-warn)' }}
            />
            <span className="min-w-0 break-words">
              {item.text}
              {isOverdue(item) && (
                <span className="ml-2 text-[11px] font-semibold" style={{ color: 'var(--color-danger)' }}>
                  overdue {new Date(item.dueDate!).toLocaleDateString()}
                </span>
              )}
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}
