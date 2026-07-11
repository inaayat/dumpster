'use client';

// Tag detail: linked items with completion circles, dump bullets
// carrying the tag, and the tag's Master Doc.
import Link from 'next/link';
import { use, useMemo, useState } from 'react';
import { createDoc, useDocs, useDumps, useItems, useTags } from '@/lib/client/api';
import ItemCard from '@/components/items/ItemCard';
import ItemEditModal from '@/components/items/ItemEditModal';
import { EmptyState, PrimaryButton, Spinner } from '@/components/ui';
import { parseBullets, stripTags } from '@/lib/magic';
import type { Item } from '@/lib/types';

export default function TagDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const { data: tagsData, isLoading } = useTags();
  const { data: itemsData } = useItems();
  const { data: dumpsData } = useDumps();
  const { data: docsData } = useDocs();
  const [editing, setEditing] = useState<Item | null>(null);
  const [creatingDoc, setCreatingDoc] = useState(false);

  const tag = tagsData?.tags.find((t) => t.id === id);
  const tagsById = useMemo(
    () => new Map((tagsData?.tags ?? []).map((t) => [t.id, t])),
    [tagsData],
  );

  const items = useMemo(
    () => (itemsData?.items ?? []).filter((i) => i.tagIds.includes(id)),
    [itemsData, id],
  );

  const bullets = useMemo(() => {
    if (!tag) return [];
    const out: { text: string; date: string }[] = [];
    const seen = new Set<string>();
    for (const dump of dumpsData?.dumps ?? []) {
      for (const bullet of parseBullets(dump.content)) {
        if (!bullet.tags.includes(tag.name)) continue;
        const clean = stripTags(bullet.text);
        if (!clean || seen.has(clean)) continue;
        seen.add(clean);
        out.push({ text: clean, date: dump.date });
      }
    }
    return out;
  }, [dumpsData, tag]);

  const doc = (docsData?.docs ?? []).find((d) => d.tagIds.includes(id));

  if (isLoading) return <Spinner />;
  if (!tag) return <EmptyState title="Tag not found" />;

  return (
    <div className="mx-auto max-w-3xl px-4 py-6 md:px-8">
      <Link href="/tags" className="text-xs font-semibold" style={{ color: 'var(--color-ink-muted)' }}>
        ← tags
      </Link>
      <header className="mb-5 mt-1 flex items-center justify-between">
        <h1 className="text-xl font-bold" style={{ color: 'var(--color-accent)' }}>
          #{tag.name}
        </h1>
        {doc ? (
          <Link
            href={`/docs/${doc.id}`}
            className="rounded-lg px-3 py-1.5 text-xs font-semibold text-white"
            style={{ background: 'var(--color-accent)' }}
          >
            Open Master Doc →
          </Link>
        ) : (
          <PrimaryButton
            disabled={creatingDoc}
            onClick={async () => {
              setCreatingDoc(true);
              const title = tag.name
                .split('-')
                .map((w) => (w ? w[0].toUpperCase() + w.slice(1) : w))
                .join(' ');
              const newDoc = await createDoc(title, [tag.name]);
              window.location.href = `/docs/${newDoc.id}`;
            }}
          >
            {creatingDoc ? '…' : 'Create Master Doc'}
          </PrimaryButton>
        )}
      </header>

      <section className="mb-6">
        <h2 className="mb-2 text-sm font-bold" style={{ color: 'var(--color-ink-secondary)' }}>
          Items ({items.length})
        </h2>
        {items.length ? (
          <div className="flex flex-col gap-2">
            {items.map((item) => (
              <ItemCard key={item.id} item={item} tagsById={tagsById} onEdit={setEditing} />
            ))}
          </div>
        ) : (
          <p className="text-xs" style={{ color: 'var(--color-ink-muted)' }}>
            No items with this tag.
          </p>
        )}
      </section>

      <section>
        <h2 className="mb-2 text-sm font-bold" style={{ color: 'var(--color-ink-secondary)' }}>
          Dump bullets ({bullets.length})
        </h2>
        {bullets.length ? (
          <ul className="flex flex-col gap-1.5">
            {bullets.map((b, i) => (
              <li key={i} className="rounded-lg border border-edge bg-card px-3 py-2 text-sm">
                {b.text}
                <span className="ml-2 text-[11px]" style={{ color: 'var(--color-ink-muted)' }}>
                  {b.date}
                </span>
              </li>
            ))}
          </ul>
        ) : (
          <p className="text-xs" style={{ color: 'var(--color-ink-muted)' }}>
            No dump bullets mention this tag (last 30 days shown).
          </p>
        )}
      </section>

      {editing && <ItemEditModal item={editing} tagsById={tagsById} onClose={() => setEditing(null)} />}
    </div>
  );
}
