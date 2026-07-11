'use client';

// Master Doc editor: Doc (markdown edit/preview + outline) · Inbox
// (unincorporated tagged items + dump bullets, add under a heading) ·
// All Items (complete directly). The AI placement of the apps becomes a
// manual heading picker in v1 — the API shape leaves room to add AI.
import Link from 'next/link';
import { use, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  incorporate,
  patchDoc,
  patchItem,
  removeDoc,
  useDoc,
  useTags,
} from '@/lib/client/api';
import MarkdownPreview from '@/components/docs/MarkdownPreview';
import ItemCard from '@/components/items/ItemCard';
import { EmptyState, Modal, PrimaryButton, Spinner, TagPill, inputClass, useToast } from '@/components/ui';

type Tab = 'doc' | 'inbox' | 'items';

export default function DocPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const { data, isLoading } = useDoc(id);
  const { data: tagsData } = useTags();
  const toast = useToast();

  const [tab, setTab] = useState<Tab>('doc');
  const [mode, setMode] = useState<'preview' | 'edit'>('preview');
  const [content, setContent] = useState<string | null>(null);
  const [title, setTitle] = useState<string | null>(null);
  const [editingTags, setEditingTags] = useState(false);
  const saveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (data && content === null) {
      setContent(data.doc.content);
      setTitle(data.doc.title);
    }
  }, [data, content]);

  const scheduleSave = useCallback(
    (patch: { content?: string; title?: string }) => {
      if (saveTimer.current) clearTimeout(saveTimer.current);
      saveTimer.current = setTimeout(() => {
        patchDoc(id, patch).catch(() => toast('Save failed', 'error'));
      }, 800);
    },
    [id, toast],
  );

  const tagsById = useMemo(
    () => new Map((tagsData?.tags ?? []).map((t) => [t.id, t])),
    [tagsData],
  );

  if (isLoading || !data || content === null) return <Spinner />;

  const { headings, inboxItems, inboxBullets, allItems } = data;
  const inboxCount = inboxItems.length + inboxBullets.length;

  const addHeading = () => {
    const name = prompt('New section heading:');
    if (!name?.trim()) return;
    const next = `${content.replace(/\n+$/, '')}${content.trim() ? '\n\n' : ''}## ${name.trim()}\n`;
    setContent(next);
    scheduleSave({ content: next });
  };

  const tabStyle = (t: Tab) =>
    tab === t
      ? { background: 'var(--color-accent)', borderColor: 'var(--color-accent)', color: '#fff' }
      : { borderColor: 'var(--color-edge)', color: 'var(--color-ink-secondary)' };

  return (
    <div className="mx-auto max-w-3xl px-4 py-6 md:px-8">
      <Link href="/docs" className="text-xs font-semibold" style={{ color: 'var(--color-ink-muted)' }}>
        ← docs
      </Link>

      <input
        className="mt-1 mb-1 w-full bg-transparent text-xl font-bold focus:outline-none"
        value={title ?? ''}
        onChange={(e) => {
          setTitle(e.target.value);
          scheduleSave({ title: e.target.value });
        }}
      />

      <button type="button" onClick={() => setEditingTags(true)} className="mb-4 flex flex-wrap gap-1">
        {data.doc.tagIds.length ? (
          data.doc.tagIds.map((tid) => {
            const tag = tagsById.get(tid);
            return tag ? <TagPill key={tid} name={tag.name} small /> : null;
          })
        ) : (
          <span className="text-xs underline" style={{ color: 'var(--color-ink-muted)' }}>
            + add tags
          </span>
        )}
      </button>

      <div className="mb-4 flex gap-1.5">
        <button type="button" onClick={() => setTab('doc')} className="rounded-full border px-3 py-1 text-xs font-semibold" style={tabStyle('doc')}>
          Doc
        </button>
        <button type="button" onClick={() => setTab('inbox')} className="rounded-full border px-3 py-1 text-xs font-semibold" style={tabStyle('inbox')}>
          Inbox{inboxCount > 0 && ` (${inboxCount})`}
        </button>
        <button type="button" onClick={() => setTab('items')} className="rounded-full border px-3 py-1 text-xs font-semibold" style={tabStyle('items')}>
          All Items ({allItems.length})
        </button>
      </div>

      {tab === 'doc' && (
        <>
          <div className="mb-2 flex items-center justify-between">
            <div className="flex gap-1.5">
              <button
                type="button"
                onClick={() => setMode(mode === 'edit' ? 'preview' : 'edit')}
                className="rounded-lg border border-edge px-3 py-1 text-xs font-semibold"
                style={{ color: 'var(--color-ink-secondary)' }}
              >
                {mode === 'edit' ? 'Preview' : 'Edit'}
              </button>
              <button
                type="button"
                onClick={addHeading}
                className="rounded-lg border border-edge px-3 py-1 text-xs font-semibold"
                style={{ color: 'var(--color-ink-secondary)' }}
              >
                + Section
              </button>
            </div>
            <button
              type="button"
              onClick={async () => {
                if (!confirm('Delete this doc? Tags and items are kept.')) return;
                await removeDoc(id);
                window.location.href = '/docs';
              }}
              className="text-xs font-semibold"
              style={{ color: 'var(--color-danger)' }}
            >
              Delete doc
            </button>
          </div>

          {headings.length > 0 && (
            <div className="mb-3 flex flex-wrap gap-1.5">
              {headings.map((h) => (
                <span
                  key={h}
                  className="rounded border border-edge px-2 py-0.5 text-[11px] font-medium"
                  style={{ color: 'var(--color-ink-muted)' }}
                >
                  {h}
                </span>
              ))}
            </div>
          )}

          {mode === 'edit' ? (
            <textarea
              className={`${inputClass} min-h-[50vh] resize-y font-[inherit]`}
              style={{ fontSize: '14px', lineHeight: 1.7 }}
              value={content}
              onChange={(e) => {
                setContent(e.target.value);
                scheduleSave({ content: e.target.value });
              }}
              placeholder={'## Section\n- bullet\n\nMarkdown: ## headings, - bullets, **bold**'}
            />
          ) : (
            <div className="rounded-xl border border-edge bg-card px-4 py-3">
              {content.trim() ? (
                <MarkdownPreview content={content} />
              ) : (
                <EmptyState title="Empty doc" hint="Hit Edit, or add entries from the Inbox." />
              )}
            </div>
          )}
        </>
      )}

      {tab === 'inbox' &&
        (inboxCount === 0 ? (
          <EmptyState
            title="Inbox zero 🎉"
            hint="Tagged items and dump bullets that aren't in the doc yet appear here."
          />
        ) : (
          <div className="flex flex-col gap-2">
            {inboxItems.map((item) => (
              <InboxRow
                key={item.id}
                text={item.text}
                meta={item.category}
                headings={headings}
                onAdd={(heading) => incorporate(id, { itemId: item.id, heading })}
                onDismiss={() => incorporate(id, { itemId: item.id, dismiss: true })}
              />
            ))}
            {inboxBullets.map((b) => (
              <InboxRow
                key={b.text}
                text={b.text}
                meta={b.date}
                headings={headings}
                onAdd={(heading) => incorporate(id, { bulletText: b.text, heading })}
                onDismiss={() => incorporate(id, { bulletText: b.text, dismiss: true })}
              />
            ))}
          </div>
        ))}

      {tab === 'items' &&
        (allItems.length === 0 ? (
          <EmptyState title="No items" hint="Items tagged with this doc's tags appear here." />
        ) : (
          <div className="flex flex-col gap-2">
            {allItems.map((item) => (
              <div key={item.id} className={item.incorporatedIntoDoc ? 'opacity-55' : ''}>
                <ItemCard
                  item={item}
                  tagsById={tagsById}
                  onEdit={async (it) => {
                    // lightweight complete/reopen from the doc view
                    await patchItem(it.id, { done: !it.done });
                  }}
                />
              </div>
            ))}
          </div>
        ))}

      {editingTags && (
        <Modal title="Doc tags" onClose={() => setEditingTags(false)}>
          <DocTagsEditor
            allTags={tagsData?.tags ?? []}
            selected={data.doc.tagIds
              .map((tid) => tagsById.get(tid)?.name)
              .filter((n): n is string => !!n)}
            onSave={async (names) => {
              await patchDoc(id, { tagNames: names });
              setEditingTags(false);
            }}
          />
        </Modal>
      )}
    </div>
  );
}

function InboxRow({
  text,
  meta,
  headings,
  onAdd,
  onDismiss,
}: {
  text: string;
  meta: string;
  headings: string[];
  onAdd: (heading: string | null) => Promise<unknown>;
  onDismiss: () => Promise<unknown>;
}) {
  const [heading, setHeading] = useState<string>('');
  const [busy, setBusy] = useState(false);
  const toast = useToast();

  return (
    <div className="rounded-xl border border-edge bg-card px-3 py-2.5">
      <p className="text-sm">{text}</p>
      <p className="mb-2 text-[11px]" style={{ color: 'var(--color-ink-muted)' }}>
        {meta}
      </p>
      <div className="flex items-center gap-2">
        {headings.length > 0 && (
          <select
            className={`${inputClass} !w-auto flex-1 !py-1 text-xs`}
            value={heading}
            onChange={(e) => setHeading(e.target.value)}
          >
            <option value="">end of doc</option>
            {headings.map((h) => (
              <option key={h} value={h}>
                under “{h}”
              </option>
            ))}
          </select>
        )}
        <button
          type="button"
          disabled={busy}
          onClick={async () => {
            setBusy(true);
            try {
              await onAdd(heading || null);
              toast('Added to doc', 'success');
            } catch {
              toast('Failed', 'error');
              setBusy(false);
            }
          }}
          className="rounded-lg px-3 py-1 text-xs font-semibold text-white"
          style={{ background: 'var(--color-accent)' }}
        >
          + Add
        </button>
        <button
          type="button"
          disabled={busy}
          onClick={async () => {
            setBusy(true);
            try {
              await onDismiss();
            } catch {
              toast('Failed', 'error');
              setBusy(false);
            }
          }}
          className="rounded-lg px-2 py-1 text-xs font-semibold"
          style={{ color: 'var(--color-ink-muted)' }}
        >
          Dismiss
        </button>
      </div>
    </div>
  );
}

function DocTagsEditor({
  allTags,
  selected,
  onSave,
}: {
  allTags: { id: string; name: string }[];
  selected: string[];
  onSave: (names: string[]) => Promise<void>;
}) {
  const [names, setNames] = useState<string[]>(selected);
  const [newTag, setNewTag] = useState('');
  const [busy, setBusy] = useState(false);

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap gap-1.5">
        {allTags.map((t) => (
          <TagPill
            key={t.id}
            name={t.name}
            small
            active={names.includes(t.name)}
            onClick={() =>
              setNames((cur) =>
                cur.includes(t.name) ? cur.filter((n) => n !== t.name) : [...cur, t.name],
              )
            }
          />
        ))}
      </div>
      <div className="flex gap-2">
        <input
          className={inputClass}
          value={newTag}
          onChange={(e) => setNewTag(e.target.value)}
          placeholder="new tag name"
        />
        <PrimaryButton
          onClick={() => {
            const name = newTag.trim().toLowerCase();
            if (name && !names.includes(name)) setNames([...names, name]);
            setNewTag('');
          }}
          disabled={!newTag.trim()}
        >
          Add
        </PrimaryButton>
      </div>
      <PrimaryButton
        onClick={async () => {
          setBusy(true);
          await onSave(names);
        }}
        disabled={busy}
      >
        {busy ? 'Saving…' : 'Save tags'}
      </PrimaryButton>
    </div>
  );
}
