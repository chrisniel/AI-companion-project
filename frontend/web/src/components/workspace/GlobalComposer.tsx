import React, { useState, useRef, useEffect } from 'react';
import {
  Paperclip,
  Mic,
  MicOff,
  Send,
  Sparkles,
  Bot,
  Command,
  CornerDownLeft,
  X,
  Pin,
  PinOff,
  ChevronUp,
  Globe,
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { Badge } from '../ui/Badge';

export interface GlobalComposerProps {
  activeCharacterName?: string;
  onSendMessage?: (content: string) => void;
}

export const GlobalComposer: React.FC<GlobalComposerProps> = ({
  activeCharacterName = 'Aura',
  onSendMessage,
}) => {
  const [inputVal, setInputVal] = useState('');
  const [isListening, setIsListening] = useState(false);
  const [attachments, setAttachments] = useState<string[]>([]);
  const [simulatedResponse, setSimulatedResponse] = useState<string | null>(null);
  const [isFocused, setIsFocused] = useState(false);
  const [isHovered, setIsHovered] = useState(false);
  const [isPinned, setIsPinned] = useState(false);
  const [composerLang, setComposerLang] = useState<'auto' | 'en' | 'fil' | 'ja'>('auto');

  const inputRef = useRef<HTMLInputElement>(null);

  const cycleLanguage = () => {
    const modes: ('auto' | 'en' | 'fil' | 'ja')[] = ['auto', 'en', 'fil', 'ja'];
    const next = modes[(modes.indexOf(composerLang) + 1) % modes.length];
    setComposerLang(next);
  };

  const placeholderText =
    composerLang === 'fil'
      ? `Magtanong kay ${activeCharacterName} sa Tagalog/Taglish...`
      : composerLang === 'ja'
      ? `${activeCharacterName}に日本語で質問する...`
      : composerLang === 'en'
      ? `Ask ${activeCharacterName} in English...`
      : `Ask ${activeCharacterName} (Multilingual Auto-Detect)...`;

  // Global shortcut: press "/" to focus composer when not typing in another input
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (
        e.key === '/' &&
        !['INPUT', 'TEXTAREA'].includes((document.activeElement as HTMLElement)?.tagName)
      ) {
        e.preventDefault();
        setIsFocused(true);
        inputRef.current?.focus();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  const isExpanded =
    isPinned ||
    isFocused ||
    isHovered ||
    inputVal.trim().length > 0 ||
    attachments.length > 0 ||
    Boolean(simulatedResponse) ||
    isListening;

  const handleSend = () => {
    if (!inputVal.trim() && attachments.length === 0) return;
    const sentText = inputVal;
    setInputVal('');
    setAttachments([]);
    if (onSendMessage) onSendMessage(sentText);

    // Mock response simulation
    if (composerLang === 'fil') {
      setSimulatedResponse(
        `[Local Core • ${activeCharacterName}]: Natanggap ang command na "${sentText}". Maayos na pinoproseso sa local neural runtime na may 0ms latency.`
      );
    } else if (composerLang === 'ja') {
      setSimulatedResponse(
        `[Local Core • ${activeCharacterName}]: コマンド「${sentText}」を受信しました。ローカルモデルで処理しています。`
      );
    } else {
      setSimulatedResponse(
        `[Local Core • ${activeCharacterName}]: Received command "${sentText}". Synthesizing response with 0ms network latency.`
      );
    }
    setTimeout(() => {
      setSimulatedResponse(null);
    }, 4500);
  };

  const handleAddAttachment = () => {
    const mockFiles = ['context_notes.md', 'telemetry_dump.json', 'system_config.yaml'];
    const randomFile = mockFiles[Math.floor(Math.random() * mockFiles.length)];
    if (!attachments.includes(randomFile)) {
      setAttachments([...attachments, randomFile]);
    }
  };

  const toggleMic = () => {
    if (!isListening) {
      setIsListening(true);
      setInputVal('Transcribing local speech audio input...');
      setTimeout(() => {
        setIsListening(false);
        setInputVal('Summarize my recent local tasks and memory index');
      }, 2200);
    } else {
      setIsListening(false);
    }
  };

  return (
    <div
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
      className="w-full max-w-4xl mx-auto px-4 sm:px-6 pb-3 pt-1 sticky bottom-0 z-20 select-none"
    >
      {/* Transient Simulated Response Banner */}
      <AnimatePresence>
        {simulatedResponse && (
          <motion.div
            initial={{ opacity: 0, y: 10, scale: 0.98 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 10, scale: 0.98 }}
            transition={{ duration: 0.2 }}
            className="mb-2 p-3 rounded-2xl glass-panel-elevated border border-[var(--color-surface-glass-border)] shadow-xl pointer-events-auto flex items-start justify-between gap-3 text-xs"
          >
            <div className="flex items-center gap-2 text-[var(--color-accent)] font-medium">
              <Sparkles className="w-4 h-4 flex-shrink-0 animate-pulse" />
              <span className="text-[var(--color-text-primary)]">{simulatedResponse}</span>
            </div>
            <button
              type="button"
              onClick={() => setSimulatedResponse(null)}
              className="text-[var(--color-text-muted)] hover:text-[var(--color-text-primary)]"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          </motion.div>
        )}
      </AnimatePresence>

      <AnimatePresence initial={false} mode="wait">
        {!isExpanded ? (
          /* Sleek Collapsed Peek Bar (Shows when not focused; expands on mouse hover or click) */
          <motion.div
            key="collapsed-peek"
            initial={{ opacity: 0, y: 8, scale: 0.96 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 8, scale: 0.96 }}
            transition={{ duration: 0.2 }}
            className="flex justify-center"
          >
            <button
              type="button"
              onClick={() => {
                setIsFocused(true);
                setTimeout(() => inputRef.current?.focus(), 50);
              }}
              className="pointer-events-auto group flex items-center gap-2 px-4 py-2 rounded-full glass-panel-elevated border border-[var(--color-surface-glass-border)] shadow-md hover:border-[var(--color-accent)]/50 hover:shadow-lg transition-all text-xs text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]"
            >
              <Sparkles className="w-3.5 h-3.5 text-[var(--color-accent)] group-hover:rotate-12 transition-transform" />
              <span className="font-medium">Ask {activeCharacterName}</span>
              <span className="text-[10px] font-mono px-1.5 py-0.5 rounded-md surface-recessed text-[var(--color-text-muted)] border border-[var(--color-border-subtle)]">
                Hover or /
              </span>
              <ChevronUp className="w-3 h-3 text-[var(--color-text-muted)] group-hover:-translate-y-0.5 transition-transform" />
            </button>
          </motion.div>
        ) : (
          /* Floating Soft Glass Composer Card */
          <motion.div
            key="expanded-composer"
            initial={{ opacity: 0, y: 12, scale: 0.98 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 12, scale: 0.98 }}
            transition={{ duration: 0.22, ease: 'easeOut' }}
            className="p-2 sm:p-2.5 rounded-2xl glass-panel-elevated border border-[var(--color-surface-glass-border)] shadow-2xl pointer-events-auto transition-all duration-200 focus-within:border-[var(--color-accent)]/50 focus-within:shadow-[0_8px_30px_rgba(0,0,0,0.12)]"
          >
            {/* Active Attachments Tray */}
            {attachments.length > 0 && (
              <div className="flex flex-wrap items-center gap-1.5 px-2 pb-2 mb-1 border-b border-[var(--color-border-subtle)]">
                <span className="text-[10px] text-[var(--color-text-muted)] uppercase tracking-wider font-semibold mr-1">
                  Context:
                </span>
                {attachments.map((file) => (
                  <span
                    key={file}
                    className="inline-flex items-center gap-1 px-2 py-0.5 rounded-lg surface-recessed text-xs font-mono text-[var(--color-accent)] border border-[var(--color-border-subtle)]"
                  >
                    {file}
                    <button
                      type="button"
                      onClick={() => setAttachments(attachments.filter((f) => f !== file))}
                      className="hover:text-[var(--color-danger)] ml-0.5"
                    >
                      <X className="w-3 h-3" />
                    </button>
                  </span>
                ))}
              </div>
            )}

            <div className="flex items-center gap-2">
              {/* 1. Add / Attachment Button */}
              <button
                type="button"
                onClick={handleAddAttachment}
                title="Attach file or local context"
                className="w-9 h-9 rounded-xl surface-raised border border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 flex items-center justify-center text-[var(--color-text-secondary)] hover:text-[var(--color-accent)] active:scale-95 transition-all flex-shrink-0"
              >
                <Paperclip className="w-4 h-4" />
              </button>

              {/* 2. Text Input Area */}
              <div className="relative flex-1 flex items-center min-w-0">
                <input
                  ref={inputRef}
                  type="text"
                  value={inputVal}
                  onFocus={() => setIsFocused(true)}
                  onBlur={() => setIsFocused(false)}
                  onChange={(e) => setInputVal(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter') {
                      e.preventDefault();
                      handleSend();
                    } else if (e.key === 'Escape') {
                      inputRef.current?.blur();
                      setIsFocused(false);
                    }
                  }}
                  placeholder={placeholderText}
                  className="w-full bg-transparent px-2.5 py-1.5 text-sm text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] focus:outline-none"
                />
                {isListening && (
                  <span className="absolute right-2 flex items-center gap-1 text-[11px] text-[var(--color-accent)] font-medium animate-pulse">
                    <span className="w-2 h-2 rounded-full bg-[var(--color-accent)]" />
                    Listening...
                  </span>
                )}
              </div>

              {/* 3. Microphone Button */}
              <button
                type="button"
                onClick={toggleMic}
                title={isListening ? 'Stop listening' : 'Start voice transcription'}
                className={`w-9 h-9 rounded-xl border flex items-center justify-center active:scale-95 transition-all flex-shrink-0 ${
                  isListening
                    ? 'bg-[var(--color-danger)] text-white border-transparent shadow-md animate-pulse'
                    : 'surface-raised border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 text-[var(--color-text-secondary)] hover:text-[var(--color-accent)]'
                }`}
              >
                {isListening ? <MicOff className="w-4 h-4" /> : <Mic className="w-4 h-4" />}
              </button>

              {/* 4. Send Button */}
              <button
                type="button"
                onClick={handleSend}
                disabled={!inputVal.trim() && attachments.length === 0}
                title="Send command"
                className="w-9 h-9 rounded-xl bg-accent-gradient text-white flex items-center justify-center shadow-md hover:shadow-lg active:scale-95 disabled:opacity-40 disabled:pointer-events-none transition-all flex-shrink-0 glow-accent-sm"
              >
                <Send className="w-4 h-4" />
              </button>
            </div>

            {/* Bottom Helper Bar */}
            <div className="flex items-center justify-between px-2 pt-1.5 text-[10px] text-[var(--color-text-muted)] border-t border-[var(--color-border-subtle)]/50 mt-1">
              <div className="flex items-center gap-2">
                <span className="flex items-center gap-1 font-mono">
                  <Command className="w-2.5 h-2.5" /> Local Loopback
                </span>
                <span>•</span>
                {/* Language Switcher Pill */}
                <button
                  type="button"
                  onClick={cycleLanguage}
                  title="Switch input language mode (Batch 12.1 Multilingual)"
                  className="flex items-center gap-1 text-[10px] font-mono px-1.5 py-0.5 rounded surface-recessed border border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:text-[var(--color-accent)] hover:border-[var(--color-accent)]/40 transition-all"
                >
                  <Globe className="w-2.5 h-2.5 text-[var(--color-accent)]" />
                  <span>
                    {composerLang === 'auto' && '🌐 Auto'}
                    {composerLang === 'en' && '🇺🇸 EN'}
                    {composerLang === 'fil' && '🇵🇭 Taglish'}
                    {composerLang === 'ja' && '🇯🇵 日本語'}
                  </span>
                </button>
              </div>

              <div className="flex items-center gap-2.5">
                <button
                  type="button"
                  onClick={() => setIsPinned(!isPinned)}
                  title={isPinned ? 'Disable pin (auto-hide on)' : 'Pin composer permanently open'}
                  className={`flex items-center gap-1 text-[10px] font-mono px-1.5 py-0.5 rounded transition-colors ${
                    isPinned
                      ? 'text-[var(--color-accent)] bg-[var(--color-accent)]/10 font-semibold'
                      : 'text-[var(--color-text-muted)] hover:text-[var(--color-text-primary)]'
                  }`}
                >
                  {isPinned ? <Pin className="w-2.5 h-2.5" /> : <PinOff className="w-2.5 h-2.5" />}
                  <span>{isPinned ? 'Pinned' : 'Auto-hide'}</span>
                </button>
                <span className="hidden sm:inline font-mono">
                  Enter <CornerDownLeft className="inline w-2.5 h-2.5 -mt-0.5" /> to send • Esc to collapse
                </span>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
};
