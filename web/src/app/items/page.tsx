'use client';

// Items view: filter tabs, group-by-tag, high-prio and completed
// toggles, and a "New" section floating recent items to the top.
import { useMemo, useState } from 'react';
import { createItem, useItems, useTags } from '@/lib/client/api';
import ItemCard from '@/components/items/ItemCard';
import ItemEditModal from '@/components/items/ItemEditModal';
import { EmptyState, PrimaryButton, Spinner, inputClass, useToast } from '@/components/ui';
import { PRIORITY_ORDER, type Category, type Item } from '@/lib/types';

type Filter = 'all' | Category;
const FILTERS: { key: Filter; label: string }[] = [
  { key: 'all', label: 'All' },
  { key: 'action', label: 'Actions' },
  { key: 'brainstorm', label: 'Brainstorms' },
  { key: 'resource', label: 'Resources' },
];

const NEW_WINDOW_MS = 24 * 60 * 60 * 1000;

function sortItems(items: Item[]): Item[] {
  return [...items].sort(
    (a, b) =>
      PRIORITY_ORDER[a.priority] - PRIORITY_ORDER[b.priority] ||
      +new Date(b.createdAt) - +new Date(a.createdAt),
  );
}

export default function ItemsPage() {
  const { data, isLoading } = useItems();
  const { data: tagsData } = useTags();
  const toast = useToast();

  const [filter, setFilter] = useState<Filter>('all');
  const [highPrioOnly, setHighPrioOnly] = useState(false);
  const [showCompleted, setShowCompleted] = useState(false);
  const [groupByTag, setGroupByTag] = useState(false);
  const [collapsed, setCollapsed] = useState<Set<string>>(new Set());
  const [editing, setEditing] = useState<Item | null>(null);
  const [quickText, setQuickText] = useState('');

  const tagsById = useMemo(
    () => new Map((tagsData?.tags ?? []).map((t) => [t.id, t])),
    [tagsData],
  );

  const filtered = useMemo(() => {
    let items = data?.items ?? [];
    if (filter !== 'all') items = items.filter((i) => i.category === filter);
    if (highPrioOnly) items = items.filter((i) => i.priority === 'high');
    if (!showCompleted) items = items.filter((i) => !i.done);
    return items;
  }, [data, filter, highPrioOnly, showCompleted]);

  // "New" items float above everything regardless of grouping.
  const now = Date.now();
  const newItems = filtered.filter((i) => !i.done && now - +new Date(i.createdAt) < NEW_WINDOW_MS);
  const rest = filtered.filter((i) => !newItems.includes(i));

  const groups = useMemo(() => {
    if (!groupByTag) return null;
    const byTag = new Map<string, Item[]>();
    const untagged: Item[] = [];
    for (const item of rest) {
      if (!item.tagIds.length) {
        untagged.push(item);
        continue;
      }
      for (const tid of item.tagIds) {
        if (!byTag.has(tid)) byTag.set(tid, []);
        byTag.get(tid)!.push(item);
      }
    }
    const entries = [...byTag.entries()]
      .map(([tid, items]) => ({
        id: tid,
        name: tagsById.get(tid)?.name ?? '?',
        items: sortItems(items),
      }))
      // Stable alphabetical order so completing items doesn't reshuffle.
      .sort((a, b) => a.name.localeCompare(b.name));
    if (untagged.length) entries.push({ id: '__untagged', name: 'untagged', items: sortItems(untagged) });
    return entries;
  }, [groupByTag, rest, tagsById]);

  const quickAdd = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!quickText.trim()) return;
    try {
      await createItem({ text: quickText, category: filter === 'all' ? 'brainstorm' : filter });
      setQuickText('');
    } catch {
      toast('Could not add item', 'error');
    }
  };

  if (isLoading) return <Spinner />;

  const toggleStyle = (on: boolean) =>
    on
      ? { background: 'var(--color-accent)', borderColor: 'var(--color-accent)', color: '#fff' }
      : { borderColor: 'var(--color-edge)', color: 'var(--color-ink-secondary)' };

  return (
    <div className="mx-auto max-w-3xl px-4 py-6 md:px-8">
      <header className="mb-4 flex items-center justify-between">
        <h1 className="text-xl font-bold">Items</h1>
      </header>

      <form onSubmit={quickAdd} className="mb-4 flex gap-2">
        <input
          className={inputClass}
          value={quickText}
          onChange={(e) => setQuickText(e.target.value)}
          placeholder="Quick add… use #tags"
        />
        <PrimaryButton type="submit" disabled={!quickText.trim()}>
          Add
        </PrimaryButton>
      </form>

      <div className="mb-2 flex gap-1.5 overflow-x-auto">
        {FILTERS.map((f) => (
          <button
            key={f.key}
            type="button"
            onClick={() => setFilter(f.key)}
            className="whitespace-nowrap rounded-full border px-3 py-1 text-xs font-semibold"
            style={toggleStyle(filter === f.key)}
          >
            {f.label}
          </button>
        ))}
      </div>
      <div className="mb-4 flex flex-wrap gap-1.5">
        <button
          type="button"
          onClick={() => setHighPrioOnly(!highPrioOnly)}
          className="rounded-full border px-3 py-1 text-xs font-semibold"
          style={toggleStyle(highPrioOnly)}
        >
          High prio
        </button>
        <button
          type="button"
          onClick={() => setShowCompleted(!showCompleted)}
          className="rounded-full border px-3 py-1 text-xs font-semibold"
          style={toggleStyle(showCompleted)}
        >
          Completed
        </button>
        <button
          type="button"
          onClick={() => setGroupByTag(!groupByTag)}
          className="rounded-full border px-3 py-1 text-xs font-semibold"
          style={toggleStyle(groupByTag)}
        >
          Group by tag
        </button>
        {groupByTag && groups && groups.length > 0 && (
          <button
            type="button"
            onClick={() =>
              setCollapsed(collapsed.size ? new Set() : new Set(groups.map((g) => g.id)))
            }
            className="rounded-full border px-3 py-1 text-xs font-semibold"
            style={toggleStyle(false)}
          >
            {collapsed.size ? 'Expand all' : 'Collapse all'}
          </button>
        )}
      </div>

      {newItems.length > 0 && (
        <section className="mb-5">
          <h2 className="mb-2 text-xs font-bold uppercase tracking-wide" style={{ color: 'var(--color-accent)' }}>
            New
          </h2>
          <div className="flex flex-col gap-2">
            {sortItems(newItems).map((item) => (
              <ItemCard key={item.id} item={item} tagsById={tagsById} onEdit={setEditing} />
            ))}
          </div>
        </section>
      )}

      {filtered.length === 0 && (
        <EmptyState title="Nothing here" hint="Dump thoughts with #action or #brainstorm to create items." />
      )}

      {!groupByTag ? (
        <div className="flex flex-col gap-2">
          {sortItems(rest).map((item) => (
            <ItemCard key={item.id} item={item} tagsById={tagsById} onEdit={setEditing} />
          ))}
        </div>
      ) : (
        <div className="flex flex-col gap-4">
          {groups!.map((group) => (
            <section key={group.id}>
              <button
                type="button"
                onClick={() => {
                  const next = new Set(collapsed);
                  if (next.has(group.id)) next.delete(group.id);
                  else next.add(group.id);
                  setCollapsed(next);
                }}
                className="mb-2 flex w-full items-center justify-between text-xs font-bold uppercase tracking-wide"
                style={{ color: 'var(--color-accent)' }}
              >
                #{group.name} ({group.items.length})
                <span>{collapsed.has(group.id) ? '▸' : '▾'}</span>
              </button>
              {!collapsed.has(group.id) && (
                <div className="flex flex-col gap-2">
                  {group.items.map((item) => (
                    <ItemCard key={`${group.id}-${item.id}`} item={item} tagsById={tagsById} onEdit={setEditing} />
                  ))}
                </div>
              )}
            </section>
          ))}
        </div>
      )}

      {editing && <ItemEditModal item={editing} tagsById={tagsById} onClose={() => setEditing(null)} />}
    </div>
  );
}
