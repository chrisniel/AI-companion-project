import React, { useState } from 'react';
import { Copy, Check, Terminal } from 'lucide-react';

export interface AssistantMarkdownRendererProps {
  content: string;
  className?: string;
}

/**
 * Safely parses inline markdown (bold, italic, code, links) into React elements.
 * Prevents raw HTML execution and forbids dangerous URI schemes (javascript:).
 */
function renderInline(text: string): React.ReactNode[] {
  const elements: React.ReactNode[] = [];
  // Tokenize regex for inline elements:
  // 1. inline code: `code`
  // 2. bold-italic: ***text***
  // 3. bold: **text**
  // 4. italic: *text*
  // 5. links: [text](url)
  const tokenRegex = /(`[^`]+`|\*\*\*[^*]+\*\*\*|\*\*[^*]+\*\*|\*[^*]+\*|\[[^\]]+\]\((?:[^()]+|\([^()]*\))*\))/g;

  let lastIndex = 0;
  let match: RegExpExecArray | null;

  while ((match = tokenRegex.exec(text)) !== null) {
    if (match.index > lastIndex) {
      elements.push(text.slice(lastIndex, match.index));
    }

    const token = match[0];
    const key = `inline-${match.index}`;

    if (token.startsWith('`') && token.endsWith('`')) {
      const code = token.slice(1, -1);
      elements.push(
        <code
          key={key}
          className="px-1.5 py-0.5 rounded-md surface-recessed border border-[var(--color-border-subtle)] font-mono text-xs text-[var(--color-accent)] font-semibold"
        >
          {code}
        </code>
      );
    } else if (token.startsWith('***') && token.endsWith('***')) {
      elements.push(
        <strong key={key} className="font-bold italic">
          {token.slice(3, -3)}
        </strong>
      );
    } else if (token.startsWith('**') && token.endsWith('**')) {
      elements.push(
        <strong key={key} className="font-semibold text-[var(--color-text-primary)]">
          {token.slice(2, -2)}
        </strong>
      );
    } else if (token.startsWith('*') && token.endsWith('*')) {
      elements.push(
        <em key={key} className="italic text-[var(--color-text-primary)]">
          {token.slice(1, -1)}
        </em>
      );
    } else if (token.startsWith('[') && token.includes('](') && token.endsWith(')')) {
      const linkMatch = token.match(/^\[([^\]]+)\]\((.*)\)$/);
      if (linkMatch) {
        const [, label, href] = linkMatch;
        // XSS sanitization: only allow http:, https:, mailto:
        const isSafeUrl = /^(https?:\/\/|mailto:)/i.test(href.trim());
        if (isSafeUrl) {
          elements.push(
            <a
              key={key}
              href={href.trim()}
              target="_blank"
              rel="noopener noreferrer"
              className="text-[var(--color-accent)] hover:underline font-medium inline-flex items-center gap-0.5"
            >
              {label}
            </a>
          );
        } else {
          // If unsafe scheme, render plain text
          elements.push(label);
        }
      } else {
        elements.push(token);
      }
    } else {
      elements.push(token);
    }

    lastIndex = match.index + token.length;
  }

  if (lastIndex < text.length) {
    elements.push(text.slice(lastIndex));
  }

  return elements.length > 0 ? elements : [text];
}

interface CodeBlockProps {
  language?: string;
  code: string;
}

const CodeBlock: React.FC<CodeBlockProps> = ({ language, code }) => {
  const [copied, setCopied] = useState(false);

  const handleCopy = () => {
    navigator.clipboard?.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="my-3 rounded-2xl overflow-hidden border border-[var(--color-surface-glass-border)] bg-[var(--color-surface-recessed)] shadow-md">
      <div className="flex items-center justify-between px-3.5 py-1.5 border-b border-[var(--color-border-subtle)] bg-[var(--color-surface-raised)] text-[11px] font-mono text-[var(--color-text-muted)]">
        <div className="flex items-center gap-1.5">
          <Terminal className="w-3.5 h-3.5 text-[var(--color-accent)]" />
          <span className="font-semibold uppercase">{language || 'text'}</span>
        </div>
        <button
          type="button"
          onClick={handleCopy}
          aria-label="Copy code to clipboard"
          className="flex items-center gap-1 px-2 py-0.5 rounded-md hover:bg-[var(--color-surface-subtle)] text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] transition-colors cursor-pointer"
        >
          {copied ? (
            <>
              <Check className="w-3 h-3 text-emerald-500" />
              <span className="text-[10px]">Copied</span>
            </>
          ) : (
            <>
              <Copy className="w-3 h-3" />
              <span className="text-[10px]">Copy</span>
            </>
          )}
        </button>
      </div>
      <div className="p-3.5 overflow-x-auto text-xs font-mono leading-relaxed text-[var(--color-text-primary)]">
        <pre className="m-0 p-0 whitespace-pre">
          <code>{code}</code>
        </pre>
      </div>
    </div>
  );
};

function splitTableRow(rawLine: string): string[] {
  let line = rawLine.trim();
  if (!line) return [];

  if (line.startsWith('|')) {
    line = line.slice(1);
  }
  if (line.endsWith('|') && !line.endsWith('\\|')) {
    line = line.slice(0, -1);
  }

  const cells: string[] = [];
  let current = '';
  let inCode = false;
  let isEscaped = false;

  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (isEscaped) {
      if (char === '|') {
        current += '|';
      } else {
        current += '\\' + char;
      }
      isEscaped = false;
      continue;
    }

    if (char === '\\') {
      isEscaped = true;
      continue;
    }

    if (char === '`') {
      inCode = !inCode;
      current += '`';
      continue;
    }

    if (char === '|' && !inCode) {
      cells.push(current.trim());
      current = '';
      continue;
    }

    current += char;
  }

  if (isEscaped) {
    current += '\\';
  }
  cells.push(current.trim());
  return cells;
}

function isSeparatorRow(cells: string[]): boolean {
  if (cells.length === 0) return false;
  const separatorPattern = /^\s*:?-{1,}:?\s*$/;
  return cells.every(cell => separatorPattern.test(cell));
}

function parseCellAlignment(sepCell: string): 'left' | 'center' | 'right' {
  const trimmed = sepCell.trim();
  const startsWithColon = trimmed.startsWith(':');
  const endsWithColon = trimmed.endsWith(':');
  if (startsWithColon && endsWithColon) {
    return 'center';
  } else if (endsWithColon) {
    return 'right';
  } else {
    return 'left';
  }
}

function isPossibleTableStart(line: string, nextLine: string): boolean {
  if (!line.includes('|')) return false;
  const headers = splitTableRow(line);
  const seps = splitTableRow(nextLine);
  return headers.length > 0 && isSeparatorRow(seps) && seps.length >= headers.length;
}

interface TableBlockProps {
  headers: string[];
  rows: string[][];
  alignments: ('left' | 'center' | 'right')[];
}

const TableBlock: React.FC<TableBlockProps> = ({ headers, rows, alignments }) => {
  const alignClass = (align: 'left' | 'center' | 'right') => {
    if (align === 'center') return 'text-center';
    if (align === 'right') return 'text-right';
    return 'text-left';
  };

  return (
    <div className="my-3 overflow-x-auto rounded-xl border border-[var(--color-surface-glass-border)] bg-[var(--color-surface-recessed)] shadow-sm">
      <table className="w-full border-collapse text-xs text-[var(--color-text-primary)]">
        <thead>
          <tr className="border-b border-[var(--color-border-subtle)] bg-[var(--color-surface-raised)]">
            {headers.map((header, idx) => (
              <th
                key={`th-${idx}`}
                className={`px-3.5 py-2 font-semibold text-[var(--color-text-primary)] ${alignClass(
                  alignments[idx] || 'left'
                )}`}
              >
                {renderInline(header)}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-[var(--color-border-subtle)]">
          {rows.map((row, rowIdx) => (
            <tr
              key={`tr-${rowIdx}`}
              className={rowIdx % 2 === 1 ? 'bg-[var(--color-surface-subtle)]' : undefined}
            >
              {headers.map((_, colIdx) => (
                <td
                  key={`td-${rowIdx}-${colIdx}`}
                  className={`px-3.5 py-2 ${alignClass(alignments[colIdx] || 'left')}`}
                >
                  {renderInline(row[colIdx] || '')}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export const AssistantMarkdownRenderer: React.FC<AssistantMarkdownRendererProps> = ({
  content,
  className = '',
}) => {
  if (!content) return null;

  // Split into lines for streaming-stable block parsing
  const lines = content.split('\n');
  const blocks: React.ReactNode[] = [];

  let i = 0;
  while (i < lines.length) {
    const line = lines[i];

    // 1. Fenced Code Block: ```lang
    if (line.trim().startsWith('```')) {
      const language = line.trim().slice(3).trim();
      const codeLines: string[] = [];
      i++;
      let closed = false;
      while (i < lines.length) {
        if (lines[i].trim().startsWith('```')) {
          closed = true;
          i++;
          break;
        }
        codeLines.push(lines[i]);
        i++;
      }
      blocks.push(
        <CodeBlock
          key={`codeblock-${i}`}
          language={language}
          code={codeLines.join('\n')}
        />
      );
      continue;
    }

    // 2. Horizontal Rule: --- or ***
    if (/^(\s*[-*_]\s*){3,}$/.test(line)) {
      blocks.push(
        <hr
          key={`hr-${i}`}
          className="my-3 border-t border-[var(--color-border-subtle)]"
        />
      );
      i++;
      continue;
    }

    // 3. Headings: #, ##, ###, ####
    const headingMatch = line.match(/^(#{1,4})\s+(.+)$/);
    if (headingMatch) {
      const level = headingMatch[1].length;
      const headingText = headingMatch[2];
      const inline = renderInline(headingText);

      if (level === 1) {
        blocks.push(
          <h2 key={`h-${i}`} className="text-base font-bold text-[var(--color-text-primary)] mt-3 mb-1.5">
            {inline}
          </h2>
        );
      } else if (level === 2) {
        blocks.push(
          <h3 key={`h-${i}`} className="text-sm font-bold text-[var(--color-text-primary)] mt-2.5 mb-1">
            {inline}
          </h3>
        );
      } else {
        blocks.push(
          <h4 key={`h-${i}`} className="text-xs font-semibold text-[var(--color-text-primary)] uppercase tracking-wide mt-2 mb-1">
            {inline}
          </h4>
        );
      }
      i++;
      continue;
    }

    // 4. Blockquotes: > quote
    if (line.trim().startsWith('>')) {
      const quoteLines: string[] = [line.trim().replace(/^>\s?/, '')];
      i++;
      while (i < lines.length && lines[i].trim().startsWith('>')) {
        quoteLines.push(lines[i].trim().replace(/^>\s?/, ''));
        i++;
      }
      blocks.push(
        <blockquote
          key={`quote-${i}`}
          className="my-2 pl-3.5 border-l-2 border-[var(--color-accent)] text-xs text-[var(--color-text-secondary)] italic leading-relaxed"
        >
          {quoteLines.map((ql, qIdx) => (
            <div key={`ql-${qIdx}`}>{renderInline(ql)}</div>
          ))}
        </blockquote>
      );
      continue;
    }

    // 5. Unordered Lists: - item or * item
    if (/^\s*[-*]\s+/.test(line)) {
      const listItems: string[] = [];
      while (i < lines.length && /^\s*[-*]\s+/.test(lines[i])) {
        listItems.push(lines[i].replace(/^\s*[-*]\s+/, ''));
        i++;
      }
      blocks.push(
        <ul key={`ul-${i}`} className="my-2 space-y-1 list-disc list-inside text-xs leading-relaxed text-[var(--color-text-primary)]">
          {listItems.map((item, idx) => (
            <li key={`li-${idx}`} className="pl-1">
              <span>{renderInline(item)}</span>
            </li>
          ))}
        </ul>
      );
      continue;
    }

    // 6. Ordered Lists: 1. item
    if (/^\s*\d+\.\s+/.test(line)) {
      const listItems: string[] = [];
      while (i < lines.length && /^\s*\d+\.\s+/.test(lines[i])) {
        listItems.push(lines[i].replace(/^\s*\d+\.\s+/, ''));
        i++;
      }
      blocks.push(
        <ol key={`ol-${i}`} className="my-2 space-y-1 list-decimal list-inside text-xs leading-relaxed text-[var(--color-text-primary)]">
          {listItems.map((item, idx) => (
            <li key={`oli-${idx}`} className="pl-1">
              <span>{renderInline(item)}</span>
            </li>
          ))}
        </ol>
      );
      continue;
    }

    // 7. Table Block
    if (line.includes('|') && i + 1 < lines.length) {
      const headerCells = splitTableRow(line);
      const sepCells = splitTableRow(lines[i + 1]);
      if (
        headerCells.length > 0 &&
        isSeparatorRow(sepCells) &&
        sepCells.length >= headerCells.length
      ) {
        const alignments = sepCells.map(parseCellAlignment);
        const colCount = headerCells.length;
        const normalizedAlignments = Array.from(
          { length: colCount },
          (_, idx) => alignments[idx] || 'left'
        );

        const rows: string[][] = [];
        i += 2;

        while (i < lines.length) {
          const curLine = lines[i];
          if (!curLine.trim()) break;
          if (
            curLine.trim().startsWith('```') ||
            curLine.match(/^(#{1,4})\s+/) ||
            curLine.trim().startsWith('>') ||
            /^\s*[-*]\s+/.test(curLine) ||
            /^\s*\d+\.\s+/.test(curLine) ||
            /^(\s*[-*_]\s*){3,}$/.test(curLine)
          ) {
            break;
          }
          if (!curLine.includes('|')) break;

          let rowCells = splitTableRow(curLine);
          if (rowCells.length < colCount) {
            rowCells = [
              ...rowCells,
              ...Array(colCount - rowCells.length).fill(''),
            ];
          } else if (rowCells.length > colCount) {
            rowCells = rowCells.slice(0, colCount);
          }
          rows.push(rowCells);
          i++;
        }

        blocks.push(
          <TableBlock
            key={`table-${i}`}
            headers={headerCells}
            rows={rows}
            alignments={normalizedAlignments}
          />
        );
        continue;
      }
    }

    // 8. Empty line spacer
    if (!line.trim()) {
      i++;
      continue;
    }

    // 9. Normal Paragraph
    const paragraphLines: string[] = [line];
    i++;
    while (
      i < lines.length &&
      lines[i].trim() &&
      !lines[i].trim().startsWith('```') &&
      !lines[i].match(/^(#{1,4})\s+/) &&
      !lines[i].trim().startsWith('>') &&
      !/^\s*[-*]\s+/.test(lines[i]) &&
      !/^\s*\d+\.\s+/.test(lines[i]) &&
      !/^(\s*[-*_]\s*){3,}$/.test(lines[i]) &&
      !(i + 1 < lines.length && isPossibleTableStart(lines[i], lines[i + 1]))
    ) {
      paragraphLines.push(lines[i]);
      i++;
    }

    blocks.push(
      <p
        key={`p-${i}`}
        className="my-1.5 text-xs sm:text-sm leading-relaxed text-[var(--color-text-primary)]"
      >
        {renderInline(paragraphLines.join('\n'))}
      </p>
    );
  }

  return <div className={`space-y-1 ${className}`}>{blocks}</div>;
};
