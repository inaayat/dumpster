'use client';

// Master Docs list. Docs own multiple tags (the iOS model); all tagged
// content flows into each doc's inbox.
import Link from 'next/link';
import { useMemo, useState } from 'react';
import { createDoc, useDocs, useTags } from '@/lib/client/api';
import { EmptyState, Modal, PrimaryButton, Spinner, TagPill, inputClass, useToast } from '@/components/ui';

export default function DocsPage() {
  const { data, isLoading } = useDocs();
  const { data: tagsData } = useTags();
  const toast = useToast();
  const [creating, setCreating] = useState(false);
  const [title, setTitle] = useState('');
  const [tagNames, setTagNames] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);

  const tagsById = useMemo(
    () => new Map((tagsData?.tags ?? []).map((t) => [t.id, t])),
    [tagsData],
  );

  if (isLoading) return <Spinner />;

  const create = async () => {
    setBusy(true);
    try {
      const doc = await createDoc(title.trim(), tagNames);
      window.location.href = `/docs/${doc.id}`;
    } catch {
      toast('Could not create doc', 'error');
      setBusy(false);
    }
  };

  return (
    <div className="mx-auto max-w-3xl px-4 py-6 md:px-8">
      <header className="mb-4 flex items-center justify-between">
        <div>
          <h1 className="text-xl font-bold">Master Docs</h1>
          <p className="text-xs" style={{ color: 'var(--color-ink-muted)' }}>
            Persistent knowledge docs fed by your tags
          </p>
        </div>
        <PrimaryButton onClick={() => setCreating(true)}>New doc</PrimaryButton>
      </header>

      {(data?.docs ?? []).length === 0 ? (
        <EmptyState
          title="No docs yet"
          hint="Create one, or use #save with a #tag in your dump to auto-create."
        />
      ) : (
        <div className="flex flex-col gap-2">
          {data!.docs.map((doc) => (
            <Link
              key={doc.id}
              href={`/docs/${doc.id}`}
              className="rounded-xl border border-edge bg-card px-4 py-3"
            >
              <div className="flex items-center justify-between">
                <span className="text-sm font-bold">{doc.title}</span>
                <span className="text-[11px]" style={{ color: 'var(--color-ink-muted)' }}>
                  {new Date(doc.updatedAt).toLocaleDateString()}
                </span>
              </div>
              {doc.tagIds.length > 0 && (
                <div className="mt-1.5 flex flex-wrap gap-1">
                  {doc.tagIds.map((tid) => {
                    const tag = tagsById.get(tid);
                    return tag ? <TagPill key={tid} name={tag.name} small /> : null;
                  })}
                </div>
              )}
            </Link>
          ))}
        </div>
      )}

      {creating && (
        <Modal title="New Master Doc" onClose={() => setCreating(false)}>
          <div className="flex flex-col gap-3">
            <input
              className={inputClass}
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Title"
              autoFocus
            />
            <div>
              <p className="mb-1.5 text-xs font-semibold" style={{ color: 'var(--color-ink-muted)' }}>
                Tags feeding this doc
              </p>
              <div className="flex flex-wrap gap-1.5">
                {(tagsData?.tags ?? []).map((t) => (
                  <TagPill
                    key={t.id}
                    name={t.name}
                    small
                    active={tagNames.includes(t.name)}
                    onClick={() =>
                      setTagNames((cur) =>
                        cur.includes(t.name) ? cur.filter((n) => n !== t.name) : [...cur, t.name],
                      )
                    }
                  />
                ))}
              </div>
            </div>
            <PrimaryButton onClick={create} disabled={busy || !title.trim()}>
              {busy ? 'Creating…' : 'Create'}
            </PrimaryButton>
          </div>
        </Modal>
      )}
    </div>
  );
}
