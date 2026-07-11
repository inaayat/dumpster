'use client';

// Typed API client + SWR hooks. Every request carries the Neon Auth JWT;
// mutations revalidate the affected SWR keys so views stay in sync.
import useSWR, { mutate } from 'swr';
import { getAuthToken } from './auth';
import type {
  DailyDump,
  Item,
  MasterDoc,
  ProcessResult,
  Tag,
  TagRelationship,
  Win,
} from '../types';

export class ApiError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

export async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = await getAuthToken();
  const res = await fetch(path, {
    ...init,
    headers: {
      ...(init.body ? { 'Content-Type': 'application/json' } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...init.headers,
    },
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new ApiError(data.error || `Request failed (${res.status})`, res.status);
  return data as T;
}

const fetcher = <T>(path: string) => api<T>(path);

// ------------------------------------------------------------- resources

export function useItems() {
  return useSWR<{ items: Item[] }>('/api/items', fetcher);
}

export function useTags() {
  return useSWR<{ tags: Tag[]; relationships: TagRelationship[] }>('/api/tags', fetcher);
}

export function useDumps() {
  return useSWR<{ dumps: DailyDump[] }>('/api/dumps', fetcher);
}

export function useDocs() {
  return useSWR<{ docs: MasterDoc[] }>('/api/docs', fetcher);
}

export interface DocDetail {
  doc: MasterDoc;
  headings: string[];
  inboxItems: Item[];
  inboxBullets: { text: string; date: string }[];
  allItems: Item[];
}

export function useDoc(id: string | null) {
  return useSWR<DocDetail>(id ? `/api/docs/${id}` : null, fetcher);
}

export function useWins() {
  return useSWR<{ wins: Win[] }>('/api/wins', fetcher);
}

// ------------------------------------------------------------- mutations

export const revalidate = {
  items: () => mutate('/api/items'),
  tags: () => mutate('/api/tags'),
  dumps: () => mutate('/api/dumps'),
  docs: () => mutate('/api/docs'),
  doc: (id: string) => mutate(`/api/docs/${id}`),
  wins: () => mutate('/api/wins'),
  all: () =>
    Promise.all([
      mutate('/api/items'),
      mutate('/api/tags'),
      mutate('/api/dumps'),
      mutate('/api/docs'),
      mutate('/api/wins'),
    ]),
};

export async function saveDump(date: string, content: string): Promise<DailyDump> {
  const { dump } = await api<{ dump: DailyDump }>(`/api/dumps/${date}`, {
    method: 'PUT',
    body: JSON.stringify({ content }),
  });
  return dump;
}

export async function processDumpLine(date: string, line: string): Promise<ProcessResult> {
  const { result } = await api<{ result: ProcessResult }>(`/api/dumps/${date}/process`, {
    method: 'POST',
    body: JSON.stringify({ line }),
  });
  // Magic tags can touch nearly everything.
  revalidate.items();
  revalidate.tags();
  if (result.createdWin) revalidate.wins();
  if (result.savedToDocs.length) revalidate.docs();
  return result;
}

export async function patchItem(id: string, patch: Record<string, unknown>): Promise<Item> {
  const { item } = await api<{ item: Item }>(`/api/items/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(patch),
  });
  revalidate.items();
  revalidate.tags();
  return item;
}

export async function removeItem(id: string): Promise<void> {
  await api(`/api/items/${id}`, { method: 'DELETE' });
  revalidate.items();
}

export async function createItem(input: Record<string, unknown>): Promise<Item> {
  const { item } = await api<{ item: Item }>('/api/items', {
    method: 'POST',
    body: JSON.stringify(input),
  });
  revalidate.items();
  revalidate.tags();
  return item;
}

export async function renameTag(id: string, name: string): Promise<{ id: string; merged: boolean }> {
  const result = await api<{ id: string; merged: boolean }>(`/api/tags/${id}`, {
    method: 'PATCH',
    body: JSON.stringify({ name }),
  });
  await revalidate.all();
  return result;
}

export async function mergeTags(fromId: string, toId: string): Promise<void> {
  await api('/api/tags/merge', { method: 'POST', body: JSON.stringify({ fromId, toId }) });
  await revalidate.all();
}

export async function deleteTag(id: string): Promise<void> {
  await api(`/api/tags/${id}`, { method: 'DELETE' });
  await revalidate.all();
}

export async function addSubTag(parentId: string, childId: string): Promise<void> {
  await api('/api/tags/subtag', { method: 'POST', body: JSON.stringify({ parentId, childId }) });
  revalidate.tags();
}

export async function removeSubTag(parentId: string, childId: string): Promise<void> {
  await api('/api/tags/subtag', { method: 'DELETE', body: JSON.stringify({ parentId, childId }) });
  revalidate.tags();
}

export async function createDoc(title: string, tagNames: string[]): Promise<MasterDoc> {
  const { doc } = await api<{ doc: MasterDoc }>('/api/docs', {
    method: 'POST',
    body: JSON.stringify({ title, tagNames }),
  });
  revalidate.docs();
  revalidate.tags();
  return doc;
}

export async function patchDoc(id: string, patch: Record<string, unknown>): Promise<MasterDoc> {
  const { doc } = await api<{ doc: MasterDoc }>(`/api/docs/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(patch),
  });
  revalidate.docs();
  revalidate.doc(id);
  return doc;
}

export async function removeDoc(id: string): Promise<void> {
  await api(`/api/docs/${id}`, { method: 'DELETE' });
  revalidate.docs();
}

export async function incorporate(
  docId: string,
  entry: { itemId?: string; bulletText?: string; heading?: string | null; dismiss?: boolean },
): Promise<void> {
  await api(`/api/docs/${docId}/incorporate`, { method: 'POST', body: JSON.stringify(entry) });
  revalidate.doc(docId);
  revalidate.docs();
  revalidate.items();
}

export async function createWin(text: string, artifact?: string): Promise<Win> {
  const { win } = await api<{ win: Win }>('/api/wins', {
    method: 'POST',
    body: JSON.stringify({ text, artifact }),
  });
  revalidate.wins();
  return win;
}

export async function patchWin(id: string, patch: Record<string, unknown>): Promise<Win> {
  const { win } = await api<{ win: Win }>(`/api/wins/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(patch),
  });
  revalidate.wins();
  return win;
}

export async function removeWin(id: string): Promise<void> {
  await api(`/api/wins/${id}`, { method: 'DELETE' });
  revalidate.wins();
}

export async function importBackup(backup: unknown): Promise<Record<string, number>> {
  const { summary } = await api<{ summary: Record<string, number> }>('/api/backup', {
    method: 'POST',
    body: JSON.stringify(backup),
  });
  await revalidate.all();
  return summary;
}

export async function downloadBackup(): Promise<void> {
  const token = await getAuthToken();
  const res = await fetch('/api/backup', {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  if (!res.ok) throw new ApiError('Export failed', res.status);
  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `dumpster-backup-${new Date().toISOString().slice(0, 10)}.json`;
  a.click();
  URL.revokeObjectURL(url);
}
