'use client';

// Edit sheet for an item. Typing #tags in the title adds tag
// associations (stripped from the stored title), like the apps.
import { useState } from 'react';
import { extractTags } from '@/lib/magic';
import { patchItem, removeItem } from '@/lib/client/api';
import { Modal, PrimaryButton, inputClass, useToast } from '@/components/ui';
import type { Category, Item, Priority, Tag } from '@/lib/types';

const CATEGORIES: Category[] = ['action', 'brainstorm', 'resource'];
const PRIORITIES: Priority[] = ['high', 'medium', 'low', 'backlog'];

interface Props {
  item: Item;
  tagsById: Map<string, Tag>;
  onClose: () => void;
}

export default function ItemEditModal({ item, tagsById, onClose }: Props) {
  const toast = useToast();
  const currentTags = item.tagIds
    .map((tid) => tagsById.get(tid)?.name)
    .filter((n): n is string => !!n);

  const [text, setText] = useState(
    item.text + (currentTags.length ? ' ' + currentTags.map((t) => `#${t}`).join(' ') : ''),
  );
  const [category, setCategory] = useState<Category>(item.category);
  const [priority, setPriority] = useState<Priority>(item.priority);
  const [dueDate, setDueDate] = useState(item.dueDate ? item.dueDate.slice(0, 10) : '');
  const [notes, setNotes] = useState(item.notes ?? '');
  const [url, setUrl] = useState(item.url ?? '');
  const [busy, setBusy] = useState(false);

  const save = async () => {
    setBusy(true);
    try {
      await patchItem(item.id, {
        text,
        category,
        priority,
        dueDate: dueDate ? new Date(dueDate + 'T12:00:00').toISOString() : null,
        notes: notes.trim() || null,
        url: url.trim() || null,
        // Explicit tagNames REPLACES the tag set, so removing a #tag from
        // the text here really detaches it.
        tagNames: extractTags(text),
      });
      onClose();
    } catch {
      toast('Save failed', 'error');
    } finally {
      setBusy(false);
    }
  };

  const del = async () => {
    if (!confirm('Delete this item?')) return;
    await removeItem(item.id);
    onClose();
  };

  return (
    <Modal title="Edit item" onClose={onClose}>
      <div className="flex flex-col gap-3">
        <textarea
          className={`${inputClass} min-h-[70px] resize-y`}
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="Item text — #tags become associations"
        />

        <div className="flex gap-2">
          {CATEGORIES.map((c) => (
            <button
              key={c}
              type="button"
              onClick={() => setCategory(c)}
              className="flex-1 rounded-lg border px-2 py-1.5 text-xs font-semibold capitalize"
              style={
                category === c
                  ? { background: 'var(--color-accent)', borderColor: 'var(--color-accent)', color: '#fff' }
                  : { borderColor: 'var(--color-edge)', color: 'var(--color-ink-secondary)' }
              }
            >
              {c}
            </button>
          ))}
        </div>

        <div className="flex gap-2">
          {PRIORITIES.map((p) => (
            <button
              key={p}
              type="button"
              onClick={() => setPriority(p)}
              className="flex-1 rounded-lg border px-1 py-1.5 text-xs font-semibold capitalize"
              style={
                priority === p
                  ? { background: 'var(--color-warn)', borderColor: 'var(--color-warn)', color: '#fff' }
                  : { borderColor: 'var(--color-edge)', color: 'var(--color-ink-secondary)' }
              }
            >
              {p}
            </button>
          ))}
        </div>

        <label className="text-xs font-semibold" style={{ color: 'var(--color-ink-muted)' }}>
          Due date
          <input
            type="date"
            className={`${inputClass} mt-1`}
            value={dueDate}
            onChange={(e) => setDueDate(e.target.value)}
          />
        </label>

        <input
          className={inputClass}
          value={url}
          onChange={(e) => setUrl(e.target.value)}
          placeholder="URL (resources)"
          inputMode="url"
        />

        <textarea
          className={`${inputClass} min-h-[60px] resize-y`}
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="Notes"
        />

        <div className="mt-1 flex items-center justify-between">
          <button
            type="button"
            onClick={del}
            className="text-xs font-semibold"
            style={{ color: 'var(--color-danger)' }}
          >
            Delete
          </button>
          <PrimaryButton onClick={save} disabled={busy || !text.trim()}>
            {busy ? 'Saving…' : 'Save'}
          </PrimaryButton>
        </div>
      </div>
    </Modal>
  );
}
