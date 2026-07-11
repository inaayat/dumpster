'use client';

// Tags: the primary organizational unit. Hierarchical list with rename
// (merge on collision), merge, sub-tag creation, and delete — the apps'
// drag interactions become an explicit action menu, which works on touch.
import Link from 'next/link';
import { useMemo, useState } from 'react';
import {
  addSubTag,
  deleteTag,
  mergeTags,
  removeSubTag,
  renameTag,
  useItems,
  useTags,
} from '@/lib/client/api';
import { EmptyState, Modal, PrimaryButton, Spinner, inputClass, useToast } from '@/components/ui';
import type { Tag } from '@/lib/types';

export default function TagsPage() {
  const { data, isLoading } = useTags();
  const { data: itemsData } = useItems();
  const toast = useToast();

  const [search, setSearch] = useState('');
  const [managing, setManaging] = useState<Tag | null>(null);

  const { roots, childrenOf, parentOf } = useMemo(() => {
    const tags = data?.tags ?? [];
    const rels = data?.relationships ?? [];
    const childrenOf = new Map<string, Tag[]>();
    const parentOf = new Map<string, string>();
    const byId = new Map(tags.map((t) => [t.id, t]));
    for (const rel of rels) {
      const child = byId.get(rel.childTagId);
      if (!child) continue;
      parentOf.set(rel.childTagId, rel.parentTagId);
      if (!childrenOf.has(rel.parentTagId)) childrenOf.set(rel.parentTagId, []);
      childrenOf.get(rel.parentTagId)!.push(child);
    }
    const roots = tags.filter((t) => !parentOf.has(t.id));
    return { roots, childrenOf, parentOf };
  }, [data]);

  const itemCount = useMemo(() => {
    const counts = new Map<string, number>();
    for (const item of itemsData?.items ?? []) {
      if (item.done) continue;
      for (const tid of item.tagIds) counts.set(tid, (counts.get(tid) ?? 0) + 1);
    }
    return counts;
  }, [itemsData]);

  if (isLoading) return <Spinner />;

  const matches = (t: Tag) => !search || t.name.includes(search.toLowerCase());
  const visibleRoots = roots.filter(
    (t) => matches(t) || (childrenOf.get(t.id) ?? []).some(matches),
  );

  const TagRow = ({ tag, depth }: { tag: Tag; depth: number }) => (
    <>
      <div
        className="flex items-center justify-between rounded-lg border border-edge bg-card px-3 py-2"
        style={{ marginLeft: depth * 20 }}
      >
        <Link href={`/tags/${tag.id}`} className="flex min-w-0 items-center gap-2">
          <span className="truncate text-sm font-semibold" style={{ color: 'var(--color-accent)' }}>
            {depth > 0 && '↳ '}#{tag.name}
          </span>
          {(itemCount.get(tag.id) ?? 0) > 0 && (
            <span
              className="rounded-full px-1.5 text-[11px] font-bold"
              style={{ background: 'var(--color-accent-tint)', color: 'var(--color-accent)' }}
            >
              {itemCount.get(tag.id)}
            </span>
          )}
        </Link>
        <button
          type="button"
          aria-label="Tag actions"
          onClick={() => setManaging(tag)}
          className="px-2 text-lg leading-none"
          style={{ color: 'var(--color-ink-muted)' }}
        >
          ⋯
        </button>
      </div>
      {(childrenOf.get(tag.id) ?? []).filter(matches).map((child) => (
        <TagRow key={child.id} tag={child} depth={depth + 1} />
      ))}
    </>
  );

  return (
    <div className="mx-auto max-w-3xl px-4 py-6 md:px-8">
      <header className="mb-4">
        <h1 className="text-xl font-bold">Tags</h1>
        <p className="text-xs" style={{ color: 'var(--color-ink-muted)' }}>
          Created automatically from #hashtags in your dumps
        </p>
      </header>

      <input
        className={`${inputClass} mb-4`}
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder="Search tags…"
      />

      {visibleRoots.length === 0 ? (
        <EmptyState title="No tags yet" hint="Type #anything in your daily dump." />
      ) : (
        <div className="flex flex-col gap-1.5">
          {visibleRoots.map((tag) => (
            <TagRow key={tag.id} tag={tag} depth={0} />
          ))}
        </div>
      )}

      {managing && (
        <ManageTagModal
          tag={managing}
          allTags={data?.tags ?? []}
          parentId={parentOf.get(managing.id) ?? null}
          onClose={() => setManaging(null)}
          onError={(m) => toast(m, 'error')}
        />
      )}
    </div>
  );
}

function ManageTagModal({
  tag,
  allTags,
  parentId,
  onClose,
  onError,
}: {
  tag: Tag;
  allTags: Tag[];
  parentId: string | null;
  onClose: () => void;
  onError: (message: string) => void;
}) {
  const [name, setName] = useState(tag.name);
  const [target, setTarget] = useState('');
  const [parent, setParent] = useState(parentId ?? '');
  const others = allTags.filter((t) => t.id !== tag.id);

  const run = async (fn: () => Promise<unknown>) => {
    try {
      await fn();
      onClose();
    } catch (err) {
      onError(err instanceof Error ? err.message : 'Failed');
    }
  };

  return (
    <Modal title={`#${tag.name}`} onClose={onClose}>
      <div className="flex flex-col gap-5">
        <div>
          <p className="mb-1 text-xs font-semibold" style={{ color: 'var(--color-ink-muted)' }}>
            Rename (renaming to an existing tag merges them)
          </p>
          <div className="flex gap-2">
            <input className={inputClass} value={name} onChange={(e) => setName(e.target.value)} />
            <PrimaryButton
              onClick={() => run(() => renameTag(tag.id, name))}
              disabled={!name.trim() || name.trim().toLowerCase() === tag.name}
            >
              Rename
            </PrimaryButton>
          </div>
        </div>

        {others.length > 0 && (
          <div>
            <p className="mb-1 text-xs font-semibold" style={{ color: 'var(--color-ink-muted)' }}>
              Merge into another tag (this tag disappears)
            </p>
            <div className="flex gap-2">
              <select className={inputClass} value={target} onChange={(e) => setTarget(e.target.value)}>
                <option value="">choose tag…</option>
                {others.map((t) => (
                  <option key={t.id} value={t.id}>
                    #{t.name}
                  </option>
                ))}
              </select>
              <PrimaryButton onClick={() => run(() => mergeTags(tag.id, target))} disabled={!target}>
                Merge
              </PrimaryButton>
            </div>
          </div>
        )}

        {others.length > 0 && (
          <div>
            <p className="mb-1 text-xs font-semibold" style={{ color: 'var(--color-ink-muted)' }}>
              Parent tag (makes this a sub-tag)
            </p>
            <div className="flex gap-2">
              <select className={inputClass} value={parent} onChange={(e) => setParent(e.target.value)}>
                <option value="">none</option>
                {others.map((t) => (
                  <option key={t.id} value={t.id}>
                    #{t.name}
                  </option>
                ))}
              </select>
              <PrimaryButton
                onClick={() =>
                  run(async () => {
                    if (parentId) await removeSubTag(parentId, tag.id);
                    if (parent) await addSubTag(parent, tag.id);
                  })
                }
                disabled={parent === (parentId ?? '')}
              >
                Set
              </PrimaryButton>
            </div>
          </div>
        )}

        <button
          type="button"
          onClick={() => {
            if (confirm(`Delete #${tag.name}? Items keep existing but lose this tag.`)) {
              run(() => deleteTag(tag.id));
            }
          }}
          className="self-start text-xs font-semibold"
          style={{ color: 'var(--color-danger)' }}
        >
          Delete tag
        </button>
      </div>
    </Modal>
  );
}
