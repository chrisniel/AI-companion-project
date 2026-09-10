import { ReactNode } from 'react';

export type ThemeMode = 'light' | 'dark';
export type ThemePreference = 'light' | 'dark' | 'system';
export type EffectIntensity = 'reduced' | 'normal' | 'enhanced';
export type InterfaceDensity = 'comfortable' | 'compact';
export type AnimationPreference = 'fluid' | 'reduced' | 'none';

export type AccentPresetId = 'aurora' | 'electric' | 'emerald' | 'amethyst';

export interface AccentPreset {
  id: AccentPresetId;
  name: string;
  description: string;
  gradient: string;
  glow: string;
  primaryColor: string;
  secondaryColor: string;
}

// Background & Glass Customization Types (Batch 10.1)
export type BackgroundType = 'builtin' | 'custom' | 'gradient' | 'solid';

export type BuiltinBackgroundId =
  | 'aurora_mist'
  | 'pearl_bloom'
  | 'cloud_glass'
  | 'lavender_flow'
  | 'midnight_aurora'
  | 'graphite_waves'
  | 'deep_violet'
  | 'blue_ember';

export type BackgroundFit = 'cover' | 'contain' | 'fill';
export type BackgroundPosition = 'center' | 'top' | 'bottom' | 'left' | 'right';
export type GradientDirection =
  | 'to bottom right'
  | 'to right'
  | 'to bottom'
  | 'to top right'
  | 'radial';

export interface BuiltinPresetInfo {
  id: BuiltinBackgroundId;
  name: string;
  category: 'light' | 'dark';
  description: string;
  colors: string[];
  css: string;
}

export interface BackgroundSettings {
  type: BackgroundType;
  builtinId: BuiltinBackgroundId;
  lightPresetId: BuiltinBackgroundId;
  darkPresetId: BuiltinBackgroundId;
  customImageUrl: string | null;
  customFit: BackgroundFit;
  customPosition: BackgroundPosition;
  gradientPrimary: string;
  gradientSecondary: string;
  gradientTertiary: string;
  hasTertiaryGradient: boolean;
  gradientDirection: GradientDirection;
  solidColor: string;
  brightness: number; // 50 to 150
  saturation: number; // 0 to 150
  blur: number; // 0 to 40
  overlayOpacity: number; // 0 to 100
}

export type GlassPreset = 'reduced' | 'normal' | 'enhanced' | 'custom';

export interface GlassSettings {
  preset: GlassPreset;
  transparency: number; // 40 to 90 (0.40 - 0.90 opacity)
  blur: number; // 4 to 32 (px)
  tintStrength: number; // 20 to 100 (%)
  saturation: number; // 100 to 150 (%)
}

export type ComponentState =
  | 'default'
  | 'hover'
  | 'focused'
  | 'pressed'
  | 'selected'
  | 'disabled'
  | 'loading'
  | 'success'
  | 'warning'
  | 'error';

export type ButtonVariant =
  | 'primary'
  | 'secondary'
  | 'ghost'
  | 'neumorphic'
  | 'danger';

export type ButtonSize = 'sm' | 'md' | 'lg';

export type BadgeVariant =
  | 'default'
  | 'accent'
  | 'success'
  | 'warning'
  | 'danger'
  | 'glass'
  | 'neutral';

export type StatusType =
  | 'online'
  | 'idle'
  | 'busy'
  | 'assistant'
  | 'model-active'
  | 'offline'
  | 'error';

export interface TabItem {
  id: string;
  label: string;
  icon?: ReactNode;
  badge?: string | number;
  disabled?: boolean;
}

export interface SelectOption {
  value: string;
  label: string;
  description?: string;
  icon?: ReactNode;
  badge?: string;
}

// Local AI Control Center Mock Types for future FastAPI backend integration
export interface SystemMetrics {
  cpuUsage: number;
  ramUsedGb: number;
  ramTotalGb: number;
  vramUsedGb: number;
  vramTotalGb: number;
  temperatureC: number;
  tokensPerSec: number;
  activeContextTokens: number;
  maxContextTokens: number;
}

export type ModelProviderType = 'llama.cpp' | 'ollama' | 'gemini';

export type ProviderRoutingPolicy =
  | 'local_only'
  | 'local_first'
  | 'cloud_first'
  | 'cloud_only';

export interface ModelProviderInfo {
  id: ModelProviderType;
  name: string;
  type: 'local' | 'cloud';
  version: string;
  status: 'running' | 'connected' | 'standby' | 'error';
  endpoint: string;
  activeModelName?: string;
  description: string;
  latencyText: string;
  supportedFormats: string[];
}

export interface LocalModel {
  id: string;
  name: string;
  family: string;
  parameters: string;
  quantization: string;
  sizeGb: number;
  contextWindow: number;
  status: 'loaded' | 'unloaded' | 'downloading';
  engine: 'llama.cpp' | 'vllm' | 'ollama' | 'exllama2' | 'gemini';
  isCloud?: boolean;
  ramUsageGb?: number;
  vramUsageGb?: number;
  estimatedLatencyMs?: number;
  tokensPerSec?: number;
  layersTotal?: number;
  layersOffloaded?: number;
  filePath?: string;
  description?: string;
  license?: string;
  tensorType?: string;
}

export interface AssistantPersona {
  id: string;
  name: string;
  title: string;
  status: 'listening' | 'idle' | 'thinking' | 'speaking';
  voice: string;
  personality: string;
  systemPromptPreset: string;
}

export interface ScheduledTask {
  id: string;
  title: string;
  time: string;
  frequency: string;
  type: 'alarm' | 'reminder' | 'maintenance' | 'sync';
  enabled: boolean;
}

// BATCH 5: Tasks & Schedule Domain Models
export type TaskPriority = 'low' | 'medium' | 'high' | 'urgent';

export interface TaskItem {
  id: string;
  title: string;
  description?: string;
  completed: boolean;
  completedAt?: string;
  dueDate: string; // YYYY-MM-DD format
  dueTime?: string; // HH:mm format
  priority: TaskPriority;
  category: string; // e.g. 'Core System', 'Work', 'Personal', 'Automation', 'Health'
  hasReminder: boolean;
  reminderTime?: string;
  createdAt: string;
}

export type ScheduleEventType = 'task' | 'reminder' | 'alarm' | 'calendar';
export type AlarmTargetDevice = 'desktop' | 'android' | 'both';
export type AlarmRepeat = 'once' | 'daily' | 'weekdays' | 'weekends';

export interface ScheduleEvent {
  id: string;
  title: string;
  description?: string;
  type: ScheduleEventType;
  date: string; // YYYY-MM-DD
  startTime: string; // HH:mm
  endTime?: string; // HH:mm
  allDay?: boolean;
  locationOrContext?: string;
  category?: string;
  // Alarm-specific fields
  repeat?: AlarmRepeat;
  targetDevice?: AlarmTargetDevice;
  enabled?: boolean;
  mirroredToAndroid?: boolean;
}

export interface AudioDevice {
  id: string;
  name: string;
  type: 'input' | 'output';
  volume: number;
  isMuted: boolean;
}

export type NavigationSectionId =
  | 'home'
  | 'assistant'
  | 'tasks'
  | 'schedule'
  | 'health'
  | 'memory'
  | 'models'
  | 'characters'
  | 'devices'
  | 'logs'
  | 'settings';

export type AssistantPanelMode = 'expanded' | 'collapsed' | 'hidden';

export type PerformanceProfile = 'eco' | 'balanced' | 'maximum' | 'turbo';

export type AssistantState =
  | 'idle'
  | 'listening'
  | 'thinking'
  | 'executing_tool'
  | 'speaking'
  | 'interrupted'
  | 'reconnecting'
  | 'offline'
  | 'error';

export type MessageType =
  | 'user'
  | 'assistant'
  | 'system'
  | 'tool_execution'
  | 'memory_retrieval'
  | 'web_search'
  | 'warning'
  | 'error';

export interface ToolCardData {
  toolName: string;
  action: string;
  summary: string;
  status: 'completed' | 'running' | 'failed';
  details?: Record<string, string | number>;
}

export interface AssistantMessage {
  id: string;
  type: MessageType;
  sender?: string;
  timestamp: string;
  content: string;
  toolCard?: ToolCardData;
  memoryMetadata?: {
    query: string;
    similarity: string;
    source: string;
  };
  searchMetadata?: {
    query: string;
    resultsCount: number;
    source: string;
  };
}

export interface ConversationHistoryItem {
  id: string;
  title: string;
  date: string;
  snippet: string;
  model: string;
  messagesCount: number;
}

export interface NotificationItem {
  id: string;
  title: string;
  message: string;
  time: string;
  read: boolean;
  type: 'info' | 'success' | 'warning';
}

// Health & Wellness Types
export type HealthTimeRange = 'today' | 'week' | 'month';

export interface HealthSourceProvider {
  id: string;
  name: string;
  deviceModel: string;
  iconType: 'band' | 'watch' | 'ring' | 'sensor';
  description: string;
  supportsSpO2: boolean;
  supportsSleepStages: boolean;
  supportsContinuousHR: boolean;
  status: 'connected' | 'syncing' | 'idle' | 'disconnected';
  lastSyncTime: string;
  sampleCount: number;
}

export interface HealthPipelineStage {
  step: number;
  label: string;
  detail: string;
  subtext: string;
  status: 'active' | 'synced' | 'pending';
}

export interface HeartRateMetric {
  currentBpm: number;
  restingAvgBpm: number;
  minBpm: number;
  maxBpm: number;
  timestamp: string;
  trend: {
    time: string;
    bpm: number;
    restingBaseline?: number;
  }[];
}

export interface SleepMetric {
  totalMinutes: number;
  recentAvgMinutes: number;
  consistencyPercentage: number;
  asleepTime: string;
  wakeTime: string;
  hasStageData: boolean;
  stageNote?: string;
  dailyTrend: {
    label: string;
    totalMinutes: number;
    deepMinutes?: number;
    lightMinutes?: number;
    targetMinutes: number;
  }[];
}

export interface ActivityMetric {
  steps: number;
  stepGoal: number;
  activeMinutes: number;
  activeMinutesGoal: number;
  caloriesBurnedKcal: number;
  distanceKm: number;
  trend: {
    label: string;
    steps: number;
    activeMinutes: number;
  }[];
}

export interface BloodOxygenMeasurement {
  id: string;
  timestamp: string;
  percentage: number;
  status: 'normal' | 'low' | 'elevated';
  condition: 'resting' | 'sleep' | 'spot-check';
}

export interface BloodOxygenMetric {
  isAvailable: boolean;
  unavailableReason?: string;
  latestPercentage?: number;
  latestTimestamp?: string;
  measurements: BloodOxygenMeasurement[];
}

export interface HealthInsight {
  id: string;
  category: 'sleep' | 'activity' | 'heart' | 'general';
  title: string;
  observation: string;
  tag: string;
  timeframe: string;
  type: 'info' | 'positive' | 'attention';
}

// BATCH 8: Character and Persona System
export type AvatarSemanticState =
  | 'idle'
  | 'listening'
  | 'thinking'
  | 'speaking'
  | 'happy'
  | 'concerned'
  | 'annoyed'
  | 'error';

export type AvatarDisplayMode =
  | 'disabled'
  | 'assistant_panel'
  | 'large'
  | 'future_floating_mode';

export type VoiceProvider =
  | 'piper_local'
  | 'kokoro_local'
  | 'system_tts'
  | 'elevenlabs_cloud';

export type PersonalityStyle =
  | 'balanced'
  | 'analytical'
  | 'concise'
  | 'warm_friendly'
  | 'witty'
  | 'formal'
  | 'sarcastic';

export type ResponseLengthPreference = 'concise' | 'balanced' | 'thorough';
export type ResponseStylePreference = 'natural' | 'bulleted' | 'code_first' | 'inquisitive';

export interface CharacterSpeakingBehavior {
  autoSpeak: boolean;
  interruptible: boolean;
  pitch: number; // 0.5 to 1.5
  rate: number; // 0.5 to 2.0
  pauseDurationMs: number; // 100 to 800
}

export interface CharacterResponsePreferences {
  length: ResponseLengthPreference;
  style: ResponseStylePreference;
  toneIntensity: number; // 1 to 5
}

// ==========================================
// BATCH 12.1: Multilingual & Language Types
// ==========================================
export type SupportedLanguageCode = 'en' | 'fil' | 'ja' | 'mixed';

export type JapaneseDisplayFormat =
  | 'kanji_furigana'
  | 'kanji_only'
  | 'romaji_subtext'
  | 'romaji_only';

export type TechnicalResponseLanguageMode =
  | 'preserve_english'
  | 'match_conversation'
  | 'dual_bilingual';

export type ResponseLanguageMode =
  | 'auto'
  | 'user_input'
  | 'primary'
  | 'en'
  | 'fil'
  | 'ja';

export interface LanguagePreferences {
  primaryLanguage: 'en' | 'fil' | 'ja' | 'auto_detect';
  understoodLanguages: ('en' | 'fil' | 'ja')[];
  codeSwitchingEnabled: boolean;
  responseLanguage: ResponseLanguageMode;
  technicalResponseLanguage: TechnicalResponseLanguageMode;
  japaneseDisplayFormat: JapaneseDisplayFormat;
}

export type CodeSwitchingFrequency = 'never' | 'rare' | 'natural' | 'frequent';
export type TagalogParticleFrequency = 'minimal' | 'natural' | 'colloquial';
export type JapaneseToneStyle =
  | 'casual_teineigo'
  | 'polite_desu_masu'
  | 'business_keigo'
  | 'warm_conversational';

export interface CharacterLanguageStyle {
  primaryLanguage: 'en' | 'fil' | 'ja' | 'match_user';
  secondaryLanguages: ('en' | 'fil' | 'ja')[];
  matchUserLanguage: boolean;
  codeSwitchingFrequency: CodeSwitchingFrequency;
  tagalogParticleFrequency: TagalogParticleFrequency;
  japaneseHonorificsFrequency: 'none' | 'polite_desu_masu' | 'casual' | 'formal_keigo';
  japaneseTone: JapaneseToneStyle;
}

export type SpeechRecognitionLanguageMode =
  | 'auto_detect'
  | 'manual_primary'
  | 'multilingual_simultaneous';

export interface VoiceLanguageCapability {
  code: SupportedLanguageCode;
  name: string;
  nativeName: string;
  sttFidelity: number;
  ttsFidelity: number;
  engine: string;
  codeSwitchSupported: boolean;
  notes: string;
}

export interface CharacterConfig extends AssistantPersona {
  subtitle?: string;
  persona?: string;
  personalityStyle?: PersonalityStyle;
  avatarSeed?: string;
  avatarType?: 'geometric_orb' | 'hologram_core' | 'sentient_glyph' | 'quantum_prism' | 'pulse_ring';
  avatarAccentColor?: string;
  voiceProvider?: VoiceProvider;
  voiceModelId?: string;
  speakingBehavior?: CharacterSpeakingBehavior;
  responsePreferences?: CharacterResponsePreferences;
  avatarDisplayMode?: AvatarDisplayMode;
  languageStyle?: CharacterLanguageStyle;
  isCustom?: boolean;
}

// ==========================================
// BATCH 9: Devices & Memory Types
// ==========================================

export type DeviceCategory = 'computer' | 'mobile' | 'audio' | 'health' | 'network';
export type DeviceStatus = 'online' | 'connected' | 'idle' | 'standby' | 'syncing' | 'offline';

export interface DeviceItem {
  id: string;
  name: string;
  category: DeviceCategory;
  status: DeviceStatus;
  capability: string;
  lastSeen: string;
  assignedRole: string;
  iconType?: string;
  batteryLevel?: number;
  ipOrAddress?: string;
  details?: Record<string, string | number>;
}

export interface AudioDeviceOption {
  id: string;
  name: string;
  type: 'input' | 'output';
  interfaceType: 'usb' | 'bluetooth' | 'system' | 'virtual' | 'pci';
  sampleRate: string;
  channels: string;
  isDefault?: boolean;
}

export interface AudioRoutingConfig {
  inputDeviceId: string;
  outputDeviceId: string;
  preferredOutputId: string;
  fallbackOutputId: string;
}

export interface AndroidSyncItem {
  name: string;
  key: 'alarms' | 'tasks' | 'health' | 'assistantConnection';
  status: 'synced' | 'syncing' | 'idle' | 'connected' | 'disconnected';
  details: string;
  lastSynced: string;
}

export interface RemoteGatewayDetails {
  name: string;
  provider: string; // e.g. Tailscale, WireGuard, Headscale, ZeroTier
  status: 'connected' | 'standby' | 'offline';
  virtualIp: string;
  latencyMs: number;
  assignedRole: string;
  encryption: string;
  protocol: string;
}

export type MemoryCategory = 'Profile' | 'Preference' | 'Fact' | 'Project' | 'Event' | 'Temporary';

export interface MemoryEntry {
  id: string;
  content: string;
  category: MemoryCategory;
  source: string;
  confidence: number; // 0 to 1 (e.g. 0.96 = 96%)
  lastUpdated: string;
  isArchived?: boolean;
  tags?: string[];
}

export type LogSubsystem =
  | 'all'
  | 'assistant'
  | 'models'
  | 'tools'
  | 'audio'
  | 'health'
  | 'devices'
  | 'scheduler'
  | 'network'
  | 'errors';

export type LogSeverity = 'ALL' | 'INFO' | 'DEBUG' | 'WARN' | 'ERROR' | 'TRACE';

export interface StructuredLogEntry {
  id: string;
  timestamp: string;
  subsystem: 'assistant' | 'models' | 'tools' | 'audio' | 'health' | 'devices' | 'scheduler' | 'network' | 'errors';
  severity: 'INFO' | 'DEBUG' | 'WARN' | 'ERROR' | 'TRACE';
  event: string;
  latencyMs?: number;
  component?: string;
  details?: Record<string, any>;
  stackTrace?: string;
}

