import React from 'react';
import { JapaneseDisplayFormat } from '../../types';

interface JapaneseTextRendererProps {
  kanjiText?: string;
  furiganaText?: string; // e.g. "こんにちは、Chrisさん！[安定|あんてい]しており..."
  romajiText?: string;
  format?: JapaneseDisplayFormat;
  className?: string;
}

export const JapaneseTextRenderer: React.FC<JapaneseTextRendererProps> = ({
  kanjiText = '',
  furiganaText,
  romajiText,
  format = 'kanji_furigana',
  className = '',
}) => {
  // If format is romaji only
  if (format === 'romaji_only' && romajiText) {
    return (
      <span className={`font-mono text-sm tracking-wide text-[var(--color-text-primary)] ${className}`}>
        {romajiText}
      </span>
    );
  }

  // Parse furigana bracket notation: [漢字|かんじ]
  const renderFurigana = (rawText: string) => {
    const parts = rawText.split(/(\[[^\]]+\])/g);
    return parts.map((part, index) => {
      if (part.startsWith('[') && part.endsWith(']')) {
        const inner = part.slice(1, -1);
        const [kanji, reading] = inner.split('|');
        if (kanji && reading) {
          if (format === 'kanji_only') {
            return <span key={index}>{kanji}</span>;
          }
          return (
            <ruby key={index} className="ruby-align">
              <span className="text-[var(--color-text-primary)] font-medium">{kanji}</span>
              <rt className="text-[10px] text-[var(--color-accent)] select-none opacity-85 px-0.5 font-normal">
                {reading}
              </rt>
            </ruby>
          );
        }
      }
      return <span key={index}>{part}</span>;
    });
  };

  const textToRender = furiganaText || kanjiText;

  return (
    <div
      className={`inline-block leading-relaxed tracking-normal ${className}`}
      style={{
        fontFamily:
          'system-ui, -apple-system, "Hiragino Sans", "Hiragino Kaku Gothic ProN", "Yu Gothic", Meiryo, sans-serif',
      }}
    >
      <div className="text-sm text-[var(--color-text-primary)]">
        {furiganaText && format !== 'romaji_only' ? renderFurigana(textToRender) : kanjiText}
      </div>

      {/* Subtext annotation if format is romaji_subtext */}
      {format === 'romaji_subtext' && romajiText && (
        <div className="text-[11px] font-mono text-[var(--color-text-muted)] mt-0.5 tracking-wide italic">
          {romajiText}
        </div>
      )}
    </div>
  );
};
