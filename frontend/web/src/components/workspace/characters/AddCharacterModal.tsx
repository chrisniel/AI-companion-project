import React, { useState } from 'react';
import { Plus, X, Sparkles, Check, Bot, ChevronDown } from 'lucide-react';
import { CharacterConfig, VoiceProvider, PersonalityStyle } from '../../../types';
import { Modal } from '../../ui/Modal';
import { NeumorphicButton } from '../../ui/NeumorphicButton';
import { AvatarPresentation } from './AvatarPresentation';
import { useTheme } from '../../../context/ThemeContext';

export interface AddCharacterModalProps {
  isOpen: boolean;
  onClose: () => void;
  onAddCharacter: (newChar: CharacterConfig) => void;
}

const TEMPLATES: Partial<CharacterConfig>[] = [
  {
    name: 'Athena',
    title: 'Research Scholar & Analyst',
    persona: 'Academic rigor, citation-oriented, and objective analytical synthesis. Evaluates hypothesis models with disciplined scrutiny.',
    systemPromptPreset: 'You are Athena, a research partner. Analyze technical papers, test hypotheses, and synthesize cross-domain literature with precision and verifiable references.',
    personalityStyle: 'analytical',
    voice: 'en_GB-alan-medium',
    voiceProvider: 'piper_local',
    avatarType: 'quantum_prism',
    avatarAccentColor: '#06b6d4',
  },
  {
    name: 'Cipher',
    title: 'Embedded Pair Programmer',
    persona: 'Focused purely on code generation, type correctness, algorithm efficiency, and minimal memory footprints.',
    systemPromptPreset: 'You are Cipher, an embedded systems engineer. Write concise, idiomatic, typed code with zero boilerplate or sycophancy.',
    personalityStyle: 'concise',
    voice: 'kokoro-am_adam',
    voiceProvider: 'kokoro_local',
    avatarType: 'geometric_orb',
    avatarAccentColor: '#6366f1',
  },
  {
    name: 'Echo',
    title: 'Mindful Wellness Companion',
    persona: 'Empathetic, restorative, and supportive. Emphasizes healthy posture, eye rests, circadian alignment, and stress mitigation.',
    systemPromptPreset: 'You are Echo, a gentle mindfulness guide. Provide compassionate feedback, suggest mindful breathing pauses, and preserve work-life equilibrium.',
    personalityStyle: 'warm_friendly',
    voice: 'en_US-amy-expressive',
    voiceProvider: 'piper_local',
    avatarType: 'pulse_ring',
    avatarAccentColor: '#10b981',
  },
];

export const AddCharacterModal: React.FC<AddCharacterModalProps> = ({
  isOpen,
  onClose,
  onAddCharacter,
}) => {
  const { mode } = useTheme();
  const [name, setName] = useState('');
  const [title, setTitle] = useState('');
  const [systemPrompt, setSystemPrompt] = useState('');
  const [personalityStyle, setPersonalityStyle] = useState<PersonalityStyle>('balanced');
  const [avatarType, setAvatarType] = useState<any>('hologram_core');
  const [avatarColor, setAvatarColor] = useState('#06b6d4');
  const [voice, setVoice] = useState('en_US-lessac-high');
  const [voiceProvider, setVoiceProvider] = useState<VoiceProvider>('piper_local');

  const handleApplyTemplate = (tmpl: Partial<CharacterConfig>) => {
    if (tmpl.name) setName(tmpl.name);
    if (tmpl.title) setTitle(tmpl.title);
    if (tmpl.systemPromptPreset) setSystemPrompt(tmpl.systemPromptPreset);
    if (tmpl.personalityStyle) setPersonalityStyle(tmpl.personalityStyle);
    if (tmpl.avatarType) setAvatarType(tmpl.avatarType);
    if (tmpl.avatarAccentColor) setAvatarColor(tmpl.avatarAccentColor);
    if (tmpl.voice) setVoice(tmpl.voice);
    if (tmpl.voiceProvider) setVoiceProvider(tmpl.voiceProvider);
  };

  const handleCreate = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;

    const newChar: CharacterConfig = {
      id: `char-${Date.now()}`,
      name: name.trim(),
      title: title.trim() || 'Custom Assistant Persona',
      status: 'idle',
      voice,
      voiceModelId: voice,
      voiceProvider,
      personality: systemPrompt.slice(0, 90) || 'Custom tailored assistant persona.',
      systemPromptPreset: systemPrompt.trim() || `You are ${name}, a helpful assistant running on the local cognitive core.`,
      personalityStyle,
      avatarType,
      avatarAccentColor: avatarColor,
      avatarDisplayMode: 'assistant_panel',
      speakingBehavior: {
        autoSpeak: true,
        interruptible: true,
        pitch: 1.0,
        rate: 1.0,
        pauseDurationMs: 200,
      },
      responsePreferences: {
        length: 'concise',
        style: 'bulleted',
        toneIntensity: 3,
      },
      isCustom: true,
    };

    onAddCharacter(newChar);
    onClose();
    // Reset fields
    setName('');
    setTitle('');
    setSystemPrompt('');
  };

  const previewDummyChar: CharacterConfig = {
    id: 'dummy',
    name: name || 'New Character',
    title: title || 'Persona Preview',
    status: 'idle',
    voice,
    personality: '',
    systemPromptPreset: '',
    avatarType,
    avatarAccentColor: avatarColor,
  };

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Create New Character Persona"
      maxWidth="max-w-2xl"
    >
      <form onSubmit={handleCreate} className="space-y-4">
        {/* Starter Templates */}
        <div>
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-semibold text-[var(--color-text-secondary)]">
              Quick Start Presets:
            </span>
            <span className="text-[10px] text-[var(--color-text-muted)] font-mono">
              Pre-tuned configurations
            </span>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
            {TEMPLATES.map((tmpl) => (
              <button
                key={tmpl.name}
                type="button"
                onClick={() => handleApplyTemplate(tmpl)}
                className="p-2.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] hover:border-[var(--color-border-strong)] text-left transition-all"
              >
                <div className="text-xs font-bold text-[var(--color-text-primary)]">
                  {tmpl.name}
                </div>
                <div className="text-[10px] text-[var(--color-text-muted)] truncate">
                  {tmpl.title}
                </div>
              </button>
            ))}
          </div>
        </div>

        {/* Live Mini Preview & Form Fields */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 pt-2 border-t border-[var(--color-border-subtle)]">
          {/* Avatar Preview Column */}
          <div className="flex flex-col items-center justify-center p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)]">
            <AvatarPresentation
              character={previewDummyChar}
              state="speaking"
              size="md"
            />
            <div className="text-xs font-bold text-[var(--color-text-primary)] mt-2">
              {name || 'Character Name'}
            </div>
            <div className="text-[10px] text-[var(--color-text-muted)] text-center truncate w-full">
              {title || 'Role Title'}
            </div>
          </div>

          {/* Core Info Column */}
          <div className="sm:col-span-2 space-y-3">
            <div>
              <label className="block text-xs font-medium text-[var(--color-text-secondary)] mb-1">
                Character Name *
              </label>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="e.g. Sentinel, Echo, Sol"
                required
                className="w-full px-3 py-1.5 rounded-xl surface-base border border-[var(--color-border-subtle)] text-sm text-[var(--color-text-primary)] focus:outline-none focus:border-[var(--color-accent)]"
              />
            </div>

            <div>
              <label className="block text-xs font-medium text-[var(--color-text-secondary)] mb-1">
                Role / Title
              </label>
              <input
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="e.g. Cognitive Systems Specialist"
                className="w-full px-3 py-1.5 rounded-xl surface-base border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] focus:outline-none focus:border-[var(--color-accent)]"
              />
            </div>

            <div className="grid grid-cols-2 gap-2">
              <div>
                <label className="block text-xs font-medium text-[var(--color-text-secondary)] mb-1">
                  Avatar Archetype
                </label>
                <div className="relative">
                  <select
                    value={avatarType}
                    onChange={(e) => setAvatarType(e.target.value as any)}
                    style={{ colorScheme: mode }}
                    className="w-full px-2.5 py-1.5 pr-7 rounded-xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] focus:outline-none appearance-none cursor-pointer"
                  >
                    <option value="hologram_core" className={mode === 'dark' ? 'bg-[#121824] text-slate-100' : 'bg-white text-slate-900'}>Hologram Core</option>
                    <option value="quantum_prism" className={mode === 'dark' ? 'bg-[#121824] text-slate-100' : 'bg-white text-slate-900'}>Quantum Prism</option>
                    <option value="geometric_orb" className={mode === 'dark' ? 'bg-[#121824] text-slate-100' : 'bg-white text-slate-900'}>Geometric Orb</option>
                    <option value="pulse_ring" className={mode === 'dark' ? 'bg-[#121824] text-slate-100' : 'bg-white text-slate-900'}>Pulse Ring</option>
                    <option value="sentient_glyph" className={mode === 'dark' ? 'bg-[#121824] text-slate-100' : 'bg-white text-slate-900'}>Sentient Glyph</option>
                  </select>
                  <ChevronDown className="w-3.5 h-3.5 text-[var(--color-text-muted)] absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none" />
                </div>
              </div>

              <div>
                <label className="block text-xs font-medium text-[var(--color-text-secondary)] mb-1">
                  Personality Style
                </label>
                <div className="relative">
                  <select
                    value={personalityStyle}
                    onChange={(e) => setPersonalityStyle(e.target.value as any)}
                    style={{ colorScheme: mode }}
                    className="w-full px-2.5 py-1.5 pr-7 rounded-xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] focus:outline-none appearance-none cursor-pointer capitalize"
                  >
                    <option value="balanced" className={mode === 'dark' ? 'bg-[#121824] text-slate-100' : 'bg-white text-slate-900'}>Balanced</option>
                    <option value="analytical" className={mode === 'dark' ? 'bg-[#121824] text-slate-100' : 'bg-white text-slate-900'}>Analytical</option>
                    <option value="concise" className={mode === 'dark' ? 'bg-[#121824] text-slate-100' : 'bg-white text-slate-900'}>Concise</option>
                    <option value="warm_friendly" className={mode === 'dark' ? 'bg-[#121824] text-slate-100' : 'bg-white text-slate-900'}>Warm & Friendly</option>
                    <option value="witty" className={mode === 'dark' ? 'bg-[#121824] text-slate-100' : 'bg-white text-slate-900'}>Witty</option>
                    <option value="formal" className={mode === 'dark' ? 'bg-[#121824] text-slate-100' : 'bg-white text-slate-900'}>Formal</option>
                  </select>
                  <ChevronDown className="w-3.5 h-3.5 text-[var(--color-text-muted)] absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none" />
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* System Prompt */}
        <div>
          <label className="block text-xs font-medium text-[var(--color-text-secondary)] mb-1">
            System Prompt Directive
          </label>
          <textarea
            rows={2}
            value={systemPrompt}
            onChange={(e) => setSystemPrompt(e.target.value)}
            placeholder="Define the primary personality and boundaries for this character..."
            className="w-full px-3 py-2 rounded-xl surface-base border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] font-mono resize-none focus:outline-none"
          />
        </div>

        {/* Footer Actions */}
        <div className="pt-3 border-t border-[var(--color-border-subtle)] flex items-center justify-end gap-2">
          <button
            type="button"
            onClick={onClose}
            className="px-3 py-1.5 rounded-xl surface-base border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]"
          >
            Cancel
          </button>
          <NeumorphicButton
            type="submit"
            size="sm"
            variant="primary"
            icon={<Plus className="w-3.5 h-3.5" />}
          >
            Add to Character Library
          </NeumorphicButton>
        </div>
      </form>
    </Modal>
  );
};
