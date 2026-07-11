// Bullet parsing and magic-tag rules, ported from MagicTagProcessor /
// DumpBullet in the Swift apps. This module is isomorphic: the dump
// editor uses it to colorize tags and offer autocomplete, the server
// uses it to process lines. Keep it dependency-free.

export const MAGIC_TAGS = [
  'action',
  'brainstorm',
  'resource',
  'win',
  'save',
  'prio',
  'backlog',
  'delete',
] as const;

export type MagicTag = (typeof MAGIC_TAGS)[number];

export function isMagicTag(tag: string): tag is MagicTag {
  return (MAGIC_TAGS as readonly string[]).includes(tag);
}

export interface ParsedBullet {
  text: string; // line without the bullet marker
  tags: string[]; // topic tags, lowercased, no '#'
  magicTags: MagicTag[];
  rawLine: string;
}

const TAG_RE = /#([\w-]+)/g;

export function extractTags(text: string): string[] {
  return [...text.matchAll(TAG_RE)].map((m) => m[1].toLowerCase());
}

export function stripTags(text: string): string {
  return text
    .replace(/#[\w-]+/g, '')
    .replace(/ {2,}/g, ' ')
    .trim();
}

export function stripBulletMarker(line: string): string {
  return line.replace(/^\s*(?:•|\*|-)\s?/, '').trim();
}

export function parseBullet(line: string): ParsedBullet | null {
  const cleaned = stripBulletMarker(line);
  if (!cleaned) return null;
  const all = extractTags(cleaned);
  return {
    text: cleaned,
    tags: all.filter((t) => !isMagicTag(t)),
    magicTags: all.filter(isMagicTag),
    rawLine: line,
  };
}

export function parseBullets(content: string): ParsedBullet[] {
  return content
    .split('\n')
    .map(parseBullet)
    .filter((b): b is ParsedBullet => b !== null);
}

// Pulls a URL and an optional [bracketed title] out of a bullet, matching
// the Swift extractURLAndTitle: the remainder is the bullet text with
// both removed.
export function extractURLAndTitle(text: string): {
  url: string | null;
  title: string | null;
  remainder: string;
} {
  let working = text;

  let title: string | null = null;
  const bracket = working.match(/\[([^\]]+)\]/);
  if (bracket) {
    title = bracket[1];
    working = working.replace(bracket[0], '');
  }

  let url: string | null = null;
  const urlMatch = working.match(/https?:\/\/\S+/);
  if (urlMatch) {
    let extracted = urlMatch[0];
    while (extracted && '.,;:)>"\''.includes(extracted[extracted.length - 1])) {
      extracted = extracted.slice(0, -1);
    }
    url = extracted;
    working = working.replace(urlMatch[0], '');
  }

  return { url, title, remainder: working.replace(/ {2,}/g, ' ').trim() };
}

// CSS class for a tag rendered inline in the dump editor.
export function tagClass(tag: string): string {
  if (isMagicTag(tag)) return `tag-${tag}`;
  return 'tag-topic';
}
