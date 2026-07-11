// Master Doc content helpers. Docs are markdown; headings are `## ` and
// `### ` (matching iOS's DocHeadingExtractor after its RTF migration).

export function extractHeadings(content: string): string[] {
  return content
    .split('\n')
    .map((line) => {
      if (line.startsWith('### ')) return line.slice(4).trim();
      if (line.startsWith('## ')) return line.slice(3).trim();
      return null;
    })
    .filter((h): h is string => !!h);
}

// Inserts a bullet at the end of a heading's section. When the heading
// isn't found (or is null), appends to the end of the doc like the Swift
// apps' non-AI fallback.
export function insertUnderHeading(content: string, heading: string | null, bullet: string): string {
  const line = `- ${bullet}`;
  if (!content.trim()) return line;
  if (!heading) return `${content.replace(/\n+$/, '')}\n${line}`;

  const lines = content.split('\n');
  const isHeading = (l: string) => l.startsWith('## ') || l.startsWith('### ');
  const headingText = (l: string) => l.replace(/^#{2,3} /, '').trim();

  const start = lines.findIndex((l) => isHeading(l) && headingText(l) === heading);
  if (start === -1) return `${content.replace(/\n+$/, '')}\n${line}`;

  let end = lines.length;
  for (let i = start + 1; i < lines.length; i++) {
    if (isHeading(lines[i])) {
      end = i;
      break;
    }
  }
  // Insert before trailing blank lines of the section so the bullet sits
  // with the section's content.
  let insertAt = end;
  while (insertAt > start + 1 && lines[insertAt - 1].trim() === '') insertAt--;
  lines.splice(insertAt, 0, line);
  return lines.join('\n');
}

// Legacy iOS backups can contain RTF-encoded doc content (pre-migration).
// Best-effort conversion to plain text so imports never produce garbage.
export function rtfToPlainText(content: string): string {
  if (!content.startsWith('{\\rtf')) return content;
  return (
    content
      // metadata groups (font/color tables etc.) contribute no text
      .replace(/\{\\(?:fonttbl|colortbl|stylesheet|info)[^{}]*\}/g, '')
      .replace(/\{\\\*[^{}]*\}/g, '')
      // \'xx hex escapes
      .replace(/\\'([0-9a-fA-F]{2})/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)))
      .replace(/\\par[d]?\b/g, '\n')
      .replace(/\\line\b/g, '\n')
      .replace(/\\tab\b/g, '\t')
      // remaining control words and groups
      .replace(/\\[a-zA-Z]+-?\d*\s?/g, '')
      .replace(/[{}]/g, '')
      .replace(/\n{3,}/g, '\n\n')
      .trim()
  );
}
