import React, { useState } from 'react';
import {
  Palette,
  SlidersHorizontal,
  Bot,
  Volume2,
  Cpu,
  HeartPulse,
  Headphones,
  Network,
  Shield,
  Wrench,
  Search,
  CheckCircle2,
  Clock,
  Layers,
  Info,
} from 'lucide-react';
import { Badge } from '../ui/Badge';
import { SearchInput } from '../ui/SearchInput';
import { AppearanceSection } from './settings/AppearanceSection';
import { ApplicationStatesShowcase } from './states/ApplicationStatesShowcase';

export type SettingsSectionId =
  | 'appearance'
  | 'general'
  | 'assistant'
  | 'voice'
  | 'ai'
  | 'health'
  | 'devices'
  | 'network'
  | 'privacy'
  | 'advanced'
  | 'states';

interface SectionMenuItem {
  id: SettingsSectionId;
  label: string;
  icon: React.ReactNode;
  description: string;
  category: 'available' | 'planned' | 'preview';
  milestoneHint?: string;
  plannedDetails?: string;
}

const SECTIONS: SectionMenuItem[] = [
  // Available / Real Section
  {
    id: 'appearance',
    label: 'Appearance',
    icon: <Palette className="w-4 h-4" />,
    description: 'Theme preference, accent colors, effect intensity, interface density, and window glass styling',
    category: 'available',
  },

  // Planned Runtime / System Sections
  {
    id: 'general',
    label: 'General',
    icon: <SlidersHorizontal className="w-4 h-4" />,
    description: 'Operating system startup, tray minimization, and background lifecycle',
    category: 'planned',
    milestoneHint: 'Desktop Wrapper Milestone',
    plannedDetails:
      'Application startup behavior, background tray synchronization, and OS-level launch parameters will be managed by native runtime wrappers in future desktop releases.',
  },
  {
    id: 'assistant',
    label: 'Assistant',
    icon: <Bot className="w-4 h-4" />,
    description: 'Persona routing, prompt addenda, and grounding boundaries',
    category: 'planned',
    milestoneHint: 'Profile & Character Architecture',
    plannedDetails:
      'Assistant persona selection, custom system prompt addenda, and behavioral constraints will be managed through the Character Registry and user Profile layers.',
  },
  {
    id: 'voice',
    label: 'Voice',
    icon: <Volume2 className="w-4 h-4" />,
    description: 'TTS synthesis, STT transcription engine, and wake-word detection',
    category: 'planned',
    milestoneHint: 'Audio Subsystem Milestone',
    plannedDetails:
      'Speech-to-text engines (e.g. Whisper), text-to-speech voice models (e.g. Piper, Kokoro), wake-word listeners, and voice activity detection will be configured in dedicated audio phases.',
  },
  {
    id: 'ai',
    label: 'AI Runtime',
    icon: <Cpu className="w-4 h-4" />,
    description: 'Model library paths, execution engine, acceleration, and profile parameters',
    category: 'planned',
    milestoneHint: 'Phase 8P (Runtime Configuration)',
    plannedDetails:
      'Hardware acceleration backend (Vulkan/ROCm/CPU), GPU layer offloads, KV cache quantization, and COMPANION_DATA_ROOT model paths are formalized in Phase 8P configuration work.',
  },
  {
    id: 'health',
    label: 'Health',
    icon: <HeartPulse className="w-4 h-4" />,
    description: 'Wearable data synchronization, sample intervals, and metric aggregation',
    category: 'planned',
    milestoneHint: 'Health Connect Milestone',
    plannedDetails:
      'BLE fitness tracker pairing, Health Connect provider bridge, sleep metric analysis, and background biometric sampling will be wired in future health integrations.',
  },
  {
    id: 'devices',
    label: 'Devices & Audio',
    icon: <Headphones className="w-4 h-4" />,
    description: 'Hardware audio routing, buffer sizing, and Bluetooth peripherals',
    category: 'planned',
    milestoneHint: 'Audio Routing Subsystem',
    plannedDetails:
      'Hardware microphone selection, speaker output routing, audio buffer depths, and peripheral hotplug handling require native audio server integration.',
  },
  {
    id: 'network',
    label: 'Network & Mesh',
    icon: <Network className="w-4 h-4" />,
    description: 'Remote runtime gateway, LAN discovery, and encrypted ingress',
    category: 'planned',
    milestoneHint: 'Mesh Ingress Milestone',
    plannedDetails:
      'Remote companion runtime access, Tailscale peer connections, mTLS encryption keys, and LAN mesh ingress are future capabilities. The companion runtime currently binds strictly to localhost.',
  },
  {
    id: 'privacy',
    label: 'Privacy & Security',
    icon: <Shield className="w-4 h-4" />,
    description: 'Database encryption, automated PII redaction, and retention policies',
    category: 'planned',
    milestoneHint: 'Security & Enterprise Milestone',
    plannedDetails:
      'Full database-at-rest encryption, automated memory scrubbing rules, and audit retention schedules will be introduced alongside enterprise security profiles.',
  },
  {
    id: 'advanced',
    label: 'Advanced',
    icon: <Wrench className="w-4 h-4" />,
    description: 'Low-level engine flags, experimental feature toggles, and developer tooling',
    category: 'planned',
    milestoneHint: 'Phase 8P Advanced Subsystem',
    plannedDetails:
      'Low-level runtime compiler flags, llama.cpp context window adjustments, and developer debugging tools will be exposed via runtime configuration files.',
  },

  // UI/UX Showcase Section
  {
    id: 'states',
    label: 'Application States',
    icon: <Layers className="w-4 h-4" />,
    description: 'UI/UX state showcase',
    category: 'preview',
  },
];

export const SettingsView: React.FC = () => {
  // Active section — defaults to Appearance (the primary operational section)
  const [activeSection, setActiveSection] = useState<SettingsSectionId>('appearance');
  const [searchQuery, setSearchQuery] = useState('');

  // Filter sections by search query
  const filteredSections = SECTIONS.filter(
    (sec) =>
      sec.label.toLowerCase().includes(searchQuery.toLowerCase()) ||
      sec.description.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const currentSection = SECTIONS.find((s) => s.id === activeSection) || SECTIONS[0];

  return (
    <div id="settings-view" className="space-y-6 pb-12">
      {/* 1. Header Banner */}
      <div className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-2xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm flex-shrink-0 shadow-sm">
            <Palette className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2 flex-wrap">
              <h1 className="text-lg font-bold text-[var(--color-text-primary)]">
                Preferences & System Configuration
              </h1>
              <Badge variant="primary" size="sm">
                Appearance Active
              </Badge>
              <Badge variant="neutral" size="sm">
                Hybrid Truthfulness
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
              Client visual preferences and planned future runtime configurations.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs font-medium text-[var(--color-text-secondary)]">
            <CheckCircle2 className="w-3.5 h-3.5 text-emerald-500" />
            <span>Appearance preferences are stored in this browser</span>
          </div>
        </div>
      </div>

      {/* 2. Main Layout Grid (Navigation + Active Content) */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        {/* Left Navigation Sidebar */}
        <div className="lg:col-span-4 space-y-3 lg:sticky lg:top-2 self-start z-10">
          <div className="p-3 rounded-2xl surface-raised border border-[var(--color-border-subtle)] backdrop-blur-md">
            <SearchInput
              value={searchQuery}
              onChange={setSearchQuery}
              placeholder="Search preferences..."
              className="w-full text-xs"
            />
          </div>

          <nav
            aria-label="Settings navigation"
            className="p-2 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-1"
          >
            {filteredSections.map((section) => {
              const isActive = activeSection === section.id;
              return (
                <button
                  key={section.id}
                  type="button"
                  onClick={() => setActiveSection(section.id)}
                  className={`w-full flex items-start gap-3 p-3 rounded-xl transition-all text-left cursor-pointer ${
                    isActive
                      ? 'bg-[var(--color-accent)] text-white shadow-sm'
                      : 'hover:bg-[var(--color-surface-elevated)] text-[var(--color-text-primary)]'
                  }`}
                >
                  <div
                    className={`mt-0.5 flex-shrink-0 ${
                      isActive ? 'text-white' : 'text-[var(--color-accent)]'
                    }`}
                  >
                    {section.icon}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between gap-1.5">
                      <span className="text-xs font-semibold truncate">{section.label}</span>
                      {section.category === 'available' && (
                        <span
                          className={`text-[9px] px-1.5 py-0.2 rounded-full font-bold uppercase ${
                            isActive
                              ? 'bg-white/20 text-white'
                              : 'bg-emerald-500/15 text-emerald-600 dark:text-emerald-400'
                          }`}
                        >
                          Available
                        </span>
                      )}
                      {section.category === 'planned' && (
                        <span
                          className={`text-[9px] px-1.5 py-0.2 rounded-full font-semibold uppercase ${
                            isActive
                              ? 'bg-white/20 text-white'
                              : 'bg-[var(--color-surface-sunken)] text-[var(--color-text-muted)]'
                          }`}
                        >
                          Planned
                        </span>
                      )}
                      {section.category === 'preview' && (
                        <span
                          className={`text-[9px] px-1.5 py-0.2 rounded-full font-semibold uppercase ${
                            isActive
                              ? 'bg-white/20 text-white'
                              : 'bg-amber-500/15 text-amber-600 dark:text-amber-400'
                          }`}
                        >
                          Preview
                        </span>
                      )}
                    </div>
                    <p
                      className={`text-[11px] truncate mt-0.5 ${
                        isActive ? 'text-white/80' : 'text-[var(--color-text-muted)]'
                      }`}
                    >
                      {section.description}
                    </p>
                  </div>
                </button>
              );
            })}
          </nav>
        </div>

        {/* Right Active Content Area */}
        <div className="lg:col-span-8">
          {/* A. Real Active Appearance Section */}
          {activeSection === 'appearance' && (
            <div id="settings-appearance-container">
              <AppearanceSection />
            </div>
          )}

          {/* B. Preview Application States Showcase */}
          {activeSection === 'states' && (
            <div id="settings-states-container" className="space-y-4">
              <div className="p-4 rounded-2xl bg-amber-500/10 border border-amber-500/20 text-xs text-amber-700 dark:text-amber-300 flex items-center gap-2">
                <Info className="w-4 h-4 flex-shrink-0" />
                <span>
                  UI/UX State Showcase — Displays simulated error, loading, and empty layout states for design verification only.
                </span>
              </div>
              <ApplicationStatesShowcase />
            </div>
          )}

          {/* C. Truthful Planned Section Component */}
          {currentSection.category === 'planned' && (
            <div
              id={`settings-${currentSection.id}-planned`}
              className="p-6 sm:p-8 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-6 shadow-sm"
            >
              <div className="flex items-center justify-between flex-wrap gap-3 pb-4 border-b border-[var(--color-border-subtle)]">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-2xl bg-[var(--color-accent)]/10 text-[var(--color-accent)] flex items-center justify-center flex-shrink-0">
                    {currentSection.icon}
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <h2 className="text-base font-bold text-[var(--color-text-primary)]">
                        {currentSection.label} Configuration
                      </h2>
                      <Badge variant="neutral" size="sm">
                        Planned
                      </Badge>
                    </div>
                    <p className="text-xs text-[var(--color-text-secondary)]">
                      {currentSection.description}
                    </p>
                  </div>
                </div>

                {currentSection.milestoneHint && (
                  <Badge variant="primary" size="sm">
                    {currentSection.milestoneHint}
                  </Badge>
                )}
              </div>

              <div className="p-5 rounded-2xl bg-[var(--color-surface-sunken)] border border-[var(--color-border-subtle)] space-y-3">
                <div className="flex items-start gap-2.5">
                  <Info className="w-4 h-4 text-[var(--color-accent)] mt-0.5 flex-shrink-0" />
                  <div className="space-y-1.5 text-xs">
                    <div className="font-semibold text-[var(--color-text-primary)]">
                      Architecture Roadmap
                    </div>
                    <p className="text-[var(--color-text-secondary)] leading-relaxed">
                      {currentSection.plannedDetails}
                    </p>
                  </div>
                </div>
              </div>

              <div className="p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-muted)] space-y-2">
                <div className="font-medium text-[var(--color-text-primary)]">
                  Epistemic Truthfulness Notice
                </div>
                <p className="leading-relaxed">
                  Browser local storage is not used to simulate fake runtime state. Interactive parameters for this section will be enabled once the corresponding backend architecture is implemented.
                </p>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
