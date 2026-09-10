import React from 'react';
import {
  Check,
  Volume2,
  Cpu,
  Edit3,
  Eye,
  Radio,
  Sparkles,
} from 'lucide-react';
import { CharacterConfig } from '../../../types';
import { AvatarPresentation } from './AvatarPresentation';
import { Badge } from '../../ui/Badge';
import { NeumorphicButton } from '../../ui/NeumorphicButton';

export interface CharacterCardProps {
  character: CharacterConfig;
  isActive: boolean;
  isSelectedForPreview: boolean;
  onSelectActive: (id: string) => void;
  onSelectForEdit: (character: CharacterConfig) => void;
  onSelectForPreview: (character: CharacterConfig) => void;
}

export const CharacterCard: React.FC<CharacterCardProps> = ({
  character,
  isActive,
  isSelectedForPreview,
  onSelectActive,
  onSelectForEdit,
  onSelectForPreview,
}) => {
  const providerLabelMap: Record<string, string> = {
    piper_local: 'Piper (Local)',
    kokoro_local: 'Kokoro (Local)',
    system_tts: 'System Native',
    elevenlabs_cloud: 'ElevenLabs (Cloud)',
  };

  return (
    <div
      id={`character-card-${character.id}`}
      className={`p-4 sm:p-5 rounded-3xl border flex flex-col justify-between transition-all duration-200 relative overflow-hidden ${
        isActive
          ? 'surface-raised border-[var(--color-accent)] ring-1 ring-[var(--color-accent)]/30 shadow-md'
          : isSelectedForPreview
          ? 'surface-raised border-[var(--color-border-strong)] shadow-xs'
          : 'surface-recessed border-[var(--color-border-subtle)] hover:border-[var(--color-border-strong)]'
      }`}
    >
      {/* Subtle Active Indicator Top Bar */}
      {isActive && (
        <div className="absolute top-0 left-0 right-0 h-1 bg-accent-gradient" />
      )}

      <div>
        {/* Top Avatar & Name Header */}
        <div className="flex items-start justify-between gap-3 mb-3.5">
          <div className="flex items-center gap-3">
            <div
              className="cursor-pointer transition-transform hover:scale-105"
              onClick={() => onSelectForPreview(character)}
              title="Click to preview avatar states"
            >
              <AvatarPresentation
                character={character}
                state={isActive ? 'speaking' : 'idle'}
                size="sm"
              />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-base font-bold text-[var(--color-text-primary)]">
                  {character.name}
                </h3>
                {isActive && (
                  <span className="flex h-2 w-2 relative">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
                    <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500" />
                  </span>
                )}
              </div>
              <p className="text-xs text-[var(--color-text-secondary)] font-medium">
                {character.title}
              </p>
            </div>
          </div>

          {/* Active Status Badge */}
          <div>
            {isActive ? (
              <Badge variant="accent" size="sm">
                Active
              </Badge>
            ) : (
              <Badge variant="neutral" size="sm">
                Standby
              </Badge>
            )}
          </div>
        </div>

        {/* Persona Short Description */}
        <p className="text-xs text-[var(--color-text-muted)] italic line-clamp-2 leading-relaxed mb-3">
          &ldquo;{character.personality}&rdquo;
        </p>

        {/* Voice and Runtime Specs */}
        <div className="p-2.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-1.5 text-xs font-mono text-[var(--color-text-secondary)] mb-4">
          <div className="flex items-center justify-between">
            <span className="flex items-center gap-1.5 text-[var(--color-text-muted)]">
              <Volume2 className="w-3.5 h-3.5 text-[var(--color-accent)]" />
              <span>Voice:</span>
            </span>
            <span className="font-semibold text-[var(--color-text-primary)] truncate max-w-[170px]" title={character.voice}>
              {character.voice}
            </span>
          </div>

          <div className="flex items-center justify-between">
            <span className="flex items-center gap-1.5 text-[var(--color-text-muted)]">
              <Cpu className="w-3.5 h-3.5 text-emerald-500" />
              <span>Provider:</span>
            </span>
            <span className="text-[11px] text-[var(--color-text-secondary)]">
              {providerLabelMap[character.voiceProvider || 'piper_local']}
            </span>
          </div>

          <div className="flex items-center justify-between">
            <span className="flex items-center gap-1.5 text-[var(--color-text-muted)]">
              <Sparkles className="w-3.5 h-3.5 text-amber-500" />
              <span>Style:</span>
            </span>
            <span className="capitalize text-[11px] text-[var(--color-text-secondary)]">
              {character.personalityStyle || 'Balanced'}
            </span>
          </div>
        </div>
      </div>

      {/* Action Controls */}
      <div className="pt-3 border-t border-[var(--color-border-subtle)] flex items-center gap-2">
        <NeumorphicButton
          size="sm"
          variant={isActive ? 'primary' : 'secondary'}
          className="flex-1 justify-center"
          onClick={() => onSelectActive(character.id)}
          icon={isActive ? <Check className="w-3.5 h-3.5" /> : <Radio className="w-3.5 h-3.5" />}
        >
          {isActive ? 'Current Active' : 'Set Active'}
        </NeumorphicButton>

        <button
          type="button"
          onClick={() => onSelectForPreview(character)}
          title="Inspect & test avatar states"
          className="p-2 rounded-xl surface-base border border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] hover:border-[var(--color-border-strong)] transition-all"
        >
          <Eye className="w-4 h-4" />
        </button>

        <button
          type="button"
          onClick={() => onSelectForEdit(character)}
          title="Configure character & persona"
          className="p-2 rounded-xl surface-base border border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] hover:border-[var(--color-border-strong)] transition-all"
        >
          <Edit3 className="w-4 h-4" />
        </button>
      </div>
    </div>
  );
};
