import React, { useState } from 'react';
import {
  Save,
  RotateCcw,
  Bot,
  Volume2,
  Sliders,
  Sparkles,
  Layers,
  Palette,
  Check,
  AlertCircle,
  Play,
  Monitor,
  Layout,
  Maximize2,
  AppWindow,
  Globe,
  Languages,
  MessageCircle,
} from 'lucide-react';
import {
  CharacterConfig,
  VoiceProvider,
  PersonalityStyle,
  ResponseLengthPreference,
  ResponseStylePreference,
  AvatarDisplayMode,
  CharacterLanguageStyle,
  CodeSwitchingFrequency,
  TagalogParticleFrequency,
  JapaneseToneStyle,
} from '../../../types';
import { mockVoiceOptions, VoiceOption } from '../../../mock/characterData';
import { defaultCharacterLanguageStyles } from '../../../mock/multilingualData';
import { Card } from '../../ui/Card';
import { NeumorphicButton } from '../../ui/NeumorphicButton';
import { Toggle } from '../../ui/Toggle';
import { AvatarPresentation } from './AvatarPresentation';
import { Badge } from '../../ui/Badge';

export interface CharacterEditorProps {
  character: CharacterConfig;
  onSave: (updated: CharacterConfig) => void;
  onCancel?: () => void;
}

const AVATAR_COLOR_PALETTE = [
  { name: 'Electric Cyan', value: '#06b6d4' },
  { name: 'Indigo Core', value: '#6366f1' },
  { name: 'Emerald Focus', value: '#10b981' },
  { name: 'Amber Glow', value: '#f59e0b' },
  { name: 'Rose Empathy', value: '#f43f5e' },
  { name: 'Purple Neural', value: '#8b5cf6' },
];

export const CharacterEditor: React.FC<CharacterEditorProps> = ({
  character,
  onSave,
  onCancel,
}) => {
  // Local state for UI controls
  const [formData, setFormData] = useState<CharacterConfig>({ ...character });
  const [saveSuccess, setSaveSuccess] = useState(false);
  const [playingVoiceSampleId, setPlayingVoiceSampleId] = useState<string | null>(null);

  // Filter voices based on selected provider
  const availableVoices = mockVoiceOptions.filter(
    (v) => v.provider === (formData.voiceProvider || 'piper_local')
  );

  const handleProviderChange = (provider: VoiceProvider) => {
    const matchingVoice = mockVoiceOptions.find((v) => v.provider === provider);
    setFormData((prev) => ({
      ...prev,
      voiceProvider: provider,
      voice: matchingVoice ? matchingVoice.id : prev.voice,
      voiceModelId: matchingVoice ? matchingVoice.id : prev.voiceModelId,
    }));
  };

  const handleVoiceSelect = (voiceId: string) => {
    setFormData((prev) => ({
      ...prev,
      voice: voiceId,
      voiceModelId: voiceId,
    }));
  };

  const handlePlayVoiceSample = (voice: VoiceOption) => {
    setPlayingVoiceSampleId(voice.id);
    setTimeout(() => {
      setPlayingVoiceSampleId(null);
    }, 2400);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSave(formData);
    setSaveSuccess(true);
    setTimeout(() => setSaveSuccess(false), 2500);
  };

  const handleReset = () => {
    setFormData({ ...character });
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-5">
      <Card
        id="character-editor-card"
        variant="elevated"
        padding="lg"
        className="space-y-6"
      >
        {/* Editor Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-4 border-b border-[var(--color-border-subtle)]">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-2xl surface-raised flex items-center justify-center text-[var(--color-accent)] border border-[var(--color-border-subtle)] shadow-xs flex-shrink-0">
              <Bot className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h2 className="text-base font-bold text-[var(--color-text-primary)]">
                  Character & Persona Editor
                </h2>
                <Badge variant="accent" size="sm">
                  UI Configuration
                </Badge>
              </div>
              <p className="text-xs text-[var(--color-text-muted)]">
                Modify character identity, neural voice routing, and procedural avatar behaviors.
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={handleReset}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl surface-base border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] hover:border-[var(--color-border-strong)] transition-all"
            >
              <RotateCcw className="w-3.5 h-3.5" />
              <span>Reset</span>
            </button>
            <NeumorphicButton
              type="submit"
              size="sm"
              variant="primary"
              icon={saveSuccess ? <Check className="w-3.5 h-3.5" /> : <Save className="w-3.5 h-3.5" />}
            >
              {saveSuccess ? 'Saved!' : 'Save Persona'}
            </NeumorphicButton>
          </div>
        </div>

        {/* Section 1: Core Identity & Persona Backstory */}
        <div className="space-y-4">
          <div className="flex items-center gap-2 text-xs font-semibold text-[var(--color-text-secondary)] uppercase tracking-wider">
            <Bot className="w-3.5 h-3.5 text-[var(--color-accent)]" />
            <span>1. Identity & System Persona</span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {/* Display Name */}
            <div>
              <label className="block text-xs font-medium text-[var(--color-text-secondary)] mb-1.5">
                Character Display Name
              </label>
              <input
                type="text"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                placeholder="e.g. Aura, Chronos"
                className="w-full px-3.5 py-2 rounded-xl surface-base border border-[var(--color-border-subtle)] text-sm text-[var(--color-text-primary)] focus:outline-none focus:border-[var(--color-accent)] transition-all"
                required
              />
            </div>

            {/* Title / Role */}
            <div>
              <label className="block text-xs font-medium text-[var(--color-text-secondary)] mb-1.5">
                Role & Functional Title
              </label>
              <input
                type="text"
                value={formData.title}
                onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                placeholder="e.g. Cognitive Core Assistant"
                className="w-full px-3.5 py-2 rounded-xl surface-base border border-[var(--color-border-subtle)] text-sm text-[var(--color-text-primary)] focus:outline-none focus:border-[var(--color-accent)] transition-all"
              />
            </div>
          </div>

          {/* Persona System Prompt */}
          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label className="text-xs font-medium text-[var(--color-text-secondary)]">
                Persona Directive & System Prompt Backstory
              </label>
              <span className="text-[10px] text-[var(--color-text-muted)] font-mono">
                Injected into context window
              </span>
            </div>
            <textarea
              rows={3}
              value={formData.systemPromptPreset}
              onChange={(e) => setFormData({ ...formData, systemPromptPreset: e.target.value })}
              className="w-full px-3.5 py-2.5 rounded-xl surface-base border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] font-mono leading-relaxed focus:outline-none focus:border-[var(--color-accent)] transition-all resize-y"
              placeholder="Define core role boundaries, behavioral directives, and tone constraints..."
            />
          </div>

          {/* Response Personality Style */}
          <div>
            <label className="block text-xs font-medium text-[var(--color-text-secondary)] mb-1.5">
              Response Personality Archetype
            </label>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 gap-2">
              {[
                { id: 'analytical', label: 'Analytical', hint: 'Rigorous & direct' },
                { id: 'balanced', label: 'Balanced', hint: 'Adaptable helper' },
                { id: 'concise', label: 'Concise', hint: 'Short & minimal' },
                { id: 'warm_friendly', label: 'Warm', hint: 'Empathetic & supportive' },
                { id: 'witty', label: 'Witty', hint: 'Engaging & clever' },
                { id: 'formal', label: 'Formal', hint: 'Executive protocol' },
              ].map((style) => (
                <button
                  key={style.id}
                  type="button"
                  onClick={() => setFormData({ ...formData, personalityStyle: style.id as PersonalityStyle })}
                  className={`p-2 rounded-xl border text-left transition-all ${
                    formData.personalityStyle === style.id
                      ? 'surface-raised border-[var(--color-accent)] shadow-xs ring-1 ring-[var(--color-accent)]/30'
                      : 'surface-base border-[var(--color-border-subtle)] hover:border-[var(--color-border-strong)] opacity-85 hover:opacity-100'
                  }`}
                >
                  <div className="text-xs font-bold text-[var(--color-text-primary)]">
                    {style.label}
                  </div>
                  <div className="text-[10px] text-[var(--color-text-muted)] truncate">
                    {style.hint}
                  </div>
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Section 2: Neural Voice Provider & Selection */}
        <div className="space-y-4 pt-4 border-t border-[var(--color-border-subtle)]">
          <div className="flex items-center gap-2 text-xs font-semibold text-[var(--color-text-secondary)] uppercase tracking-wider">
            <Volume2 className="w-3.5 h-3.5 text-emerald-500" />
            <span>2. Neural Voice & Speech Synthesis</span>
          </div>

          {/* Voice Providers Selection */}
          <div className="grid grid-cols-1 sm:grid-cols-4 gap-2.5">
            {[
              {
                id: 'piper_local',
                name: 'Piper TTS',
                badge: 'Local Fast',
                desc: '<15ms latency • Embedded ONNX',
              },
              {
                id: 'kokoro_local',
                name: 'Kokoro-82M',
                badge: 'Local Studio',
                desc: '82M params • High Fidelity',
              },
              {
                id: 'system_tts',
                name: 'System Native',
                badge: 'OS Audio',
                desc: 'Zero memory overhead',
              },
              {
                id: 'elevenlabs_cloud',
                name: 'ElevenLabs',
                badge: 'Cloud Studio',
                desc: 'API fallback stream',
              },
            ].map((p) => (
              <button
                key={p.id}
                type="button"
                onClick={() => handleProviderChange(p.id as VoiceProvider)}
                className={`p-3 rounded-2xl border text-left transition-all flex flex-col justify-between ${
                  formData.voiceProvider === p.id
                    ? 'surface-raised border-emerald-500 ring-1 ring-emerald-500/30 shadow-xs'
                    : 'surface-base border-[var(--color-border-subtle)] hover:border-[var(--color-border-strong)] opacity-85 hover:opacity-100'
                }`}
              >
                <div className="flex items-center justify-between mb-1">
                  <span className="text-xs font-bold text-[var(--color-text-primary)]">
                    {p.name}
                  </span>
                  <span className="text-[9px] px-1.5 py-0.5 rounded-full surface-recessed text-emerald-500 border border-emerald-500/20 font-mono">
                    {p.badge}
                  </span>
                </div>
                <p className="text-[10px] text-[var(--color-text-muted)]">
                  {p.desc}
                </p>
              </button>
            ))}
          </div>

          {/* Available Voices Grid */}
          <div className="space-y-2">
            <label className="block text-xs font-medium text-[var(--color-text-secondary)]">
              Select Voice Model ({availableVoices.length} Available)
            </label>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
              {availableVoices.map((voice) => {
                const isSelected = formData.voice === voice.id;
                const isPlaying = playingVoiceSampleId === voice.id;
                return (
                  <div
                    key={voice.id}
                    onClick={() => handleVoiceSelect(voice.id)}
                    className={`p-3 rounded-2xl border cursor-pointer transition-all flex items-center justify-between gap-3 ${
                      isSelected
                        ? 'surface-raised border-[var(--color-accent)] ring-1 ring-[var(--color-accent)]/20 shadow-xs'
                        : 'surface-base border-[var(--color-border-subtle)] hover:border-[var(--color-border-strong)]'
                    }`}
                  >
                    <div className="min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="text-xs font-bold text-[var(--color-text-primary)] truncate">
                          {voice.name}
                        </span>
                        <span className="text-[10px] text-[var(--color-text-muted)] font-mono capitalize">
                          {voice.gender} • {voice.accent}
                        </span>
                      </div>
                      <div className="text-[10px] text-[var(--color-text-muted)] truncate italic mt-0.5">
                        &ldquo;{voice.sampleText}&rdquo;
                      </div>
                    </div>

                    <button
                      type="button"
                      onClick={(e) => {
                        e.stopPropagation();
                        handlePlayVoiceSample(voice);
                      }}
                      title="Preview Voice Sample"
                      className={`p-1.5 rounded-lg border flex-shrink-0 transition-all ${
                        isPlaying
                          ? 'bg-[var(--color-accent)] text-white border-[var(--color-accent)] animate-pulse'
                          : 'surface-recessed text-[var(--color-text-secondary)] border-[var(--color-border-subtle)] hover:text-[var(--color-text-primary)]'
                      }`}
                    >
                      <Play className="w-3.5 h-3.5" />
                    </button>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Speaking Behavior Sliders */}
          <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-3">
            <div className="flex items-center justify-between text-xs">
              <span className="font-semibold text-[var(--color-text-secondary)] flex items-center gap-1.5">
                <Sliders className="w-3.5 h-3.5 text-[var(--color-accent)]" />
                <span>Speaking Dynamics & Telemetry</span>
              </span>
              <div className="flex items-center gap-3">
                <label className="flex items-center gap-1.5 text-xs text-[var(--color-text-secondary)] cursor-pointer">
                  <input
                    type="checkbox"
                    checked={formData.speakingBehavior?.autoSpeak ?? true}
                    onChange={(e) =>
                      setFormData({
                        ...formData,
                        speakingBehavior: {
                          autoSpeak: e.target.checked,
                          interruptible: formData.speakingBehavior?.interruptible ?? true,
                          pitch: formData.speakingBehavior?.pitch ?? 1.0,
                          rate: formData.speakingBehavior?.rate ?? 1.0,
                          pauseDurationMs: formData.speakingBehavior?.pauseDurationMs ?? 200,
                        },
                      })
                    }
                    className="rounded accent-[var(--color-accent)]"
                  />
                  <span>Auto-Speak Responses</span>
                </label>

                <label className="flex items-center gap-1.5 text-xs text-[var(--color-text-secondary)] cursor-pointer">
                  <input
                    type="checkbox"
                    checked={formData.speakingBehavior?.interruptible ?? true}
                    onChange={(e) =>
                      setFormData({
                        ...formData,
                        speakingBehavior: {
                          autoSpeak: formData.speakingBehavior?.autoSpeak ?? true,
                          interruptible: e.target.checked,
                          pitch: formData.speakingBehavior?.pitch ?? 1.0,
                          rate: formData.speakingBehavior?.rate ?? 1.0,
                          pauseDurationMs: formData.speakingBehavior?.pauseDurationMs ?? 200,
                        },
                      })
                    }
                    className="rounded accent-[var(--color-accent)]"
                  />
                  <span>Interruptible</span>
                </label>
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 pt-2">
              {/* Pitch Slider */}
              <div>
                <div className="flex justify-between text-[11px] font-mono text-[var(--color-text-muted)] mb-1">
                  <span>Voice Pitch</span>
                  <span className="text-[var(--color-text-primary)] font-bold">
                    {(formData.speakingBehavior?.pitch ?? 1.0).toFixed(2)}x
                  </span>
                </div>
                <input
                  type="range"
                  min="0.75"
                  max="1.25"
                  step="0.05"
                  value={formData.speakingBehavior?.pitch ?? 1.0}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      speakingBehavior: {
                        autoSpeak: formData.speakingBehavior?.autoSpeak ?? true,
                        interruptible: formData.speakingBehavior?.interruptible ?? true,
                        pitch: parseFloat(e.target.value),
                        rate: formData.speakingBehavior?.rate ?? 1.0,
                        pauseDurationMs: formData.speakingBehavior?.pauseDurationMs ?? 200,
                      },
                    })
                  }
                  className="w-full accent-[var(--color-accent)] h-1.5 surface-recessed rounded-lg cursor-pointer"
                />
              </div>

              {/* Rate Slider */}
              <div>
                <div className="flex justify-between text-[11px] font-mono text-[var(--color-text-muted)] mb-1">
                  <span>Speaking Rate</span>
                  <span className="text-[var(--color-text-primary)] font-bold">
                    {(formData.speakingBehavior?.rate ?? 1.0).toFixed(2)}x
                  </span>
                </div>
                <input
                  type="range"
                  min="0.75"
                  max="1.4"
                  step="0.05"
                  value={formData.speakingBehavior?.rate ?? 1.0}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      speakingBehavior: {
                        autoSpeak: formData.speakingBehavior?.autoSpeak ?? true,
                        interruptible: formData.speakingBehavior?.interruptible ?? true,
                        pitch: formData.speakingBehavior?.pitch ?? 1.0,
                        rate: parseFloat(e.target.value),
                        pauseDurationMs: formData.speakingBehavior?.pauseDurationMs ?? 200,
                      },
                    })
                  }
                  className="w-full accent-[var(--color-accent)] h-1.5 surface-recessed rounded-lg cursor-pointer"
                />
              </div>

              {/* Sentence Pause Slider */}
              <div>
                <div className="flex justify-between text-[11px] font-mono text-[var(--color-text-muted)] mb-1">
                  <span>Pause Cadence</span>
                  <span className="text-[var(--color-text-primary)] font-bold">
                    {formData.speakingBehavior?.pauseDurationMs ?? 200}ms
                  </span>
                </div>
                <input
                  type="range"
                  min="100"
                  max="500"
                  step="25"
                  value={formData.speakingBehavior?.pauseDurationMs ?? 200}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      speakingBehavior: {
                        autoSpeak: formData.speakingBehavior?.autoSpeak ?? true,
                        interruptible: formData.speakingBehavior?.interruptible ?? true,
                        pitch: formData.speakingBehavior?.pitch ?? 1.0,
                        rate: formData.speakingBehavior?.rate ?? 1.0,
                        pauseDurationMs: parseInt(e.target.value, 10),
                      },
                    })
                  }
                  className="w-full accent-[var(--color-accent)] h-1.5 surface-recessed rounded-lg cursor-pointer"
                />
              </div>
            </div>
          </div>
        </div>

        {/* Section 3: Avatar Archetype, Palette & Display Mode */}
        <div className="space-y-4 pt-4 border-t border-[var(--color-border-subtle)]">
          <div className="flex items-center gap-2 text-xs font-semibold text-[var(--color-text-secondary)] uppercase tracking-wider">
            <Palette className="w-3.5 h-3.5 text-[var(--color-accent)]" />
            <span>3. Procedural Avatar & Display Surface</span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {/* Avatar Geometry Archetype */}
            <div>
              <label className="block text-xs font-medium text-[var(--color-text-secondary)] mb-1.5">
                Geometric Avatar Archetype
              </label>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                {[
                  { id: 'hologram_core', label: 'Hologram Core' },
                  { id: 'quantum_prism', label: 'Quantum Prism' },
                  { id: 'geometric_orb', label: 'Geometric Orb' },
                  { id: 'pulse_ring', label: 'Pulse Ring' },
                  { id: 'sentient_glyph', label: 'Sentient Glyph' },
                ].map((item) => (
                  <button
                    key={item.id}
                    type="button"
                    onClick={() =>
                      setFormData({
                        ...formData,
                        avatarType: item.id as any,
                      })
                    }
                    className={`p-2 rounded-xl border text-center transition-all text-xs font-medium ${
                      formData.avatarType === item.id
                        ? 'surface-raised border-[var(--color-accent)] text-[var(--color-text-primary)] shadow-xs ring-1 ring-[var(--color-accent)]/30 font-bold'
                        : 'surface-base border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:border-[var(--color-border-strong)]'
                    }`}
                  >
                    {item.label}
                  </button>
                ))}
              </div>
            </div>

            {/* Accent Color Palette */}
            <div>
              <label className="block text-xs font-medium text-[var(--color-text-secondary)] mb-1.5">
                Core Shading & Accent Palette
              </label>
              <div className="flex flex-wrap gap-2.5 pt-1">
                {AVATAR_COLOR_PALETTE.map((c) => {
                  const isSelected = formData.avatarAccentColor === c.value;
                  return (
                    <button
                      key={c.value}
                      type="button"
                      onClick={() => setFormData({ ...formData, avatarAccentColor: c.value })}
                      title={c.name}
                      className={`w-8 h-8 rounded-full border-2 transition-all flex items-center justify-center ${
                        isSelected
                          ? 'border-[var(--color-text-primary)] scale-110 shadow-sm'
                          : 'border-transparent hover:scale-105'
                      }`}
                      style={{ backgroundColor: c.value }}
                    >
                      {isSelected && <Check className="w-3.5 h-3.5 text-white drop-shadow-sm" />}
                    </button>
                  );
                })}
              </div>
            </div>
          </div>

          {/* AVATAR DISPLAY: Disabled, Assistant Panel, Large, Future Floating Mode */}
          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label className="text-xs font-medium text-[var(--color-text-secondary)]">
                Avatar Display Surface
              </label>
              <span className="text-[10px] text-[var(--color-text-muted)] font-mono">
                Placement routing
              </span>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-4 gap-2.5">
              {[
                {
                  id: 'disabled',
                  title: 'Disabled',
                  desc: 'Avatar hidden in standard views',
                  icon: Monitor,
                },
                {
                  id: 'assistant_panel',
                  title: 'Assistant Panel',
                  desc: 'Docked in side companion panel',
                  icon: Layout,
                },
                {
                  id: 'large',
                  title: 'Large Canvas',
                  desc: 'Prominent center workspace stage',
                  icon: Maximize2,
                },
                {
                  id: 'future_floating_mode',
                  title: 'Future Floating',
                  desc: 'Mock desktop overlay bridge',
                  icon: AppWindow,
                  isMockBadge: true,
                },
              ].map((mode) => {
                const isSelected = (formData.avatarDisplayMode || 'assistant_panel') === mode.id;
                const ModeIcon = mode.icon;
                return (
                  <button
                    key={mode.id}
                    type="button"
                    onClick={() => setFormData({ ...formData, avatarDisplayMode: mode.id as AvatarDisplayMode })}
                    className={`p-3 rounded-2xl border text-left transition-all flex flex-col justify-between ${
                      isSelected
                        ? 'surface-raised border-[var(--color-accent)] ring-1 ring-[var(--color-accent)]/30 shadow-xs'
                        : 'surface-base border-[var(--color-border-subtle)] hover:border-[var(--color-border-strong)] opacity-85 hover:opacity-100'
                    }`}
                  >
                    <div className="flex items-start justify-between mb-1.5">
                      <div className="flex items-center gap-2">
                        <ModeIcon className={`w-4 h-4 ${isSelected ? 'text-[var(--color-accent)]' : 'text-[var(--color-text-muted)]'}`} />
                        <span className="text-xs font-bold text-[var(--color-text-primary)]">
                          {mode.title}
                        </span>
                      </div>
                      {mode.isMockBadge && (
                        <span className="text-[9px] px-1.5 py-0.5 rounded-full surface-recessed text-amber-500 border border-amber-500/20 font-mono">
                          Bridge
                        </span>
                      )}
                    </div>
                    <p className="text-[10px] text-[var(--color-text-muted)] leading-tight">
                      {mode.desc}
                    </p>
                  </button>
                );
              })}
            </div>
          </div>
        </div>

        {/* Section 4: Response Length & Format Preferences */}
        <div className="space-y-3 pt-4 border-t border-[var(--color-border-subtle)]">
          <div className="flex items-center gap-2 text-xs font-semibold text-[var(--color-text-secondary)] uppercase tracking-wider">
            <Sparkles className="w-3.5 h-3.5 text-amber-500" />
            <span>4. Output Length & Formatting Style</span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {/* Length */}
            <div>
              <label className="block text-xs font-medium text-[var(--color-text-secondary)] mb-1.5">
                Target Response Verbosity
              </label>
              <div className="grid grid-cols-3 gap-2">
                {(['concise', 'balanced', 'thorough'] as ResponseLengthPreference[]).map((len) => (
                  <button
                    key={len}
                    type="button"
                    onClick={() =>
                      setFormData({
                        ...formData,
                        responsePreferences: {
                          length: len,
                          style: formData.responsePreferences?.style ?? 'bulleted',
                          toneIntensity: formData.responsePreferences?.toneIntensity ?? 3,
                        },
                      })
                    }
                    className={`p-2 rounded-xl border text-center capitalize text-xs font-medium transition-all ${
                      (formData.responsePreferences?.length ?? 'concise') === len
                        ? 'surface-raised border-[var(--color-accent)] font-bold text-[var(--color-text-primary)] shadow-xs'
                        : 'surface-base border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:border-[var(--color-border-strong)]'
                    }`}
                  >
                    {len}
                  </button>
                ))}
              </div>
            </div>

            {/* Format */}
            <div>
              <label className="block text-xs font-medium text-[var(--color-text-secondary)] mb-1.5">
                Presentation Formatting
              </label>
              <div className="grid grid-cols-3 gap-2">
                {[
                  { id: 'bulleted', label: 'Bullet Lists' },
                  { id: 'natural', label: 'Conversational' },
                  { id: 'code_first', label: 'Code-First' },
                ].map((fmt) => (
                  <button
                    key={fmt.id}
                    type="button"
                    onClick={() =>
                      setFormData({
                        ...formData,
                        responsePreferences: {
                          length: formData.responsePreferences?.length ?? 'concise',
                          style: fmt.id as ResponseStylePreference,
                          toneIntensity: formData.responsePreferences?.toneIntensity ?? 3,
                        },
                      })
                    }
                    className={`p-2 rounded-xl border text-center text-xs font-medium transition-all ${
                      (formData.responsePreferences?.style ?? 'bulleted') === fmt.id
                        ? 'surface-raised border-[var(--color-accent)] font-bold text-[var(--color-text-primary)] shadow-xs'
                        : 'surface-base border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:border-[var(--color-border-strong)]'
                    }`}
                  >
                    {fmt.label}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>

        {/* Section 5: BATCH 12.1 Multilingual Persona Language Style */}
        {(() => {
          const langStyle: CharacterLanguageStyle =
            formData.languageStyle ||
            defaultCharacterLanguageStyles[formData.id] ||
            defaultCharacterLanguageStyles['p-1'];

          const updateLanguageStyle = <K extends keyof CharacterLanguageStyle>(
            key: K,
            value: CharacterLanguageStyle[K]
          ) => {
            setFormData((prev) => ({
              ...prev,
              languageStyle: {
                ...(prev.languageStyle ||
                  defaultCharacterLanguageStyles[prev.id] ||
                  defaultCharacterLanguageStyles['p-1']),
                [key]: value,
              },
            }));
          };

          const toggleSecondaryLang = (code: 'en' | 'fil' | 'ja') => {
            const current = langStyle.secondaryLanguages || [];
            if (current.includes(code)) {
              updateLanguageStyle('secondaryLanguages', current.filter((c) => c !== code));
            } else {
              updateLanguageStyle('secondaryLanguages', [...current, code]);
            }
          };

          return (
            <div className="space-y-4 pt-4 border-t border-[var(--color-border-subtle)]">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2 text-xs font-semibold text-[var(--color-text-secondary)] uppercase tracking-wider">
                  <Globe className="w-3.5 h-3.5 text-[var(--color-accent)]" />
                  <span>5. Multilingual & Character Language Style</span>
                </div>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[var(--color-accent)]/10 text-[var(--color-accent)] font-semibold">
                  Batch 12.1
                </span>
              </div>

              {/* Primary Persona Language & Match User Language */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-medium text-[var(--color-text-secondary)] mb-1.5">
                    Character Default Speaking Language
                  </label>
                  <div className="grid grid-cols-2 gap-2">
                    {[
                      { id: 'en' as const, label: 'English', flag: '🇺🇸' },
                      { id: 'fil' as const, label: 'Filipino / Tagalog', flag: '🇵🇭' },
                      { id: 'ja' as const, label: 'Japanese (日本語)', flag: '🇯🇵' },
                      { id: 'match_user' as const, label: 'Match User Input', flag: '🪞' },
                    ].map((item) => (
                      <button
                        key={item.id}
                        type="button"
                        onClick={() => updateLanguageStyle('primaryLanguage', item.id)}
                        className={`p-2 rounded-xl border text-left text-xs font-medium transition-all flex items-center gap-2 ${
                          langStyle.primaryLanguage === item.id
                            ? 'surface-raised border-[var(--color-accent)] text-[var(--color-text-primary)] font-bold shadow-xs'
                            : 'surface-base border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:border-[var(--color-border-strong)]'
                        }`}
                      >
                        <span className="text-sm">{item.flag}</span>
                        <span className="truncate">{item.label}</span>
                      </button>
                    ))}
                  </div>
                </div>

                {/* Secondary Languages */}
                <div>
                  <label className="block text-xs font-medium text-[var(--color-text-secondary)] mb-1.5">
                    Permitted Secondary Languages
                  </label>
                  <div className="flex flex-wrap gap-2 pt-1">
                    {[
                      { code: 'en' as const, name: 'English (en)', flag: '🇺🇸' },
                      { code: 'fil' as const, name: 'Filipino (fil)', flag: '🇵🇭' },
                      { code: 'ja' as const, name: 'Japanese (ja)', flag: '🇯🇵' },
                    ].map((lang) => {
                      const isChecked = (langStyle.secondaryLanguages || []).includes(lang.code);
                      return (
                        <button
                          key={lang.code}
                          type="button"
                          onClick={() => toggleSecondaryLang(lang.code)}
                          className={`px-3 py-1.5 rounded-xl border text-xs font-medium flex items-center gap-1.5 transition-all ${
                            isChecked
                              ? 'border-[var(--color-accent)] bg-[var(--color-accent)]/10 text-[var(--color-accent)] font-semibold shadow-xs'
                              : 'surface-base border-[var(--color-border-subtle)] text-[var(--color-text-secondary)]'
                          }`}
                        >
                          <span>{lang.flag}</span>
                          <span>{lang.name}</span>
                          {isChecked && <Check className="w-3 h-3 ml-1" />}
                        </button>
                      );
                    })}
                  </div>
                </div>
              </div>

              {/* Match User Language Toggle */}
              <div className="flex items-center justify-between p-3 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)]">
                <div>
                  <span className="text-xs font-semibold text-[var(--color-text-primary)] block">
                    Adapt Persona Language to Match Incoming User Language
                  </span>
                  <p className="text-[11px] text-[var(--color-text-secondary)]">
                    When active, Iris/Marcus will automatically reply in Tagalog, Japanese, or English if the user addresses them in that language.
                  </p>
                </div>
                <Toggle
                  checked={langStyle.matchUserLanguage}
                  onChange={(val) => updateLanguageStyle('matchUserLanguage', val)}
                  size="sm"
                />
              </div>

              {/* Code-Switching & Particle Frequencies */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-1">
                {/* Code-Switching Frequency */}
                <div>
                  <label className="block text-xs font-medium text-[var(--color-text-secondary)] mb-1.5">
                    Code-Switching Frequency
                  </label>
                  <div className="grid grid-cols-2 gap-1.5">
                    {(['never', 'rare', 'natural', 'frequent'] as CodeSwitchingFrequency[]).map((freq) => (
                      <button
                        key={freq}
                        type="button"
                        onClick={() => updateLanguageStyle('codeSwitchingFrequency', freq)}
                        className={`p-1.5 rounded-lg border text-center capitalize text-[11px] transition-all ${
                          langStyle.codeSwitchingFrequency === freq
                            ? 'surface-raised border-[var(--color-accent)] text-[var(--color-text-primary)] font-bold shadow-xs'
                            : 'surface-base border-[var(--color-border-subtle)] text-[var(--color-text-secondary)]'
                        }`}
                      >
                        {freq}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Tagalog Colloquial Particles */}
                <div>
                  <label className="block text-xs font-medium text-[var(--color-text-secondary)] mb-1.5">
                    Tagalog Nuance & Particles
                  </label>
                  <div className="grid grid-cols-1 gap-1.5">
                    {[
                      { id: 'minimal' as const, label: 'Minimal (Formal PH)' },
                      { id: 'natural' as const, label: 'Natural (po, naman, pala)' },
                      { id: 'colloquial' as const, label: 'Colloquial (Conversational)' },
                    ].map((item) => (
                      <button
                        key={item.id}
                        type="button"
                        onClick={() => updateLanguageStyle('tagalogParticleFrequency', item.id)}
                        className={`p-1.5 px-2 rounded-lg border text-left text-[11px] transition-all truncate ${
                          langStyle.tagalogParticleFrequency === item.id
                            ? 'surface-raised border-[var(--color-accent)] text-[var(--color-text-primary)] font-bold shadow-xs'
                            : 'surface-base border-[var(--color-border-subtle)] text-[var(--color-text-secondary)]'
                        }`}
                      >
                        {item.label}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Japanese Conversational Tone */}
                <div>
                  <label className="block text-xs font-medium text-[var(--color-text-secondary)] mb-1.5">
                    Japanese Conversational Tone
                  </label>
                  <div className="grid grid-cols-1 gap-1.5">
                    {[
                      { id: 'polite_desu_masu' as const, label: 'Polite (です/ます)' },
                      { id: 'warm_conversational' as const, label: 'Warm Conversational' },
                      { id: 'casual_teineigo' as const, label: 'Casual Friendly' },
                      { id: 'business_keigo' as const, label: 'Business Keigo (敬語)' },
                    ].map((item) => (
                      <button
                        key={item.id}
                        type="button"
                        onClick={() => updateLanguageStyle('japaneseTone', item.id)}
                        className={`p-1.5 px-2 rounded-lg border text-left text-[11px] transition-all truncate ${
                          langStyle.japaneseTone === item.id
                            ? 'surface-raised border-[var(--color-accent)] text-[var(--color-text-primary)] font-bold shadow-xs'
                            : 'surface-base border-[var(--color-border-subtle)] text-[var(--color-text-secondary)]'
                        }`}
                      >
                        {item.label}
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          );
        })()}

        {/* Footer Actions */}
        <div className="pt-4 border-t border-[var(--color-border-subtle)] flex items-center justify-between">
          <div className="text-[11px] text-[var(--color-text-muted)] flex items-center gap-1.5">
            <AlertCircle className="w-3.5 h-3.5 text-[var(--color-accent)]" />
            <span>Characters are modular configuration profiles decoupled from execution runtimes.</span>
          </div>

          <div className="flex items-center gap-2">
            {onCancel && (
              <button
                type="button"
                onClick={onCancel}
                className="px-3 py-1.5 rounded-xl surface-base border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] transition-all"
              >
                Cancel
              </button>
            )}
            <NeumorphicButton
              type="submit"
              size="sm"
              variant="primary"
              icon={saveSuccess ? <Check className="w-3.5 h-3.5" /> : <Save className="w-3.5 h-3.5" />}
            >
              {saveSuccess ? 'Changes Applied' : 'Save Configuration'}
            </NeumorphicButton>
          </div>
        </div>
      </Card>
    </form>
  );
};
