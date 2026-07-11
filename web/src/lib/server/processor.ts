// Magic-tag processing for a dump line, ported line-for-line from the
// Swift MagicTagProcessor.processLine (dumpsteriOS/Models/DailyDump.swift)
// with one difference: #win creates a Win here (iOS skips it; the macOS
// app and this web app have a Wins log).
import { extractURLAndTitle, parseBullet, stripTags } from '../magic';
import { insertUnderHeading } from '../markdown';
import type { Priority, ProcessResult } from '../types';
import * as store from './store';

export async function processLine(userId: string, line: string): Promise<ProcessResult> {
  const result: ProcessResult = {
    createdItems: [],
    createdWin: null,
    savedToDocs: [],
    deletedItems: 0,
    registeredTags: [],
  };

  const bullet = parseBullet(line);
  if (!bullet) return result;

  // Topic tags register the moment they appear on a processed line.
  for (const name of bullet.tags) {
    await store.getOrCreateTag(userId, name);
    result.registeredTags.push(name);
  }

  const magic = new Set(bullet.magicTags);

  if (magic.size > 0) {
    const cleanText = stripTags(bullet.text);
    if (!cleanText) return result;

    const isHighPrio = magic.has('prio');
    const isBacklog = magic.has('backlog');

    const createItem = async (
      category: 'action' | 'brainstorm' | 'resource',
      priority: Priority,
      opts: { url?: string | null; urlTitle?: string | null; text?: string } = {},
    ) => {
      const text = opts.text ?? cleanText;
      const existing = await store.findItemByCleanText(userId, text);
      if (existing) {
        // #action #prio on an existing item upgrades its priority.
        if (category === 'action' && isHighPrio && existing.priority !== 'high') {
          await store.updateItem(userId, existing.id, { priority: 'high' });
        }
        return;
      }
      const item = await store.createItem(userId, {
        text,
        category,
        priority,
        url: opts.url ?? null,
        urlTitle: opts.urlTitle ?? null,
      });
      await store.tagItemWithNames(userId, item.id, bullet.tags);
      result.createdItems.push({ id: item.id, category, priority, text });
    };

    for (const tag of bullet.magicTags) {
      switch (tag) {
        case 'action':
          await createItem('action', isHighPrio ? 'high' : isBacklog ? 'backlog' : 'medium');
          break;
        case 'brainstorm':
          await createItem('brainstorm', 'medium');
          break;
        case 'resource': {
          const { url, title, remainder } = extractURLAndTitle(cleanText);
          const itemText = title ?? (remainder || url || cleanText);
          await createItem('resource', 'medium', { url, urlTitle: title, text: itemText });
          break;
        }
        case 'win':
          if (!(await store.winExists(userId, cleanText))) {
            const win = await store.createWin(userId, cleanText);
            result.createdWin = win.text;
          }
          break;
        case 'save':
          for (const tagName of bullet.tags) {
            const doc = await store.getOrCreateDocForTag(userId, tagName);
            if (doc.content.includes(cleanText)) continue;
            const content = doc.content
              ? insertUnderHeading(doc.content, null, cleanText)
              : `- ${cleanText}`;
            await store.updateDoc(userId, doc.id, { content });
            result.savedToDocs.push(doc.title);
          }
          break;
        case 'prio':
          if (!magic.has('action') && !magic.has('brainstorm')) {
            await createItem('action', 'high');
          }
          break;
        case 'backlog':
          if (!magic.has('action') && !magic.has('brainstorm')) {
            await createItem('action', 'backlog');
          }
          break;
        case 'delete':
          result.deletedItems += await store.deleteItemsByCleanText(userId, cleanText);
          break;
      }
    }
  }

  // Auto-resource: a URL in a bullet without #resource still creates a
  // resource item.
  if (!magic.has('resource')) {
    const { url, title, remainder } = extractURLAndTitle(bullet.text);
    if (url) {
      const itemText = stripTags(title ?? (remainder || url));
      if (itemText && !(await store.findItemByCleanText(userId, itemText))) {
        const item = await store.createItem(userId, {
          text: itemText,
          category: 'resource',
          url,
          urlTitle: title,
        });
        await store.tagItemWithNames(userId, item.id, bullet.tags);
        result.createdItems.push({
          id: item.id,
          category: 'resource',
          priority: 'medium',
          text: itemText,
        });
      }
    }
  }

  return result;
}
