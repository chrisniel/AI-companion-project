import React, { useState, useEffect } from 'react';
import {
  Sparkles,
  Play,
  Pause,
  Layers,
  Code2,
  Info,
} from 'lucide-react';
import { AvatarSemanticState, CharacterConfig } from '../../../types';
import { AvatarPresentation, STATE_VISUAL_REGISTRY } from './AvatarPresentation';
import { Badge } from '../../ui/Badge';
import { Card } from '../../ui/Card';

export interface CharacterPreviewProps {
  character: CharacterConfig;
}

const ALL_SEMANTIC_STATES: AvatarSemanticState[] = [
  'idle',
  'listening',
  'thinking',
  'speaking',
  'happy',
  'concerned',
  'annoyed',
  'error',
];

const SAMPLE_STATE_PHRASES: Record<AvatarSemanticState, string> = {
  idle: 'Standing by for wake word or hotkey sequence. Low-power idle state.',
  listening: 'Capturing streaming microphone VAD telemetry. Processing input buffer...',
  thinking: 'Generating attention matrices. Offloading KV cache to local GPU layers...',
  speaking: 'Streaming phoneme audio synthesis through local neural TTS runtime.',
  happy: 'Optimization complete! System efficiency reached maximum benchmark targets.',
  concerned: 'Elevated nocturnal heart rate detected. Recommending rest window schedule.',
  annoyed: 'Multiple repetitive execution requests detected. Throttling redundant queue.',
  error: 'Context window buffer overrun fault. Fallback recovery subroutine engaged.',
};

export const CharacterPreview: React.FC<CharacterPreviewProps> = ({ character }) => {
  const [activeState, setActiveState] = useState<AvatarSemanticState>('idle');
  const [autoCycle, setAutoCycle] = useState(false);

  // Auto-cycle through states for automated preview if enabled
  useEffect(() => {
    if (!autoCycle) return;
    const interval = setInterval(() => {
      setActiveState((prev) => {
        const nextIndex = (ALL_SEMANTIC_STATES.indexOf(prev) + 1) % ALL_SEMANTIC_STATES.length;
        return ALL_SEMANTIC_STATES[nextIndex];
      });
    }, 2800);
    return () => clearInterval(interval);
  }, [autoCycle]);

  const visual = STATE_VISUAL_REGISTRY[activeState];

  return (
    <Card
      id="character-preview-card"
      variant="elevated"
      padding="md"
      className="space-y-4"
    >
      {/* Header & Meta */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pb-3 border-b border-[var(--color-border-subtle)]">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-xl surface-raised flex items-center justify-center text-[var(--color-accent)] border border-[var(--color-border-subtle)] shadow-xs flex-shrink-0">
            <Sparkles className="w-4 h-4" />
          </div>
          <div>
            <h3 className="text-sm font-bold text-[var(--color-text-primary)]">
              Interactive Avatar & State Preview
            </h3>
            <p className="text-[11px] text-[var(--color-text-muted)]">
              Preview real-time semantic emotion states without executing TTS audio
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => setAutoCycle(!autoCycle)}
            className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-mono border transition-all ${
              autoCycle
                ? 'bg-[var(--color-accent)] text-white border-[var(--color-accent)] shadow-xs'
                : 'surface-recessed text-[var(--color-text-secondary)] border-[var(--color-border-subtle)] hover:border-[var(--color-border-strong)]'
            }`}
          >
            {autoCycle ? (
              <>
                <Pause className="w-3 h-3" />
                <span>Auto-Cycling Active</span>
              </>
            ) : (
              <>
                <Play className="w-3 h-3" />
                <span>Auto-Cycle States</span>
              </>
            )}
          </button>
          <Badge variant="neutral" size="sm">
            8 States
          </Badge>
        </div>
      </div>

      {/* Main Preview Stage */}
      <div className="p-4 sm:p-6 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex flex-col items-center justify-center relative overflow-hidden">
        {/* Subtle grid backdrop */}
        <div
          className="absolute inset-0 opacity-[0.03] pointer-events-none"
          style={{
            backgroundImage: `radial-gradient(var(--color-text-primary) 1px, transparent 1px)`,
            backgroundSize: '16px 16px',
          }}
        />

        {/* Dynamic Procedural Avatar */}
        <div className="my-2">
          <AvatarPresentation
            character={character}
            state={activeState}
            size="lg"
            showStateBadge={false}
          />
        </div>

        {/* Current State Indicator Badge */}
        <div className="mt-3 flex items-center gap-2 px-3 py-1 rounded-full surface-raised border border-[var(--color-border-subtle)] shadow-xs">
          <span
            className="w-2.5 h-2.5 rounded-full animate-pulse"
            style={{ backgroundColor: visual.accentColor }}
          />
          <span className="text-xs font-bold font-mono uppercase tracking-wider text-[var(--color-text-primary)]">
            {visual.label} State
          </span>
          <span className="text-[10px] text-[var(--color-text-muted)] border-l border-[var(--color-border-subtle)] pl-2 font-mono">
            {visual.expressionSymbol}
          </span>
        </div>

        {/* Simulated Transcript Teaser */}
        <div className="mt-4 max-w-md w-full p-3 rounded-xl surface-base border border-[var(--color-border-subtle)] text-center shadow-xs">
          <p className="text-xs italic text-[var(--color-text-secondary)] leading-relaxed">
            &ldquo;{SAMPLE_STATE_PHRASES[activeState]}&rdquo;
          </p>
          <div className="mt-1.5 flex items-center justify-center gap-1.5 text-[10px] text-[var(--color-text-muted)] font-mono">
            <span>Voice: {character.voice}</span>
            <span>•</span>
            <span className="text-emerald-500 font-medium">Visual Simulation Only</span>
          </div>
        </div>
      </div>

      {/* Semantic State Selection Buttons */}
      <div className="space-y-2">
        <div className="flex items-center justify-between text-xs px-1">
          <span className="text-[11px] font-semibold text-[var(--color-text-secondary)]">
            Semantic State Switcher:
          </span>
          <span className="text-[10px] font-mono text-[var(--color-text-muted)]">
            Backend signal: <code className="text-[var(--color-accent)]">AvatarSemanticState</code>
          </span>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
          {ALL_SEMANTIC_STATES.map((state) => {
            const stateMeta = STATE_VISUAL_REGISTRY[state];
            const isSelected = activeState === state;
            const StateIcon = stateMeta.icon;

            return (
              <button
                key={state}
                type="button"
                onClick={() => {
                  setAutoCycle(false);
                  setActiveState(state);
                }}
                className={`p-2.5 rounded-xl border text-left transition-all flex items-center gap-2.5 ${
                  isSelected
                    ? 'surface-raised border-[var(--color-accent)] shadow-xs ring-1 ring-[var(--color-accent)]/30'
                    : 'surface-base border-[var(--color-border-subtle)] hover:border-[var(--color-border-strong)] opacity-85 hover:opacity-100'
                }`}
              >
                <div
                  className={`w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0 transition-colors ${
                    isSelected ? 'text-white' : 'text-[var(--color-text-secondary)]'
                  }`}
                  style={{
                    backgroundColor: isSelected ? stateMeta.accentColor : 'var(--color-surface-recessed)',
                  }}
                >
                  <StateIcon className="w-3.5 h-3.5" />
                </div>
                <div className="min-w-0">
                  <div className="text-xs font-bold text-[var(--color-text-primary)] truncate">
                    {stateMeta.label}
                  </div>
                  <div className="text-[10px] font-mono text-[var(--color-text-muted)] truncate">
                    {stateMeta.expressionSymbol}
                  </div>
                </div>
              </button>
            );
          })}
        </div>
      </div>

      {/* Architectural Decoupling Note */}
      <div className="p-3 rounded-xl surface-base border border-[var(--color-border-subtle)] flex items-start gap-2.5 text-xs text-[var(--color-text-muted)]">
        <Code2 className="w-4 h-4 text-[var(--color-accent)] flex-shrink-0 mt-0.5" />
        <div className="leading-relaxed text-[11px]">
          <strong className="font-semibold text-[var(--color-text-secondary)]">
            Decoupled Presentation Architecture:{' '}
          </strong>
          Backend services emit pure semantic state enums without referencing concrete GIF filenames or hardcoded media assets. The frontend presentation layer dynamically maps semantic events to vector geometry, pulse animations, and procedural shaders.
        </div>
      </div>
    </Card>
  );
};
