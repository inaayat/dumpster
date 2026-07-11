'use client';

import { patchItem } from '@/lib/client/api';
import { CategoryBadge, PriorityBadge, useToast } from '@/components/ui';
import type { Item, Tag } from '@/lib/types';

interface Props {
  item: Item;
  tagsById: Map<string, Tag>;
  onEdit: (item: Item) => void;
}

export default function ItemCard({ item, tagsById, onEdit }: Props) {
  const toast = useToast();

  const toggleDone = async () => {
    await patchItem(item.id, { done: !item.done });
    if (!item.done) toast('Completed 🎉', 'success');
  };

  const overdue =
    item.dueDate && !item.done && new Date(item.dueDate) < new Date(new Date().setHours(0, 0, 0, 0));

  return (
    <div className="flex items-start gap-3 rounded-xl border border-edge bg-card px-3 py-2.5">
      <button
        type="button"
        aria-label={item.done ? 'Reopen' : 'Complete'}
        onClick={toggleDone}
        className="mt-1 h-[18px] w-[18px] flex-shrink-0 rounded-full border-2"
        style={{
          borderColor: item.done ? 'var(--color-brainstorm)' : 'var(--color-ink-muted)',
          background: item.done ? 'var(--color-brainstorm)' : 'transparent',
        }}
      >
        {item.done && <span className="block text-[11px] leading-none text-white">✓</span>}
      </button>

      <button type="button" className="min-w-0 flex-1 text-left" onClick={() => onEdit(item)}>
        <p
          className={`text-sm ${item.done ? 'line-through' : ''}`}
          style={{ color: item.done ? 'var(--color-ink-muted)' : 'var(--color-ink)' }}
        >
          {item.text}
        </p>
        <div className="mt-1 flex flex-wrap items-center gap-1.5">
          <CategoryBadge category={item.category} />
          <PriorityBadge priority={item.priority} />
          {item.dueDate && (
            <span
              className="text-[11px] font-medium"
              style={{ color: overdue ? 'var(--color-danger)' : 'var(--color-ink-muted)' }}
            >
              📅 {new Date(item.dueDate).toLocaleDateString()}
            </span>
          )}
          {item.url && (
            <a
              href={item.url}
              target="_blank"
              rel="noreferrer"
              onClick={(e) => e.stopPropagation()}
              className="text-[11px] font-medium underline"
              style={{ color: 'var(--color-resource)' }}
            >
              link ↗
            </a>
          )}
          {item.tagIds.map((tid) => {
            const tag = tagsById.get(tid);
            return tag ? (
              <span key={tid} className="text-[11px] font-medium" style={{ color: 'var(--color-accent)' }}>
                #{tag.name}
              </span>
            ) : null;
          })}
        </div>
      </button>
    </div>
  );
}
