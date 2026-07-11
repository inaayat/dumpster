// Export/import in the iOS app's AppBackup JSON shape (BackupService.swift),
// so an iOS "Backup & Restore" export drops straight into the web app and a
// web export can go back the other way. Unknown fields are ignored on both
// sides (Swift's JSONDecoder skips unknown keys), which lets the web add
// `wins` to exports without breaking iOS imports.
import { randomUUID } from 'node:crypto';
import { db, ensureSchema } from './db';
import { rtfToPlainText } from '../markdown';

type Json = Record<string, unknown>;

const str = (v: unknown, fallback = ''): string => (typeof v === 'string' ? v : fallback);
const opt = (v: unknown): string | null => (typeof v === 'string' && v !== '' ? v : null);
const bool = (v: unknown): boolean => v === true;
const date = (v: unknown): string => {
  const d = typeof v === 'string' ? new Date(v) : null;
  return d && !isNaN(d.getTime()) ? d.toISOString() : new Date().toISOString();
};

export async function exportAll(userId: string): Promise<Json> {
  await ensureSchema();
  const sql = db();
  const [items, tags, itemTags, dumps, docs, docTags, rels, hidden, wins] = await Promise.all([
    sql`SELECT * FROM dumpster_items WHERE user_id = ${userId}`,
    sql`SELECT * FROM dumpster_tags WHERE user_id = ${userId}`,
    sql`SELECT * FROM dumpster_item_tags WHERE user_id = ${userId}`,
    sql`SELECT * FROM dumpster_daily_dumps WHERE user_id = ${userId}`,
    sql`SELECT * FROM dumpster_master_docs WHERE user_id = ${userId}`,
    sql`SELECT * FROM dumpster_master_doc_tags WHERE user_id = ${userId}`,
    sql`SELECT * FROM dumpster_tag_relationships WHERE user_id = ${userId}`,
    sql`SELECT * FROM dumpster_hidden_bullets WHERE user_id = ${userId}`,
    sql`SELECT * FROM dumpster_wins WHERE user_id = ${userId}`,
  ] as const);

  const firstDocTag = new Map<string, string>();
  for (const r of docTags as Json[]) {
    const docId = String(r.doc_id);
    if (!firstDocTag.has(docId)) firstDocTag.set(docId, String(r.tag_id));
  }

  return {
    exportDate: new Date().toISOString(),
    items: (items as Json[]).map((r) => ({
      id: r.id,
      text: r.text,
      category: r.category,
      priority: r.priority,
      done: r.done,
      doneAt: r.done_at ? date(r.done_at) : undefined,
      dueDate: r.due_date ? date(r.due_date) : undefined,
      url: r.url ?? undefined,
      urlTitle: r.url_title ?? undefined,
      notes: r.notes ?? undefined,
      incorporatedIntoDoc: r.incorporated_into_doc,
      dismissedFromDoc: r.dismissed_from_doc,
      createdAt: date(r.created_at),
    })),
    tags: (tags as Json[]).map((r) => ({ id: r.id, name: r.name, createdAt: date(r.created_at) })),
    itemTags: (itemTags as Json[]).map((r) => ({ itemId: r.item_id, tagId: r.tag_id })),
    dailyDumps: (dumps as Json[]).map((r) => ({
      id: r.id,
      date: r.date,
      content: r.content,
      createdAt: date(r.created_at),
      updatedAt: date(r.updated_at),
    })),
    // iOS's MasterDoc still requires a legacy single tagId; hand it the
    // doc's first tag so round-trips decode.
    masterDocs: (docs as Json[]).map((r) => ({
      id: r.id,
      tagId: firstDocTag.get(String(r.id)) ?? '',
      title: r.title,
      content: r.content,
      createdAt: date(r.created_at),
      updatedAt: date(r.updated_at),
    })),
    masterDocTags: (docTags as Json[]).map((r) => ({ docId: r.doc_id, tagId: r.tag_id })),
    itemLinks: [],
    tagRelationships: (rels as Json[]).map((r) => ({
      id: r.id,
      parentTagId: r.parent_tag_id,
      childTagId: r.child_tag_id,
      createdAt: date(r.created_at),
    })),
    hiddenBullets: (hidden as Json[]).map((r) => ({
      id: r.id,
      bulletText: r.bullet_text,
      createdAt: date(r.created_at),
    })),
    // Web/macOS extra — ignored by the iOS importer.
    wins: (wins as Json[]).map((r) => ({
      id: r.id,
      text: r.text,
      artifact: r.artifact ?? undefined,
      createdAt: date(r.created_at),
    })),
  };
}

export interface ImportSummary {
  items: number;
  tags: number;
  dailyDumps: number;
  masterDocs: number;
  wins: number;
}

// Replaces ALL of the user's dumpster data with the backup's contents,
// mirroring BackupService.importAll's wipe-then-insert.
export async function importAll(userId: string, backup: Json): Promise<ImportSummary> {
  await ensureSchema();
  const sql = db();

  const items = Array.isArray(backup.items) ? (backup.items as Json[]) : [];
  const tags = Array.isArray(backup.tags) ? (backup.tags as Json[]) : [];
  const itemTags = Array.isArray(backup.itemTags) ? (backup.itemTags as Json[]) : [];
  const dumps = Array.isArray(backup.dailyDumps) ? (backup.dailyDumps as Json[]) : [];
  const docs = Array.isArray(backup.masterDocs) ? (backup.masterDocs as Json[]) : [];
  const docTags = Array.isArray(backup.masterDocTags) ? (backup.masterDocTags as Json[]) : [];
  const rels = Array.isArray(backup.tagRelationships) ? (backup.tagRelationships as Json[]) : [];
  const hidden = Array.isArray(backup.hiddenBullets) ? (backup.hiddenBullets as Json[]) : [];
  const wins = Array.isArray(backup.wins) ? (backup.wins as Json[]) : [];

  if (!tags.length && !items.length && !dumps.length && !docs.length) {
    throw new Error('This file does not look like a Dumpster backup.');
  }

  // Wipe (join tables cascade from their parents).
  await sql`DELETE FROM dumpster_items WHERE user_id = ${userId}`;
  await sql`DELETE FROM dumpster_master_docs WHERE user_id = ${userId}`;
  await sql`DELETE FROM dumpster_tags WHERE user_id = ${userId}`;
  await sql`DELETE FROM dumpster_daily_dumps WHERE user_id = ${userId}`;
  await sql`DELETE FROM dumpster_hidden_bullets WHERE user_id = ${userId}`;
  await sql`DELETE FROM dumpster_wins WHERE user_id = ${userId}`;

  const tagIds = new Set<string>();
  for (const t of tags) {
    const id = str(t.id, randomUUID());
    tagIds.add(id);
    await sql`
      INSERT INTO dumpster_tags (id, user_id, name, created_at)
      VALUES (${id}, ${userId}, ${str(t.name).toLowerCase()}, ${date(t.createdAt)})
      ON CONFLICT (user_id, name) DO NOTHING`;
  }

  const itemIds = new Set<string>();
  for (const it of items) {
    const id = str(it.id, randomUUID());
    itemIds.add(id);
    await sql`
      INSERT INTO dumpster_items
        (id, user_id, text, category, priority, done, done_at, due_date, url, url_title,
         notes, incorporated_into_doc, dismissed_from_doc, created_at)
      VALUES
        (${id}, ${userId}, ${str(it.text)}, ${str(it.category, 'brainstorm')},
         ${str(it.priority, 'medium')}, ${bool(it.done)},
         ${it.doneAt ? date(it.doneAt) : null}, ${it.dueDate ? date(it.dueDate) : null},
         ${opt(it.url)}, ${opt(it.urlTitle)}, ${opt(it.notes)},
         ${bool(it.incorporatedIntoDoc)}, ${bool(it.dismissedFromDoc)}, ${date(it.createdAt)})
      ON CONFLICT (id) DO NOTHING`;
  }

  for (const link of itemTags) {
    const itemId = str(link.itemId);
    const tagId = str(link.tagId);
    if (!itemIds.has(itemId) || !tagIds.has(tagId)) continue;
    await sql`
      INSERT INTO dumpster_item_tags (user_id, item_id, tag_id)
      VALUES (${userId}, ${itemId}, ${tagId})
      ON CONFLICT DO NOTHING`;
  }

  for (const d of dumps) {
    await sql`
      INSERT INTO dumpster_daily_dumps (id, user_id, date, content, created_at, updated_at)
      VALUES (${str(d.id, randomUUID())}, ${userId}, ${str(d.date)}, ${str(d.content)},
              ${date(d.createdAt)}, ${date(d.updatedAt)})
      ON CONFLICT (user_id, date) DO UPDATE SET content = EXCLUDED.content, updated_at = EXCLUDED.updated_at`;
  }

  const docIds = new Set<string>();
  for (const doc of docs) {
    const id = str(doc.id, randomUUID());
    docIds.add(id);
    await sql`
      INSERT INTO dumpster_master_docs (id, user_id, title, content, created_at, updated_at)
      VALUES (${id}, ${userId}, ${str(doc.title, 'Untitled')}, ${rtfToPlainText(str(doc.content))},
              ${date(doc.createdAt)}, ${date(doc.updatedAt)})
      ON CONFLICT (id) DO NOTHING`;
  }

  // Newer backups carry masterDocTags; older ones only have the legacy
  // per-doc tagId. Use whichever is present.
  const links = docTags.length
    ? docTags.map((l) => ({ docId: str(l.docId), tagId: str(l.tagId) }))
    : docs.map((doc) => ({ docId: str(doc.id), tagId: str(doc.tagId) }));
  for (const link of links) {
    if (!docIds.has(link.docId) || !tagIds.has(link.tagId)) continue;
    await sql`
      INSERT INTO dumpster_master_doc_tags (user_id, doc_id, tag_id)
      VALUES (${userId}, ${link.docId}, ${link.tagId})
      ON CONFLICT DO NOTHING`;
  }

  for (const r of rels) {
    const parent = str(r.parentTagId);
    const child = str(r.childTagId);
    if (!tagIds.has(parent) || !tagIds.has(child)) continue;
    await sql`
      INSERT INTO dumpster_tag_relationships (id, user_id, parent_tag_id, child_tag_id, created_at)
      VALUES (${str(r.id, randomUUID())}, ${userId}, ${parent}, ${child}, ${date(r.createdAt)})
      ON CONFLICT DO NOTHING`;
  }

  for (const h of hidden) {
    await sql`
      INSERT INTO dumpster_hidden_bullets (id, user_id, bullet_text, created_at)
      VALUES (${str(h.id, randomUUID())}, ${userId}, ${str(h.bulletText)}, ${date(h.createdAt)})
      ON CONFLICT DO NOTHING`;
  }

  for (const w of wins) {
    await sql`
      INSERT INTO dumpster_wins (id, user_id, text, artifact, created_at)
      VALUES (${str(w.id, randomUUID())}, ${userId}, ${str(w.text)}, ${opt(w.artifact)}, ${date(w.createdAt)})
      ON CONFLICT DO NOTHING`;
  }

  return {
    items: items.length,
    tags: tags.length,
    dailyDumps: dumps.length,
    masterDocs: docs.length,
    wins: wins.length,
  };
}
