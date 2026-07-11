'use client';

// Tiny markdown renderer for Master Docs — headings, bullets, numbered
// lists, checklists, bold/italic. Deliberately small: docs are written
// by this app (and the iOS app's migration), not arbitrary markdown.
import type { ReactNode } from 'react';

function inline(text: string, key = 0): ReactNode[] {
  const out: ReactNode[] = [];
  // bold then italic, non-greedy
  const re = /(\*\*([^*]+)\*\*|\*([^*]+)\*|_([^_]+)_)/g;
  let last = 0;
  let match;
  while ((match = re.exec(text))) {
    if (match.index > last) out.push(text.slice(last, match.index));
    if (match[2]) out.push(<strong key={`${key}-${match.index}`}>{match[2]}</strong>);
    else out.push(<em key={`${key}-${match.index}`}>{match[3] ?? match[4]}</em>);
    last = match.index + match[0].length;
  }
  if (last < text.length) out.push(text.slice(last));
  return out;
}

export default function MarkdownPreview({ content }: { content: string }) {
  const blocks: ReactNode[] = [];
  const lines = content.split('\n');
  let list: { type: 'ul' | 'ol'; items: ReactNode[] } | null = null;
  let key = 0;

  const flushList = () => {
    if (!list) return;
    const Tag = list.type;
    blocks.push(
      <Tag key={key++} className={`my-1 flex flex-col gap-0.5 pl-5 ${Tag === 'ul' ? 'list-disc' : 'list-decimal'}`}>
        {list.items}
      </Tag>,
    );
    list = null;
  };

  for (const line of lines) {
    const trimmed = line.trim();
    const bullet = trimmed.match(/^[-•*]\s+(.*)$/);
    const numbered = trimmed.match(/^\d+[.)]\s+(.*)$/);
    const checkbox = trimmed.match(/^[-•*]\s+\[([ xX])\]\s+(.*)$/);

    if (trimmed.startsWith('### ')) {
      flushList();
      blocks.push(
        <h3 key={key++} className="mt-4 mb-1 text-sm font-bold">
          {inline(trimmed.slice(4), key)}
        </h3>,
      );
    } else if (trimmed.startsWith('## ')) {
      flushList();
      blocks.push(
        <h2 key={key++} className="mt-5 mb-1.5 text-base font-bold" style={{ color: 'var(--color-accent)' }}>
          {inline(trimmed.slice(3), key)}
        </h2>,
      );
    } else if (trimmed.startsWith('# ')) {
      flushList();
      blocks.push(
        <h2 key={key++} className="mt-5 mb-1.5 text-lg font-bold">
          {inline(trimmed.slice(2), key)}
        </h2>,
      );
    } else if (checkbox) {
      if (!list || list.type !== 'ul') {
        flushList();
        list = { type: 'ul', items: [] };
      }
      list.items.push(
        <li key={key++} className="list-none text-sm" style={{ marginLeft: '-1.25rem' }}>
          <span className="mr-1.5">{checkbox[1] === ' ' ? '☐' : '☑'}</span>
          {inline(checkbox[2], key)}
        </li>,
      );
    } else if (bullet) {
      if (!list || list.type !== 'ul') {
        flushList();
        list = { type: 'ul', items: [] };
      }
      list.items.push(
        <li key={key++} className="text-sm">
          {inline(bullet[1], key)}
        </li>,
      );
    } else if (numbered) {
      if (!list || list.type !== 'ol') {
        flushList();
        list = { type: 'ol', items: [] };
      }
      list.items.push(
        <li key={key++} className="text-sm">
          {inline(numbered[1], key)}
        </li>,
      );
    } else if (trimmed === '') {
      flushList();
    } else {
      flushList();
      blocks.push(
        <p key={key++} className="my-1 text-sm">
          {inline(trimmed, key)}
        </p>,
      );
    }
  }
  flushList();

  return <div>{blocks}</div>;
}
