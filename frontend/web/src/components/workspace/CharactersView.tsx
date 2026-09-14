import React, { useState } from 'react';
import {
  Sparkles,
  Bot,
  Sliders,
  Volume2,
  Image as ImageIcon,
  Shield,
  Info,
  Layers,
  Heart,
  User,
  Cpu,
} from 'lucide-react';
import { Badge } from '../ui/Badge';

export interface CharactersViewProps {
  activeCharacterId?: string;
  onSelectCharacter?: (id: string) => void;
}

interface PersonalityTrait {
  name: string;
  key: string;
  lowLabel: string;
  highLabel: string;
  value: number;
}

const DEFAULT_PREVIEW_TRAITS: PersonalityTrait[] = [
  { name: 'Warmth', key: 'warmth', lowLabel: 'Reserved', highLabel: 'Affectionate', value: 75 },
  { name: 'Teasing', key: 'teasing', lowLabel: 'Earnest', highLabel: 'Playful', value: 40 },
  { name: 'Guardedness', key: 'guardedness', lowLabel: 'Open', highLabel: 'Protective', value: 30 },
  { name: 'Directness', key: 'directness', lowLabel: 'Gentle', highLabel: 'Blunt', value: 60 },
  { name: 'Expressiveness', key: 'expressiveness', lowLabel: 'Subtle', highLabel: 'Animated', value: 70 },
  { name: 'Affection', key: 'affection', lowLabel: 'Detached', highLabel: 'Devoted', value: 50 },
  { name: 'Formality', key: 'formality', lowLabel: 'Casual', highLabel: 'Formal', value: 20 },
  { name: 'Verbosity', key: 'verbosity', lowLabel: 'Concise', highLabel: 'Elaborate', value: 45 },
];

const ARCHETYPE_PRESETS = [
  { id: 'custom', label: 'Custom' },
  { id: 'warm', label: 'Warm Companion' },
  { id: 'playful', label: 'Playful' },
  { id: 'formal', label: 'Formal Advisor' },
  { id: 'tsundere', label: 'Tsundere (Preset)' },
  { id: 'kuudere', label: 'Kuudere (Preset)' },
  { id: 'dandere', label: 'Dandere (Preset)' },
  { id: 'yandere', label: 'Yandere (Preset)' },
];

export const CharactersView: React.FC<CharactersViewProps> = () => {
  const [selectedPreset, setSelectedPreset] = useState<string>('warm');
  const [previewTraits, setPreviewTraits] = useState<PersonalityTrait[]>(DEFAULT_PREVIEW_TRAITS);

  const handleTraitChange = (key: string, newValue: number) => {
    setPreviewTraits((prev) =>
      prev.map((t) => (t.key === key ? { ...t, value: newValue } : t))
    );
  };

  return (
    <div id="characters-view" className="space-y-8 pb-12">
      {/* 1. Header Banner */}
      <div className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] flex flex-col md:flex-row md:items-center justify-between gap-4 shadow-sm">
        <div className="flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-2xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm flex-shrink-0">
            <Sparkles className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2 flex-wrap">
              <h1 className="text-xl font-bold text-[var(--color-text-primary)]">
                Character Studio
              </h1>
              <Badge variant="primary" size="sm" className="font-semibold">
                Preview
              </Badge>
              <Badge variant="neutral" size="sm">
                Persistence Planned
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] mt-0.5 max-w-2xl">
              Architecture preview for future persona customization. Characters decouple personality, voice, and visual presence from user profile data.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 self-start md:self-auto">
          <div className="px-3.5 py-1.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-muted)] flex items-center gap-2">
            <Info className="w-3.5 h-3.5 text-[var(--color-accent)] flex-shrink-0" />
            <span>Interactive UI preview — modifications are not applied to runtime inference</span>
          </div>
        </div>
      </div>

      {/* 2. Neutral Assistant Active Fallback Card */}
      <div className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <div className="flex items-center justify-between flex-wrap gap-3">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-[var(--color-accent)]/10 text-[var(--color-accent)] flex items-center justify-center flex-shrink-0">
              <Bot className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h2 className="text-base font-bold text-[var(--color-text-primary)]">
                  Neutral Assistant
                </h2>
                <Badge variant="success" size="sm">
                  Active Fallback
                </Badge>
              </div>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Available fallback / no persistent character selected
              </p>
            </div>
          </div>
          <div className="text-xs text-[var(--color-text-muted)] bg-[var(--color-surface-elevated)] px-3 py-1.5 rounded-xl border border-[var(--color-border-subtle)]">
            Single local instance • Profile-character assignment planned
          </div>
        </div>

        <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed bg-[var(--color-surface-sunken)] p-3.5 rounded-2xl border border-[var(--color-border-subtle)]">
          The Neutral Assistant provides standard system prompt steering without theatrical personality overrides.
          In the future architecture, user profiles will own personal memories, tasks, and conversations, while a preferred character will steer persona tone, voice ID, and visual presence.
        </p>
      </div>

      {/* 3. Architecture Specification Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Card A: Identity & Prompt */}
        <div className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <User className="w-4 h-4 text-[var(--color-accent)]" />
              <h3 className="text-sm font-semibold text-[var(--color-text-primary)]">
                1. Identity Layer
              </h3>
            </div>
            <Badge variant="neutral" size="sm">
              Planned Schema
            </Badge>
          </div>
          <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
            Defines who the companion is: stable ID, display name, description, and base persona prompt.
          </p>
          <div className="space-y-2.5 text-xs">
            <div className="p-3 rounded-xl surface-recessed border border-[var(--color-border-subtle)] space-y-1 font-mono text-[11px]">
              <div className="text-[var(--color-text-muted)]">// Character Manifest (Target)</div>
              <div>id: &quot;neutral-assistant&quot;</div>
              <div>display_name: &quot;Assistant&quot;</div>
              <div>persona_prompt: &quot;Helpful, factual, and concise companion.&quot;</div>
            </div>
          </div>
        </div>

        {/* Card B: Voice Configuration */}
        <div className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <Volume2 className="w-4 h-4 text-[var(--color-accent)]" />
              <h3 className="text-sm font-semibold text-[var(--color-text-primary)]">
                2. Voice Layer
              </h3>
            </div>
            <Badge variant="neutral" size="sm">
              Planned Subsystem
            </Badge>
          </div>
          <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
            Defines how the companion sounds: maps preferred voice identifier, pitch, rate, and speech synthesis engine hints without affecting user memory or identity.
          </p>
          <div className="p-3.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-secondary)] space-y-1.5">
            <div className="font-semibold text-[var(--color-text-primary)]">Decoupled Audio Architecture</div>
            <p className="text-[11px] text-[var(--color-text-muted)]">
              No voice engine or TTS synthesis is bundled in this phase. Speech synthesis engines (e.g. Piper, Kokoro) will attach to this slot in future audio phases.
            </p>
          </div>
        </div>

        {/* Card C: Visual Presence Layer */}
        <div className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <ImageIcon className="w-4 h-4 text-[var(--color-accent)]" />
              <h3 className="text-sm font-semibold text-[var(--color-text-primary)]">
                3. Presence Layer
              </h3>
            </div>
            <Badge variant="neutral" size="sm">
              Far Future Architecture
            </Badge>
          </div>
          <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
            Defines how the companion appears visually. Decoupled from memory, conversations, and personality.
          </p>
          <div className="grid grid-cols-2 gap-2 text-xs">
            <div className="p-2.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-center">
              <div className="font-medium text-[var(--color-text-primary)]">Static 2D</div>
              <div className="text-[10px] text-[var(--color-text-muted)]">Image / Portrait</div>
            </div>
            <div className="p-2.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-center">
              <div className="font-medium text-[var(--color-text-primary)]">Animated 2D</div>
              <div className="text-[10px] text-[var(--color-text-muted)]">GIF / WebP Sprite</div>
            </div>
            <div className="p-2.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-center">
              <div className="font-medium text-[var(--color-text-primary)]">2D Rigging</div>
              <div className="text-[10px] text-[var(--color-text-muted)]">Live2D / Kinematics</div>
            </div>
            <div className="p-2.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-center">
              <div className="font-medium text-[var(--color-text-primary)]">3D Avatar</div>
              <div className="text-[10px] text-[var(--color-text-muted)]">glTF / VRM Mesh</div>
            </div>
          </div>
        </div>

        {/* Card D: Safety & Alignment Constraints */}
        <div className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <Shield className="w-4 h-4 text-emerald-500" />
              <h3 className="text-sm font-semibold text-[var(--color-text-primary)]">
                4. Safety & Grounding Invariants
              </h3>
            </div>
            <Badge variant="success" size="sm">
              Enforced
            </Badge>
          </div>
          <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
            Character safety and factual grounding are strictly governed by core AI Companion runtime constraints.
            A personality preset or trait vector may modify tone, phrasing, and warmth, but must NEVER override system safety bounds, tool authorization, or airgap security.
          </p>
          <div className="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-xs text-emerald-600 dark:text-emerald-400">
            ✓ Airgapped execution invariants remain permanent across all character configurations.
          </div>
        </div>
      </div>

      {/* 4. Interactive Personality Trait Vector Wireframe Preview */}
      <div className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-6">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <div className="flex items-center gap-2 flex-wrap">
              <Sliders className="w-4 h-4 text-[var(--color-accent)]" />
              <h2 className="text-base font-bold text-[var(--color-text-primary)]">
                Personality Architecture Preview
              </h2>
              <Badge variant="neutral" size="sm">
                Continuous Trait Vector (0–100)
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
              Archetypes are convenience presets only. The underlying model is defined by continuous trait dimensions.
            </p>
          </div>
          <div className="text-xs text-[var(--color-text-muted)] italic">
            Preview only — not saved or applied to active model
          </div>
        </div>

        {/* Archetype Preset Selector */}
        <div className="space-y-2">
          <label className="text-xs font-semibold text-[var(--color-text-muted)] uppercase tracking-wider">
            Archetype Presets (Convenience Templates)
          </label>
          <div className="flex flex-wrap gap-2">
            {ARCHETYPE_PRESETS.map((preset) => (
              <button
                key={preset.id}
                type="button"
                onClick={() => setSelectedPreset(preset.id)}
                className={`px-3 py-1.5 rounded-xl text-xs font-medium border transition-all cursor-pointer ${
                  selectedPreset === preset.id
                    ? 'bg-[var(--color-accent)] text-white border-[var(--color-accent)] shadow-sm'
                    : 'surface-recessed border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:border-[var(--color-accent)]/50'
                }`}
              >
                {preset.label}
              </button>
            ))}
          </div>
        </div>

        {/* Continuous Trait Sliders (Visual Preview) */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-5 pt-2">
          {previewTraits.map((trait) => (
            <div
              key={trait.key}
              className="p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] space-y-2"
            >
              <div className="flex items-center justify-between text-xs">
                <span className="font-semibold text-[var(--color-text-primary)]">
                  {trait.name}
                </span>
                <span className="font-mono text-[var(--color-accent)] font-bold">
                  {trait.value}/100
                </span>
              </div>
              <input
                type="range"
                min="0"
                max="100"
                value={trait.value}
                onChange={(e) => handleTraitChange(trait.key, parseInt(e.target.value, 10))}
                className="w-full h-1.5 bg-[var(--color-surface-elevated)] rounded-lg appearance-none cursor-pointer accent-[var(--color-accent)]"
                title={`${trait.name} (Preview only)`}
              />
              <div className="flex justify-between text-[10px] text-[var(--color-text-muted)]">
                <span>{trait.lowLabel}</span>
                <span>{trait.highLabel}</span>
              </div>
            </div>
          ))}
        </div>

        <div className="p-4 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] flex items-center justify-between text-xs text-[var(--color-text-secondary)]">
          <div className="flex items-center gap-2">
            <Layers className="w-4 h-4 text-[var(--color-text-muted)]" />
            <span>Character persistence and profile switching will be wired in future persistent asset and profile phases.</span>
          </div>
          <Badge variant="neutral" size="sm">
            Read-Only Wireframe
          </Badge>
        </div>
      </div>
    </div>
  );
};
