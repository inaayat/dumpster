// All database reads/writes, scoped by user id. This is the web
// counterpart of Queries.swift in the Swift apps: route handlers stay
// thin and call into here, so future features (or an AI layer) reuse the
// same primitives.
import { randomUUID } from 'node:crypto';
import { db, ensureSchema } from './db';
import { stripTags } from '../magic';
import type {
  Category,
  DailyDump,
  Item,
  MasterDoc,
  Priority,
  Tag,
  TagRelationship,
  Win,
} from '../types';

type Row = Record<string, unknown>;

const s = (v: unknown) => (v == null ? null : String(v));
const iso = (v: unknown) => (v == null ? null : new Date(v as string).toISOString());

function rowToItem(r: Row, tagIds: string[] = []): Item {
  return {
    id: String(r.id),
    text: String(r.text),
    category: String(r.category) as Category,
    priority: String(r.priority) as Priority,
    done: Boolean(r.done),
    doneAt: iso(r.done_at),
    dueDate: iso(r.due_date),
    url: s(r.url),
    urlTitle: s(r.url_title),
    notes: s(r.notes),
    incorporatedIntoDoc: Boolean(r.incorporated_into_doc),
    dismissedFromDoc: Boolean(r.dismissed_from_doc),
    createdAt: iso(r.created_at)!,
    tagIds,
  };
}

const rowToTag = (r: Row): Tag => ({
  id: String(r.id),
  name: String(r.name),
  createdAt: iso(r.created_at)!,
});

const rowToDump = (r: Row): DailyDump => ({
  id: String(r.id),
  date: String(r.date),
  content: String(r.content),
  updatedAt: iso(r.updated_at)!,
});

const rowToWin = (r: Row): Win => ({
  id: String(r.id),
  text: String(r.text),
  artifact: s(r.artifact),
  createdAt: iso(r.created_at)!,
});

function rowToDoc(r: Row, tagIds: string[] = []): MasterDoc {
  return {
    id: String(r.id),
    title: String(r.title),
    content: String(r.content),
    createdAt: iso(r.created_at)!,
    updatedAt: iso(r.updated_at)!,
    tagIds,
  };
}

export const normalizeTagName = (name: string) => name.trim().toLowerCase();

// Escape a tag name for use inside a RegExp when rewriting `#tag`
// occurrences in dump/doc text (tag names may contain '-').
const tagPattern = (name: string) =>
  new RegExp(`#${name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(?![\\w-])`, 'g');

// ---------------------------------------------------------------- tags

export async function listTags(userId: string): Promise<Tag[]> {
  await ensureSchema();
  const rows = await db()`
    SELECT * FROM dumpster_tags WHERE user_id = ${userId} ORDER BY name`;
  return (rows as Row[]).map(rowToTag);
}

export async function listTagRelationships(userId: string): Promise<TagRelationship[]> {
  await ensureSchema();
  const rows = await db()`
    SELECT * FROM dumpster_tag_relationships WHERE user_id = ${userId}`;
  return (rows as Row[]).map((r) => ({
    id: String(r.id),
    parentTagId: String(r.parent_tag_id),
    childTagId: String(r.child_tag_id),
  }));
}

export async function getOrCreateTag(userId: string, rawName: string): Promise<Tag> {
  await ensureSchema();
  const name = normalizeTagName(rawName);
  const rows = await db()`
    INSERT INTO dumpster_tags (id, user_id, name)
    VALUES (${randomUUID()}, ${userId}, ${name})
    ON CONFLICT (user_id, name) DO UPDATE SET name = EXCLUDED.name
    RETURNING *`;
  return rowToTag((rows as Row[])[0]);
}

export async function getTag(userId: string, tagId: string): Promise<Tag | null> {
  await ensureSchema();
  const rows = await db()`
    SELECT * FROM dumpster_tags WHERE user_id = ${userId} AND id = ${tagId}`;
  return (rows as Row[]).length ? rowToTag((rows as Row[])[0]) : null;
}

// Rewrites `#oldName` → `#newName` in every dump and doc, so renames and
// merges propagate the way they do in the Swift apps.
async function rewriteHashtag(userId: string, oldName: string, newName: string) {
  const sql = db();
  const pattern = tagPattern(oldName);
  const dumps = (await sql`
    SELECT id, content FROM dumpster_daily_dumps
    WHERE user_id = ${userId} AND content LIKE ${'%#' + oldName + '%'}`) as Row[];
  for (const d of dumps) {
    const next = String(d.content).replace(pattern, `#${newName}`);
    if (next !== d.content) {
      await sql`UPDATE dumpster_daily_dumps SET content = ${next}, updated_at = now() WHERE id = ${d.id}`;
    }
  }
  const docs = (await sql`
    SELECT id, content FROM dumpster_master_docs
    WHERE user_id = ${userId} AND content LIKE ${'%#' + oldName + '%'}`) as Row[];
  for (const doc of docs) {
    const next = String(doc.content).replace(pattern, `#${newName}`);
    if (next !== doc.content) {
      await sql`UPDATE dumpster_master_docs SET content = ${next}, updated_at = now() WHERE id = ${doc.id}`;
    }
  }
}

// Re-points every reference from one tag to another, then deletes the
// source tag. Shared by merge and rename-onto-existing.
export async function mergeTags(userId: string, fromId: string, toId: string): Promise<void> {
  if (fromId === toId) return;
  await ensureSchema();
  const sql = db();
  const from = await getTag(userId, fromId);
  const to = await getTag(userId, toId);
  if (!from || !to) throw new Error('Tag not found');

  await sql`
    INSERT INTO dumpster_item_tags (user_id, item_id, tag_id)
    SELECT user_id, item_id, ${toId} FROM dumpster_item_tags
    WHERE user_id = ${userId} AND tag_id = ${fromId}
    ON CONFLICT DO NOTHING`;
  await sql`
    INSERT INTO dumpster_master_doc_tags (user_id, doc_id, tag_id)
    SELECT user_id, doc_id, ${toId} FROM dumpster_master_doc_tags
    WHERE user_id = ${userId} AND tag_id = ${fromId}
    ON CONFLICT DO NOTHING`;
  await sql`
    UPDATE dumpster_tag_relationships SET parent_tag_id = ${toId}
    WHERE user_id = ${userId} AND parent_tag_id = ${fromId}
      AND child_tag_id <> ${toId}
      AND NOT EXISTS (
        SELECT 1 FROM dumpster_tag_relationships r2
        WHERE r2.user_id = ${userId} AND r2.parent_tag_id = ${toId}
          AND r2.child_tag_id = dumpster_tag_relationships.child_tag_id)`;
  await sql`
    UPDATE dumpster_tag_relationships SET child_tag_id = ${toId}
    WHERE user_id = ${userId} AND child_tag_id = ${fromId}
      AND parent_tag_id <> ${toId}
      AND NOT EXISTS (
        SELECT 1 FROM dumpster_tag_relationships r2
        WHERE r2.user_id = ${userId} AND r2.child_tag_id = ${toId}
          AND r2.parent_tag_id = dumpster_tag_relationships.parent_tag_id)`;
  await rewriteHashtag(userId, from.name, to.name);
  // Cascades take item_tags/doc_tags/relationship rows still pointing here.
  await sql`DELETE FROM dumpster_tags WHERE user_id = ${userId} AND id = ${fromId}`;
}

// Rename; if the new name already exists this becomes a merge (matching
// the Swift apps' "rename to an existing tag → they merge" behavior).
// Returns the id the tag ended up as.
export async function renameTag(userId: string, tagId: string, rawNewName: string): Promise<string> {
  await ensureSchema();
  const newName = normalizeTagName(rawNewName);
  if (!newName) throw new Error('Tag name cannot be empty');
  const tag = await getTag(userId, tagId);
  if (!tag) throw new Error('Tag not found');
  if (tag.name === newName) return tagId;

  const existing = (await db()`
    SELECT id FROM dumpster_tags WHERE user_id = ${userId} AND name = ${newName}`) as Row[];
  if (existing.length) {
    const targetId = String(existing[0].id);
    await mergeTags(userId, tagId, targetId);
    return targetId;
  }
  await db()`UPDATE dumpster_tags SET name = ${newName} WHERE user_id = ${userId} AND id = ${tagId}`;
  await rewriteHashtag(userId, tag.name, newName);
  return tagId;
}

export async function deleteTag(userId: string, tagId: string): Promise<void> {
  await ensureSchema();
  await db()`DELETE FROM dumpster_tags WHERE user_id = ${userId} AND id = ${tagId}`;
}

export async function addSubTag(userId: string, parentTagId: string, childTagId: string) {
  await ensureSchema();
  if (parentTagId === childTagId) throw new Error('A tag cannot be its own sub-tag');
  await db()`
    INSERT INTO dumpster_tag_relationships (id, user_id, parent_tag_id, child_tag_id)
    VALUES (${randomUUID()}, ${userId}, ${parentTagId}, ${childTagId})
    ON CONFLICT DO NOTHING`;
}

export async function removeSubTag(userId: string, parentTagId: string, childTagId: string) {
  await ensureSchema();
  await db()`
    DELETE FROM dumpster_tag_relationships
    WHERE user_id = ${userId} AND parent_tag_id = ${parentTagId} AND child_tag_id = ${childTagId}`;
}

// ---------------------------------------------------------------- items

async function tagIdsByItem(userId: string): Promise<Map<string, string[]>> {
  const rows = (await db()`
    SELECT item_id, tag_id FROM dumpster_item_tags WHERE user_id = ${userId}`) as Row[];
  const map = new Map<string, string[]>();
  for (const r of rows) {
    const itemId = String(r.item_id);
    if (!map.has(itemId)) map.set(itemId, []);
    map.get(itemId)!.push(String(r.tag_id));
  }
  return map;
}

export async function listItems(userId: string): Promise<Item[]> {
  await ensureSchema();
  const [rows, tagMap] = await Promise.all([
    db()`SELECT * FROM dumpster_items WHERE user_id = ${userId} ORDER BY created_at DESC`,
    tagIdsByItem(userId),
  ]);
  return (rows as Row[]).map((r) => rowToItem(r, tagMap.get(String(r.id)) ?? []));
}

export async function getItem(userId: string, itemId: string): Promise<Item | null> {
  await ensureSchema();
  const rows = (await db()`
    SELECT * FROM dumpster_items WHERE user_id = ${userId} AND id = ${itemId}`) as Row[];
  if (!rows.length) return null;
  const tagRows = (await db()`
    SELECT tag_id FROM dumpster_item_tags WHERE user_id = ${userId} AND item_id = ${itemId}`) as Row[];
  return rowToItem(rows[0], tagRows.map((r) => String(r.tag_id)));
}

export interface NewItem {
  text: string;
  category?: Category;
  priority?: Priority;
  dueDate?: string | null;
  url?: string | null;
  urlTitle?: string | null;
  notes?: string | null;
}

export async function createItem(userId: string, input: NewItem): Promise<Item> {
  await ensureSchema();
  const rows = await db()`
    INSERT INTO dumpster_items (id, user_id, text, category, priority, due_date, url, url_title, notes)
    VALUES (${randomUUID()}, ${userId}, ${input.text}, ${input.category ?? 'brainstorm'},
            ${input.priority ?? 'medium'}, ${input.dueDate ?? null}, ${input.url ?? null},
            ${input.urlTitle ?? null}, ${input.notes ?? null})
    RETURNING *`;
  return rowToItem((rows as Row[])[0]);
}

export interface ItemPatch {
  text?: string;
  category?: Category;
  priority?: Priority;
  done?: boolean;
  dueDate?: string | null;
  url?: string | null;
  urlTitle?: string | null;
  notes?: string | null;
  incorporatedIntoDoc?: boolean;
  dismissedFromDoc?: boolean;
  tagNames?: string[]; // replaces the item's tags when present
}

export async function updateItem(userId: string, itemId: string, patch: ItemPatch): Promise<Item | null> {
  await ensureSchema();
  const sql = db();
  const existing = (await sql`
    SELECT * FROM dumpster_items WHERE user_id = ${userId} AND id = ${itemId}`) as Row[];
  if (!existing.length) return null;
  const cur = existing[0];

  const done = patch.done ?? Boolean(cur.done);
  const doneAt = patch.done === undefined ? cur.done_at : patch.done ? new Date().toISOString() : null;

  await sql`
    UPDATE dumpster_items SET
      text = ${patch.text ?? String(cur.text)},
      category = ${patch.category ?? String(cur.category)},
      priority = ${patch.priority ?? String(cur.priority)},
      done = ${done},
      done_at = ${doneAt},
      due_date = ${patch.dueDate !== undefined ? patch.dueDate : cur.due_date},
      url = ${patch.url !== undefined ? patch.url : cur.url},
      url_title = ${patch.urlTitle !== undefined ? patch.urlTitle : cur.url_title},
      notes = ${patch.notes !== undefined ? patch.notes : cur.notes},
      incorporated_into_doc = ${patch.incorporatedIntoDoc ?? Boolean(cur.incorporated_into_doc)},
      dismissed_from_doc = ${patch.dismissedFromDoc ?? Boolean(cur.dismissed_from_doc)}
    WHERE user_id = ${userId} AND id = ${itemId}`;

  if (patch.tagNames) {
    await sql`DELETE FROM dumpster_item_tags WHERE user_id = ${userId} AND item_id = ${itemId}`;
    await tagItemWithNames(userId, itemId, patch.tagNames);
  }
  return getItem(userId, itemId);
}

export async function deleteItem(userId: string, itemId: string): Promise<void> {
  await ensureSchema();
  await db()`DELETE FROM dumpster_items WHERE user_id = ${userId} AND id = ${itemId}`;
}

export async function tagItemWithNames(userId: string, itemId: string, tagNames: string[]) {
  for (const name of tagNames) {
    const normalized = normalizeTagName(name);
    if (!normalized) continue;
    const tag = await getOrCreateTag(userId, normalized);
    await db()`
      INSERT INTO dumpster_item_tags (user_id, item_id, tag_id)
      VALUES (${userId}, ${itemId}, ${tag.id})
      ON CONFLICT DO NOTHING`;
  }
}

// Dedupe helper used by magic-tag processing: finds an item whose
// tag-stripped text matches exactly (the Swift apps' itemAlreadyExists).
export async function findItemByCleanText(userId: string, cleanText: string): Promise<Item | null> {
  await ensureSchema();
  const rows = (await db()`
    SELECT * FROM dumpster_items
    WHERE user_id = ${userId} AND text ILIKE ${'%' + cleanText + '%'}`) as Row[];
  const match = rows.find((r) => stripTags(String(r.text)) === cleanText);
  return match ? rowToItem(match) : null;
}

export async function deleteItemsByCleanText(userId: string, cleanText: string): Promise<number> {
  await ensureSchema();
  const rows = (await db()`
    SELECT id, text FROM dumpster_items
    WHERE user_id = ${userId} AND text ILIKE ${'%' + cleanText + '%'}`) as Row[];
  let deleted = 0;
  for (const r of rows) {
    if (stripTags(String(r.text)) === cleanText) {
      await db()`DELETE FROM dumpster_items WHERE user_id = ${userId} AND id = ${r.id}`;
      deleted++;
    }
  }
  return deleted;
}

// ---------------------------------------------------------------- dumps

export async function listDumps(userId: string, limit = 30): Promise<DailyDump[]> {
  await ensureSchema();
  const rows = await db()`
    SELECT * FROM dumpster_daily_dumps WHERE user_id = ${userId}
    ORDER BY date DESC LIMIT ${limit}`;
  return (rows as Row[]).map(rowToDump);
}

export async function upsertDump(userId: string, date: string, content: string): Promise<DailyDump> {
  await ensureSchema();
  const rows = await db()`
    INSERT INTO dumpster_daily_dumps (id, user_id, date, content)
    VALUES (${randomUUID()}, ${userId}, ${date}, ${content})
    ON CONFLICT (user_id, date) DO UPDATE SET content = EXCLUDED.content, updated_at = now()
    RETURNING *`;
  return rowToDump((rows as Row[])[0]);
}

// ----------------------------------------------------------------- docs

async function tagIdsByDoc(userId: string): Promise<Map<string, string[]>> {
  const rows = (await db()`
    SELECT doc_id, tag_id FROM dumpster_master_doc_tags WHERE user_id = ${userId}`) as Row[];
  const map = new Map<string, string[]>();
  for (const r of rows) {
    const docId = String(r.doc_id);
    if (!map.has(docId)) map.set(docId, []);
    map.get(docId)!.push(String(r.tag_id));
  }
  return map;
}

export async function listDocs(userId: string): Promise<MasterDoc[]> {
  await ensureSchema();
  const [rows, tagMap] = await Promise.all([
    db()`SELECT * FROM dumpster_master_docs WHERE user_id = ${userId} ORDER BY updated_at DESC`,
    tagIdsByDoc(userId),
  ]);
  return (rows as Row[]).map((r) => rowToDoc(r, tagMap.get(String(r.id)) ?? []));
}

export async function getDoc(userId: string, docId: string): Promise<MasterDoc | null> {
  await ensureSchema();
  const rows = (await db()`
    SELECT * FROM dumpster_master_docs WHERE user_id = ${userId} AND id = ${docId}`) as Row[];
  if (!rows.length) return null;
  const tagRows = (await db()`
    SELECT tag_id FROM dumpster_master_doc_tags WHERE user_id = ${userId} AND doc_id = ${docId}`) as Row[];
  return rowToDoc(rows[0], tagRows.map((r) => String(r.tag_id)));
}

export async function createDoc(
  userId: string,
  title: string,
  tagNames: string[],
  content = '',
): Promise<MasterDoc> {
  await ensureSchema();
  const rows = await db()`
    INSERT INTO dumpster_master_docs (id, user_id, title, content)
    VALUES (${randomUUID()}, ${userId}, ${title}, ${content})
    RETURNING *`;
  const doc = rowToDoc((rows as Row[])[0]);
  await setDocTags(userId, doc.id, tagNames);
  return (await getDoc(userId, doc.id))!;
}

export async function setDocTags(userId: string, docId: string, tagNames: string[]) {
  const sql = db();
  await sql`DELETE FROM dumpster_master_doc_tags WHERE user_id = ${userId} AND doc_id = ${docId}`;
  for (const name of tagNames) {
    const normalized = normalizeTagName(name);
    if (!normalized) continue;
    const tag = await getOrCreateTag(userId, normalized);
    await sql`
      INSERT INTO dumpster_master_doc_tags (user_id, doc_id, tag_id)
      VALUES (${userId}, ${docId}, ${tag.id})
      ON CONFLICT DO NOTHING`;
  }
}

export interface DocPatch {
  title?: string;
  content?: string;
  tagNames?: string[];
}

export async function updateDoc(userId: string, docId: string, patch: DocPatch): Promise<MasterDoc | null> {
  await ensureSchema();
  const cur = await getDoc(userId, docId);
  if (!cur) return null;
  await db()`
    UPDATE dumpster_master_docs SET
      title = ${patch.title ?? cur.title},
      content = ${patch.content ?? cur.content},
      updated_at = now()
    WHERE user_id = ${userId} AND id = ${docId}`;
  if (patch.tagNames) await setDocTags(userId, docId, patch.tagNames);
  return getDoc(userId, docId);
}

export async function deleteDoc(userId: string, docId: string): Promise<void> {
  await ensureSchema();
  await db()`DELETE FROM dumpster_master_docs WHERE user_id = ${userId} AND id = ${docId}`;
}

// Finds the doc a #save should land in for a tag, creating a fresh doc
// titled from the tag name (like the Swift apps) when none exists.
export async function getOrCreateDocForTag(userId: string, tagName: string): Promise<MasterDoc> {
  await ensureSchema();
  const normalized = normalizeTagName(tagName);
  const tag = await getOrCreateTag(userId, normalized);
  const rows = (await db()`
    SELECT doc_id FROM dumpster_master_doc_tags
    WHERE user_id = ${userId} AND tag_id = ${tag.id}
    LIMIT 1`) as Row[];
  if (rows.length) {
    const doc = await getDoc(userId, String(rows[0].doc_id));
    if (doc) return doc;
  }
  const title = normalized
    .split('-')
    .map((w) => (w ? w[0].toUpperCase() + w.slice(1) : w))
    .join(' ');
  return createDoc(userId, title, [normalized]);
}

// ----------------------------------------------------------------- wins

export async function listWins(userId: string): Promise<Win[]> {
  await ensureSchema();
  const rows = await db()`
    SELECT * FROM dumpster_wins WHERE user_id = ${userId} ORDER BY created_at DESC`;
  return (rows as Row[]).map(rowToWin);
}

export async function createWin(userId: string, text: string, artifact?: string | null): Promise<Win> {
  await ensureSchema();
  const rows = await db()`
    INSERT INTO dumpster_wins (id, user_id, text, artifact)
    VALUES (${randomUUID()}, ${userId}, ${text.trim()}, ${artifact?.trim() || null})
    RETURNING *`;
  return rowToWin((rows as Row[])[0]);
}

export async function updateWin(
  userId: string,
  winId: string,
  patch: { text?: string; artifact?: string | null },
): Promise<Win | null> {
  await ensureSchema();
  const rows = (await db()`
    SELECT * FROM dumpster_wins WHERE user_id = ${userId} AND id = ${winId}`) as Row[];
  if (!rows.length) return null;
  const cur = rows[0];
  const updated = await db()`
    UPDATE dumpster_wins SET
      text = ${patch.text ?? String(cur.text)},
      artifact = ${patch.artifact !== undefined ? patch.artifact : cur.artifact}
    WHERE user_id = ${userId} AND id = ${winId}
    RETURNING *`;
  return rowToWin((updated as Row[])[0]);
}

export async function deleteWin(userId: string, winId: string): Promise<void> {
  await ensureSchema();
  await db()`DELETE FROM dumpster_wins WHERE user_id = ${userId} AND id = ${winId}`;
}

export async function winExists(userId: string, text: string): Promise<boolean> {
  await ensureSchema();
  const rows = (await db()`
    SELECT 1 FROM dumpster_wins WHERE user_id = ${userId} AND text = ${text.trim()} LIMIT 1`) as Row[];
  return rows.length > 0;
}

// -------------------------------------------------------- hidden bullets

export async function listHiddenBullets(userId: string): Promise<string[]> {
  await ensureSchema();
  const rows = (await db()`
    SELECT bullet_text FROM dumpster_hidden_bullets WHERE user_id = ${userId}`) as Row[];
  return rows.map((r) => String(r.bullet_text));
}

export async function hideBullet(userId: string, bulletText: string): Promise<void> {
  await ensureSchema();
  await db()`
    INSERT INTO dumpster_hidden_bullets (id, user_id, bullet_text)
    VALUES (${randomUUID()}, ${userId}, ${bulletText})`;
}
