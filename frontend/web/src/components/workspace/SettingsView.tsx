import React, { useState, useEffect } from 'react';
import {
  Settings,
  SlidersHorizontal,
  Palette,
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
  RotateCcw,
  Layers,
} from 'lucide-react';
import { Badge } from '../ui/Badge';
import { SearchInput } from '../ui/SearchInput';
import { useTheme } from '../../context/ThemeContext';

// Sub-sections
import { GeneralSection, GeneralSettingsState } from './settings/GeneralSection';
import { AppearanceSection } from './settings/AppearanceSection';
import { AssistantSection, AssistantSettingsState } from './settings/AssistantSection';
import { VoiceSection, VoiceSettingsState } from './settings/VoiceSection';
import { AiSection, AiSettingsState } from './settings/AiSection';
import { HealthSection, HealthSettingsState } from './settings/HealthSection';
import { DevicesSection, DeviceSettingsState } from './settings/DevicesSection';
import { NetworkSection, NetworkSettingsState } from './settings/NetworkSection';
import { PrivacySection, PrivacySettingsState } from './settings/PrivacySection';
import { AdvancedSection, AdvancedSettingsState } from './settings/AdvancedSection';
import { ApplicationStatesShowcase } from './states/ApplicationStatesShowcase';

export type SettingsSectionId =
  | 'general'
  | 'appearance'
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
}

const SECTIONS: SectionMenuItem[] = [
  {
    id: 'general',
    label: 'General',
    icon: <SlidersHorizontal className="w-4 h-4" />,
    description: 'Startup behavior, language, timezone',
  },
  {
    id: 'appearance',
    label: 'Appearance',
    icon: <Palette className="w-4 h-4" />,
    description: 'Light/Dark, accent presets, effect intensity, animations, density',
  },
  {
    id: 'assistant',
    label: 'Assistant',
    icon: <Bot className="w-4 h-4" />,
    description: 'Default character, behavior preferences',
  },
  {
    id: 'voice',
    label: 'Voice',
    icon: <Volume2 className="w-4 h-4" />,
    description: 'TTS provider, STT provider, listening mode, audio behavior',
  },
  {
    id: 'ai',
    label: 'AI',
    icon: <Cpu className="w-4 h-4" />,
    description: 'Model routing, performance profile, cloud fallback',
  },
  {
    id: 'health',
    label: 'Health',
    icon: <HeartPulse className="w-4 h-4" />,
    description: 'Health provider, synchronization, wellness insights',
  },
  {
    id: 'devices',
    label: 'Devices',
    icon: <Headphones className="w-4 h-4" />,
    description: 'Microphone, speaker, frame buffers, Bluetooth',
  },
  {
    id: 'network',
    label: 'Network',
    icon: <Network className="w-4 h-4" />,
    description: 'Remote gateway, connection state',
  },
  {
    id: 'privacy',
    label: 'Privacy',
    icon: <Shield className="w-4 h-4" />,
    description: 'Chat history, memory, health storage, cloud, diagnostics',
  },
  {
    id: 'advanced',
    label: 'Advanced',
    icon: <Wrench className="w-4 h-4" />,
    description: 'Developer settings, experimental features',
  },
  {
    id: 'states',
    label: 'Application States',
    icon: <Layers className="w-4 h-4" />,
    description: '27 verified states: loading, empty, error, AI, health, devices, tasks, assistant',
  },
];

// Initial default settings
const defaultGeneralSettings: GeneralSettingsState = {
  launchAtBoot: true,
  startMinimized: false,
  resumeLastView: true,
  defaultStartupView: 'home',
  language: 'en-US',
  assistantVoiceLanguage: 'en-US',
  autoDetectTimezone: true,
  timezone: 'America/Los_Angeles',
  use24HourTime: false,
};

const defaultAssistantSettings: AssistantSettingsState = {
  defaultCharacterId: 'p-1',
  proactiveSuggestions: true,
  concisenessLevel: 50,
  empathyLevel: 65,
  strictFactualGrounding: true,
  autoExtractMemories: true,
  customSystemPromptAddendum: '',
};

const defaultVoiceSettings: VoiceSettingsState = {
  ttsProvider: 'kokoro-82m',
  ttsVoice: 'af_sarah',
  speechRate: 1.0,
  speechPitch: 1.0,
  sttProvider: 'whisper-small-metal',
  streamingTranscription: true,
  listeningMode: 'vad',
  wakeWordPhrase: 'Hey Iris',
  vadSensitivity: 60,
  echoCancellation: true,
  noiseSuppression: true,
  audioDucking: true,
};

const defaultAiSettings: AiSettingsState = {
  modelRoutingStrategy: 'smart_auto',
  primaryModelId: 'llama-3.1-8b-instruct',
  speculativeDecoding: true,
  performanceProfile: 'balanced',
  cloudFallbackPolicy: 'strict_airgap',
  kvCacheQuantization: false,
  gpuLayerOffload: 33,
};

const defaultHealthSettings: HealthSettingsState = {
  healthProvider: 'fitcloudpro_ble',
  syncIntervalMinutes: 5,
  syncWhileIdle: true,
  continuousHeartRateSampling: true,
  sleepScoreAnalysis: true,
  postureAlerts: true,
  hydrationAlerts: true,
  stressAlerts: true,
};

const defaultDeviceSettings: DeviceSettingsState = {
  selectedMicId: 'builtin_mic',
  selectedSpeakerId: 'usb_dac',
  audioBufferSize: 256,
  autoReconnectBluetooth: true,
  usbHotplugAutoSwitch: true,
  exclusiveDeviceAccess: false,
  wearableAutoSync: true,
};

const defaultNetworkSettings: NetworkSettingsState = {
  gatewayProvider: 'tailscale',
  gatewayIp: '100.84.192.42',
  gatewayPort: 8000,
  allowRemoteCompanion: true,
  enforceTlsCertificates: true,
  blockOutboundWan: true,
};

const defaultPrivacySettings: PrivacySettingsState = {
  historyRetention: 'forever',
  autoRedactPii: true,
  enableEpisodicMemory: true,
  associateBiometricFacts: true,
  encryptHealthDb: true,
  retainDiagnosticLogs: true,
};

const defaultAdvancedSettings: AdvancedSettingsState = {
  developerMode: false,
  exposeSwaggerDocs: false,
  metalVulkanLogging: false,
  streamingThrottleMs: 0,
  multiAgentDebate: false,
  voiceBargeIn: true,
  visionScreenAnalyzer: false,
};

export const SettingsView: React.FC = () => {
  const { mode, setThemePreference, setAccent, setEffectIntensity, setInterfaceDensity, setAnimationPreference } = useTheme();

  // Active section
  const [activeSection, setActiveSection] = useState<SettingsSectionId>('general');
  const [searchQuery, setSearchQuery] = useState('');

  // Settings states with localStorage persistence
  const [general, setGeneral] = useState<GeneralSettingsState>(() => {
    const saved = localStorage.getItem('localai-settings-general');
    return saved ? { ...defaultGeneralSettings, ...JSON.parse(saved) } : defaultGeneralSettings;
  });

  const [assistant, setAssistant] = useState<AssistantSettingsState>(() => {
    const saved = localStorage.getItem('localai-settings-assistant');
    return saved ? { ...defaultAssistantSettings, ...JSON.parse(saved) } : defaultAssistantSettings;
  });

  const [voice, setVoice] = useState<VoiceSettingsState>(() => {
    const saved = localStorage.getItem('localai-settings-voice');
    return saved ? { ...defaultVoiceSettings, ...JSON.parse(saved) } : defaultVoiceSettings;
  });

  const [ai, setAi] = useState<AiSettingsState>(() => {
    const saved = localStorage.getItem('localai-settings-ai');
    return saved ? { ...defaultAiSettings, ...JSON.parse(saved) } : defaultAiSettings;
  });

  const [health, setHealth] = useState<HealthSettingsState>(() => {
    const saved = localStorage.getItem('localai-settings-health');
    return saved ? { ...defaultHealthSettings, ...JSON.parse(saved) } : defaultHealthSettings;
  });

  const [devices, setDevices] = useState<DeviceSettingsState>(() => {
    const saved = localStorage.getItem('localai-settings-devices');
    return saved ? { ...defaultDeviceSettings, ...JSON.parse(saved) } : defaultDeviceSettings;
  });

  const [network, setNetwork] = useState<NetworkSettingsState>(() => {
    const saved = localStorage.getItem('localai-settings-network');
    return saved ? { ...defaultNetworkSettings, ...JSON.parse(saved) } : defaultNetworkSettings;
  });

  const [privacy, setPrivacy] = useState<PrivacySettingsState>(() => {
    const saved = localStorage.getItem('localai-settings-privacy');
    return saved ? { ...defaultPrivacySettings, ...JSON.parse(saved) } : defaultPrivacySettings;
  });

  const [advanced, setAdvanced] = useState<AdvancedSettingsState>(() => {
    const saved = localStorage.getItem('localai-settings-advanced');
    return saved ? { ...defaultAdvancedSettings, ...JSON.parse(saved) } : defaultAdvancedSettings;
  });

  // Save states
  const updateGeneral = <K extends keyof GeneralSettingsState>(key: K, value: GeneralSettingsState[K]) => {
    setGeneral((prev) => {
      const next = { ...prev, [key]: value };
      localStorage.setItem('localai-settings-general', JSON.stringify(next));
      return next;
    });
  };

  const updateAssistant = <K extends keyof AssistantSettingsState>(key: K, value: AssistantSettingsState[K]) => {
    setAssistant((prev) => {
      const next = { ...prev, [key]: value };
      localStorage.setItem('localai-settings-assistant', JSON.stringify(next));
      return next;
    });
  };

  const updateVoice = <K extends keyof VoiceSettingsState>(key: K, value: VoiceSettingsState[K]) => {
    setVoice((prev) => {
      const next = { ...prev, [key]: value };
      localStorage.setItem('localai-settings-voice', JSON.stringify(next));
      return next;
    });
  };

  const updateAi = <K extends keyof AiSettingsState>(key: K, value: AiSettingsState[K]) => {
    setAi((prev) => {
      const next = { ...prev, [key]: value };
      localStorage.setItem('localai-settings-ai', JSON.stringify(next));
      return next;
    });
  };

  const updateHealth = <K extends keyof HealthSettingsState>(key: K, value: HealthSettingsState[K]) => {
    setHealth((prev) => {
      const next = { ...prev, [key]: value };
      localStorage.setItem('localai-settings-health', JSON.stringify(next));
      return next;
    });
  };

  const updateDevices = <K extends keyof DeviceSettingsState>(key: K, value: DeviceSettingsState[K]) => {
    setDevices((prev) => {
      const next = { ...prev, [key]: value };
      localStorage.setItem('localai-settings-devices', JSON.stringify(next));
      return next;
    });
  };

  const updateNetwork = <K extends keyof NetworkSettingsState>(key: K, value: NetworkSettingsState[K]) => {
    setNetwork((prev) => {
      const next = { ...prev, [key]: value };
      localStorage.setItem('localai-settings-network', JSON.stringify(next));
      return next;
    });
  };

  const updatePrivacy = <K extends keyof PrivacySettingsState>(key: K, value: PrivacySettingsState[K]) => {
    setPrivacy((prev) => {
      const next = { ...prev, [key]: value };
      localStorage.setItem('localai-settings-privacy', JSON.stringify(next));
      return next;
    });
  };

  const updateAdvanced = <K extends keyof AdvancedSettingsState>(key: K, value: AdvancedSettingsState[K]) => {
    setAdvanced((prev) => {
      const next = { ...prev, [key]: value };
      localStorage.setItem('localai-settings-advanced', JSON.stringify(next));
      return next;
    });
  };

  const handleResetAll = () => {
    setGeneral(defaultGeneralSettings);
    setAssistant(defaultAssistantSettings);
    setVoice(defaultVoiceSettings);
    setAi(defaultAiSettings);
    setHealth(defaultHealthSettings);
    setDevices(defaultDeviceSettings);
    setNetwork(defaultNetworkSettings);
    setPrivacy(defaultPrivacySettings);
    setAdvanced(defaultAdvancedSettings);
    setThemePreference('system');
    setAccent('aurora');
    setEffectIntensity('normal');
    setInterfaceDensity('comfortable');
    setAnimationPreference('fluid');

    localStorage.removeItem('localai-settings-general');
    localStorage.removeItem('localai-settings-assistant');
    localStorage.removeItem('localai-settings-voice');
    localStorage.removeItem('localai-settings-ai');
    localStorage.removeItem('localai-settings-health');
    localStorage.removeItem('localai-settings-devices');
    localStorage.removeItem('localai-settings-network');
    localStorage.removeItem('localai-settings-privacy');
    localStorage.removeItem('localai-settings-advanced');
  };

  // Filter sections by search query
  const filteredSections = SECTIONS.filter((sec) => {
    if (!searchQuery.trim()) return true;
    const q = searchQuery.toLowerCase();
    return (
      sec.label.toLowerCase().includes(q) ||
      sec.description.toLowerCase().includes(q)
    );
  });

  return (
    <div className="space-y-6">
      {/* View Header */}
      <div className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-2xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm flex-shrink-0 shadow-sm">
            <Settings className="w-5 h-5" />
          </div>
          <div>
            <h1 className="text-lg font-bold text-[var(--color-text-primary)]">
              Preferences & System Configuration
            </h1>
            <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
              10 organized sections: General, Appearance, Assistant, Voice, AI, Health, Devices, Network, Privacy, Advanced.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <div className="flex items-center gap-1.5 px-3 py-1.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs font-medium text-[var(--color-text-secondary)]">
            <CheckCircle2 className="w-3.5 h-3.5 text-emerald-500" />
            <span>Persisted Locally (SQLite & Keyring)</span>
          </div>
        </div>
      </div>

      {/* Main Settings Layout (Left Nav + Right Content) */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        {/* Left Navigation Sidebar (Sticky on desktop) */}
        <div className="lg:col-span-4 space-y-3 lg:sticky lg:top-2 self-start z-10">
          {/* Section Search Bar */}
          <div className="p-3 rounded-2xl surface-raised border border-[var(--color-border-subtle)] backdrop-blur-md">
            <SearchInput
              value={searchQuery}
              onChangeValue={setSearchQuery}
              placeholder="Search preferences & parameters..."
              sizeVariant="sm"
            />
          </div>

          {/* Section Tabs List (Scrollable if viewport is compact) */}
          <div className="p-2 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-1 max-h-[calc(100vh-180px)] overflow-y-auto overscroll-contain shadow-xs">
            {filteredSections.map((sec) => {
              const isSelected = activeSection === sec.id;
              return (
                <button
                  key={sec.id}
                  type="button"
                  onClick={() => setActiveSection(sec.id)}
                  className={`w-full p-3 rounded-2xl text-left transition-all flex items-center gap-3 ${
                    isSelected
                      ? 'bg-accent-gradient text-white shadow-sm font-semibold'
                      : 'hover:bg-[var(--color-surface-elevated)] text-[var(--color-text-primary)]'
                  }`}
                >
                  <div
                    className={`p-2 rounded-xl flex-shrink-0 ${
                      isSelected
                        ? 'bg-white/20 text-white'
                        : 'bg-[var(--color-surface-secondary)] text-[var(--color-text-secondary)]'
                    }`}
                  >
                    {sec.icon}
                  </div>
                  <div className="min-w-0 flex-1">
                    <span className="text-xs font-bold block uppercase tracking-wider font-mono">
                      {sec.label}
                    </span>
                    <span
                      className={`text-[11px] truncate block mt-0.5 ${
                        isSelected ? 'text-white/80' : 'text-[var(--color-text-muted)]'
                      }`}
                    >
                      {sec.description}
                    </span>
                  </div>
                </button>
              );
            })}
          </div>
        </div>

        {/* Right Content Area */}
        <div className="lg:col-span-8">
          {activeSection === 'general' && (
            <GeneralSection settings={general} onUpdate={updateGeneral} />
          )}
          {activeSection === 'appearance' && <AppearanceSection />}
          {activeSection === 'assistant' && (
            <AssistantSection settings={assistant} onUpdate={updateAssistant} />
          )}
          {activeSection === 'voice' && (
            <VoiceSection settings={voice} onUpdate={updateVoice} />
          )}
          {activeSection === 'ai' && (
            <AiSection settings={ai} onUpdate={updateAi} />
          )}
          {activeSection === 'health' && (
            <HealthSection settings={health} onUpdate={updateHealth} />
          )}
          {activeSection === 'devices' && (
            <DevicesSection settings={devices} onUpdate={updateDevices} />
          )}
          {activeSection === 'network' && (
            <NetworkSection settings={network} onUpdate={updateNetwork} />
          )}
          {activeSection === 'privacy' && (
            <PrivacySection settings={privacy} onUpdate={updatePrivacy} />
          )}
          {activeSection === 'advanced' && (
            <AdvancedSection
              settings={advanced}
              onUpdate={updateAdvanced}
              onResetAll={handleResetAll}
            />
          )}
          {activeSection === 'states' && <ApplicationStatesShowcase />}
        </div>
      </div>
    </div>
  );
};
