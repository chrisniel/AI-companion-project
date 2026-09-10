import React, { useState } from 'react';
import {
  Layers,
  Loader2,
  Inbox,
  AlertTriangle,
  WifiOff,
  CloudOff,
  Cpu,
  RefreshCw,
  ServerOff,
  ShieldAlert,
  Activity,
  Watch,
  Link2Off,
  FileQuestion,
  Clock,
  Sparkles,
  Smartphone,
  Bluetooth,
  MicOff,
  CheckSquare,
  AlertCircle,
  RotateCcw,
  Bot,
  Mic,
  Brain,
  Volume2,
  CheckCircle2,
  Copy,
  Check,
  Search,
  ExternalLink,
  ShieldCheck,
  Zap,
} from 'lucide-react';
import { Badge } from '../../ui/Badge';
import { Card } from '../../ui/Card';
import { SearchInput } from '../../ui/SearchInput';

export type StateCategory =
  | 'all'
  | 'general'
  | 'ai'
  | 'health'
  | 'devices'
  | 'tasks'
  | 'assistant';

export interface ApplicationStateExample {
  id: string;
  category: StateCategory;
  name: string;
  badgeText: string;
  badgeVariant: 'default' | 'accent' | 'success' | 'warning' | 'danger' | 'glass';
  icon: React.ReactNode;
  summary: string;
  accessibilityFeatures: string[];
  diagnosticCode: string;
  renderedComponent: React.ReactNode;
}

export const ApplicationStatesShowcase: React.FC<{
  onSimulateState?: (category: StateCategory, stateId: string) => void;
}> = ({ onSimulateState }) => {
  const [selectedCategory, setSelectedCategory] = useState<StateCategory>('all');
  const [searchQuery, setSearchQuery] = useState('');
  const [copiedCode, setCopiedCode] = useState<string | null>(null);

  const handleCopy = (code: string) => {
    navigator.clipboard.writeText(code);
    setCopiedCode(code);
    setTimeout(() => setCopiedCode(null), 2000);
  };

  // The 27 Required Application States across 6 categories
  const stateExamples: ApplicationStateExample[] = [
    // ==========================================
    // 1. GENERAL (5 states)
    // ==========================================
    {
      id: 'gen-loading',
      category: 'general',
      name: 'Loading State',
      badgeText: 'SYNCHRONIZING',
      badgeVariant: 'accent',
      icon: <Loader2 className="w-4 h-4 animate-spin text-[var(--color-accent)]" />,
      summary: 'Data or telemetry is currently streaming or fetching with aria-busy feedback.',
      accessibilityFeatures: [
        'aria-busy="true" declared on region',
        'Animated spinning glyph + human-readable text',
        'WCAG AA text contrast ratio > 4.5:1',
      ],
      diagnosticCode: 'GEN_SYS_BUSY_FETCH',
      renderedComponent: (
        <div className="p-6 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex flex-col items-center justify-center text-center space-y-3" role="status" aria-busy="true">
          <div className="w-10 h-10 rounded-xl surface-raised flex items-center justify-center text-[var(--color-accent)] shadow-xs">
            <Loader2 className="w-5 h-5 animate-spin" />
          </div>
          <div>
            <h4 className="text-sm font-bold text-[var(--color-text-primary)]">Loading Telemetry Pipeline...</h4>
            <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">Aggregating local sensor data and vector indices</p>
          </div>
          <div className="w-48 h-1.5 rounded-full bg-[var(--color-surface-secondary)] overflow-hidden">
            <div className="h-full bg-accent-gradient w-2/3 animate-pulse rounded-full" />
          </div>
        </div>
      ),
    },
    {
      id: 'gen-empty',
      category: 'general',
      name: 'Empty State',
      badgeText: 'NO RECORDS',
      badgeVariant: 'glass',
      icon: <Inbox className="w-4 h-4 text-[var(--color-text-muted)]" />,
      summary: 'No records exist yet in the current view or query context.',
      accessibilityFeatures: [
        'Clear empty illustration with descriptive icon',
        'Direct primary call-to-action button with focus ring',
        'No ambiguous or dead-end layouts',
      ],
      diagnosticCode: 'GEN_DATA_EMPTY_SET',
      renderedComponent: (
        <div className="p-6 rounded-2xl surface-recessed border border-dashed border-[var(--color-border-subtle)] flex flex-col items-center justify-center text-center space-y-3">
          <div className="w-10 h-10 rounded-xl surface-raised flex items-center justify-center text-[var(--color-text-muted)]">
            <Inbox className="w-5 h-5" />
          </div>
          <div>
            <h4 className="text-sm font-bold text-[var(--color-text-primary)]">No Items Found</h4>
            <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">Get started by creating your first entry or clearing search filters</p>
          </div>
          <button
            type="button"
            className="px-3.5 py-1.5 rounded-xl bg-accent-gradient text-white text-xs font-semibold shadow-xs hover:opacity-95 focus-visible:ring-2 focus-visible:ring-[var(--color-accent)] cursor-pointer"
          >
            Create New Item
          </button>
        </div>
      ),
    },
    {
      id: 'gen-error',
      category: 'general',
      name: 'Error State',
      badgeText: 'CRITICAL FAILURE',
      badgeVariant: 'danger',
      icon: <AlertTriangle className="w-4 h-4 text-rose-500" />,
      summary: 'An unhandled exception or parsing malfunction occurred during execution.',
      accessibilityFeatures: [
        'Role="alert" announces immediately to screen readers',
        'High-contrast crimson border and alert iconography',
        'Non-color reliant: explicit error code + troubleshooting advice',
      ],
      diagnosticCode: 'GEN_ERR_SOCKET_TIMEOUT',
      renderedComponent: (
        <div className="p-5 rounded-2xl bg-rose-500/10 border border-rose-500/30 text-[var(--color-text-primary)] space-y-3" role="alert">
          <div className="flex items-start gap-3">
            <div className="w-8 h-8 rounded-xl bg-rose-500 text-white flex items-center justify-center flex-shrink-0 mt-0.5">
              <AlertTriangle className="w-4 h-4" />
            </div>
            <div className="space-y-1 min-w-0 flex-1">
              <div className="flex items-center gap-2">
                <h4 className="text-sm font-bold text-rose-600 dark:text-rose-400">Communication Pipeline Fault</h4>
                <span className="text-[10px] font-mono px-1.5 py-0.2 rounded bg-rose-500/20 text-rose-700 dark:text-rose-300">CODE: 504</span>
              </div>
              <p className="text-xs text-[var(--color-text-secondary)]">The local IPC socket did not respond within 30,000ms. Process may have restarted.</p>
            </div>
          </div>
          <div className="flex items-center gap-2 pt-1 border-t border-rose-500/20">
            <button
              type="button"
              className="px-3 py-1 rounded-lg bg-rose-600 text-white text-xs font-semibold hover:bg-rose-700 cursor-pointer focus-visible:ring-2 focus-visible:ring-rose-500"
            >
              Restart Service
            </button>
            <button
              type="button"
              className="px-3 py-1 rounded-lg surface-raised text-xs font-medium hover:text-[var(--color-text-primary)] cursor-pointer"
            >
              View System Logs
            </button>
          </div>
        </div>
      ),
    },
    {
      id: 'gen-disconnected',
      category: 'general',
      name: 'Disconnected State',
      badgeText: 'LINK DOWN',
      badgeVariant: 'warning',
      icon: <WifiOff className="w-4 h-4 text-amber-500" />,
      summary: 'Connection between client interface and backend daemon has dropped.',
      accessibilityFeatures: [
        'Persistent amber banner with disconnected antenna symbol',
        'Automatic retry timer with live second countdown',
        'Tactile retry control accessible via keyboard Enter/Space',
      ],
      diagnosticCode: 'GEN_LINK_DISCONNECTED',
      renderedComponent: (
        <div className="p-4 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-amber-500/20 text-amber-600 dark:text-amber-400 flex items-center justify-center flex-shrink-0">
              <WifiOff className="w-4 h-4" />
            </div>
            <div>
              <div className="text-xs font-bold text-[var(--color-text-primary)]">Backend Service Disconnected</div>
              <div className="text-[11px] text-[var(--color-text-secondary)]">Attempting reconnect in 4s (Attempt 3 of 10)</div>
            </div>
          </div>
          <button
            type="button"
            className="px-3 py-1 rounded-xl bg-amber-500 text-white text-xs font-semibold hover:bg-amber-600 self-start sm:self-auto cursor-pointer focus-visible:ring-2 focus-visible:ring-amber-500"
          >
            Reconnect Now
          </button>
        </div>
      ),
    },
    {
      id: 'gen-offline',
      category: 'general',
      name: 'Offline State',
      badgeText: 'LOCAL AIRGAP',
      badgeVariant: 'glass',
      icon: <CloudOff className="w-4 h-4 text-sky-400" />,
      summary: 'System is running fully offline with zero external internet dependency.',
      accessibilityFeatures: [
        'Green checkmark for local capabilities despite offline state',
        'Clear privacy reassurance badge: Zero telemetry leaving workstation',
        'High-contrast neutral card framing',
      ],
      diagnosticCode: 'GEN_NET_OFFLINE_AIRGAP',
      renderedComponent: (
        <div className="p-4 rounded-2xl surface-raised border border-[var(--color-border-subtle)] flex items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-xl surface-recessed text-[var(--color-accent)] flex items-center justify-center border border-[var(--color-border-subtle)]">
              <CloudOff className="w-4 h-4" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-[var(--color-text-primary)]">Strict Airgap Mode</span>
                <span className="text-[10px] font-mono px-1.5 py-0.2 rounded bg-emerald-500/15 text-emerald-600 dark:text-emerald-400 font-bold">ACTIVE</span>
              </div>
              <p className="text-[11px] text-[var(--color-text-secondary)]">All models, vectors, and device metrics run 100% locally on this machine.</p>
            </div>
          </div>
          <Badge variant="glass" size="sm">Local Only</Badge>
        </div>
      ),
    },

    // ==========================================
    // 2. AI RUNTIME (5 states)
    // ==========================================
    {
      id: 'ai-no-model-loaded',
      category: 'ai',
      name: 'No Model Loaded',
      badgeText: 'STANDBY',
      badgeVariant: 'warning',
      icon: <Cpu className="w-4 h-4 text-amber-500" />,
      summary: 'VRAM is idle; no neural model is currently resident in GPU memory.',
      accessibilityFeatures: [
        'Amber standby status badge + clear zero VRAM footprint notation',
        'Direct "Select Model" button with autofocus support',
        'Clear instruction on how to boot an engine',
      ],
      diagnosticCode: 'AI_CORE_NO_MODEL_ACTIVE',
      renderedComponent: (
        <div className="p-5 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <Cpu className="w-4 h-4 text-amber-500" />
              <span className="text-xs font-bold text-[var(--color-text-primary)]">Neural Inference Engine</span>
            </div>
            <Badge variant="warning" size="sm">No Model in VRAM</Badge>
          </div>
          <p className="text-xs text-[var(--color-text-secondary)]">
            Zero GPU memory currently allocated (0.0 / 8.0 GB). Select a quantized GGUF model from the library to begin inference.
          </p>
          <div className="flex items-center gap-2 pt-1">
            <button
              type="button"
              className="px-3 py-1.5 rounded-xl bg-accent-gradient text-white text-xs font-semibold shadow-xs cursor-pointer focus-visible:ring-2 focus-visible:ring-[var(--color-accent)]"
            >
              Load Recommended Model
            </button>
          </div>
        </div>
      ),
    },
    {
      id: 'ai-model-loading',
      category: 'ai',
      name: 'Model Loading',
      badgeText: 'GPU ALLOCATION',
      badgeVariant: 'accent',
      icon: <RefreshCw className="w-4 h-4 animate-spin text-[var(--color-accent)]" />,
      summary: 'Neural weights are being transferred into GPU VRAM with layer-by-layer progress.',
      accessibilityFeatures: [
        'Live percentage counter (68%) and offload metric (33 GPU layers)',
        'Progress bar with aria-valuenow="68"',
        'Cancel button available in case of VRAM overflow',
      ],
      diagnosticCode: 'AI_CORE_MODEL_TRANSFER',
      renderedComponent: (
        <div className="p-5 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <RefreshCw className="w-4 h-4 animate-spin text-[var(--color-accent)]" />
              <span className="text-xs font-bold text-[var(--color-text-primary)]">Allocating Llama-3.1-8B-Instruct (Q4_K_M)</span>
            </div>
            <span className="text-xs font-mono font-bold text-[var(--color-accent)]">68%</span>
          </div>
          <div className="w-full h-2 rounded-full surface-recessed overflow-hidden">
            <div className="h-full bg-accent-gradient w-[68%] transition-all duration-300 rounded-full" />
          </div>
          <div className="flex items-center justify-between text-[11px] text-[var(--color-text-muted)] font-mono">
            <span>Layers Offloaded: 22 / 33</span>
            <span>Allocating: 3.32 GB / 4.90 GB VRAM</span>
          </div>
        </div>
      ),
    },
    {
      id: 'ai-core-offline',
      category: 'ai',
      name: 'Local AI Core Offline',
      badgeText: 'DAEMON STOPPED',
      badgeVariant: 'danger',
      icon: <ServerOff className="w-4 h-4 text-rose-500" />,
      summary: 'The background inference daemon (llama.cpp / Ollama) is not responding on 127.0.0.1:8000.',
      accessibilityFeatures: [
        'Clear port indicator (:8000) and connection refusal reason',
        'One-click "Start Daemon" command dispatch',
        'Diagnostic copy code for CLI debugging',
      ],
      diagnosticCode: 'AI_ERR_LOCAL_CORE_OFFLINE',
      renderedComponent: (
        <div className="p-5 rounded-2xl bg-rose-500/10 border border-rose-500/30 space-y-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <ServerOff className="w-4 h-4 text-rose-500" />
              <h4 className="text-xs font-bold text-rose-600 dark:text-rose-400">Local AI Core Inactive</h4>
            </div>
            <Badge variant="danger" size="sm">Port 8000 Down</Badge>
          </div>
          <p className="text-xs text-[var(--color-text-secondary)]">
            Unable to connect to local llama.cpp server. Verify that the daemon binary is installed and not blocked by local firewall.
          </p>
          <div className="flex items-center gap-2">
            <button
              type="button"
              className="px-3 py-1.5 rounded-xl bg-rose-600 text-white text-xs font-semibold hover:bg-rose-700 cursor-pointer"
            >
              Start Local AI Core
            </button>
          </div>
        </div>
      ),
    },
    {
      id: 'ai-local-provider-unavailable',
      category: 'ai',
      name: 'Local Provider Unavailable',
      badgeText: 'ENGINE MISSING',
      badgeVariant: 'warning',
      icon: <AlertTriangle className="w-4 h-4 text-amber-500" />,
      summary: 'Selected engine (e.g. Ollama or vLLM) binary was not located in system PATH.',
      accessibilityFeatures: [
        'Explicit missing dependency notification',
        'Fallback recommendation to builtin llama.cpp engine',
        'Color + icon + text triple redundancy',
      ],
      diagnosticCode: 'AI_PROVIDER_BIN_NOT_FOUND',
      renderedComponent: (
        <div className="p-4 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex items-start gap-3">
          <AlertTriangle className="w-4 h-4 text-amber-500 flex-shrink-0 mt-0.5" />
          <div className="space-y-1 min-w-0 flex-1">
            <div className="flex items-center justify-between">
              <h4 className="text-xs font-bold text-[var(--color-text-primary)]">Ollama Provider Unavailable</h4>
              <button
                type="button"
                className="text-[11px] font-semibold text-[var(--color-accent)] hover:underline cursor-pointer"
              >
                Switch to llama.cpp
              </button>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)]">
              No response from /usr/local/bin/ollama. You can switch to the builtin embedded llama.cpp runtime with zero installation.
            </p>
          </div>
        </div>
      ),
    },
    {
      id: 'ai-cloud-fallback-unavailable',
      category: 'ai',
      name: 'Cloud Fallback Unavailable',
      badgeText: 'NO API KEY',
      badgeVariant: 'glass',
      icon: <ShieldAlert className="w-4 h-4 text-sky-400" />,
      summary: 'Complex prompt routing failed to reach cloud fallback due to missing credentials or airgap.',
      accessibilityFeatures: [
        'Security-first wording: No unexpected cloud leaks',
        'Clear indicator whether blocked by policy or missing key',
        'Inline action to configure key or force local processing',
      ],
      diagnosticCode: 'AI_CLOUD_FALLBACK_BLOCKED',
      renderedComponent: (
        <div className="p-4 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-2">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 text-xs font-bold text-[var(--color-text-primary)]">
              <ShieldAlert className="w-4 h-4 text-[var(--color-accent)]" />
              <span>Cloud Fallback Offline</span>
            </div>
            <Badge variant="glass" size="sm">Airgapped</Badge>
          </div>
          <p className="text-xs text-[var(--color-text-secondary)]">
            Cloud fallback was requested for high-context synthesis, but strict airgap mode is active. Processing redirected to local Qwen-2.5 model.
          </p>
        </div>
      ),
    },

    // ==========================================
    // 3. HEALTH (5 states)
    // ==========================================
    {
      id: 'hlth-no-smartwatch',
      category: 'health',
      name: 'No Smartwatch Paired',
      badgeText: 'NO HARDWARE',
      badgeVariant: 'glass',
      icon: <Watch className="w-4 h-4 text-[var(--color-text-muted)]" />,
      summary: 'No biometric optical sensor or BLE fitness watch is paired with this profile.',
      accessibilityFeatures: [
        'Direct pairing button with Bluetooth icon',
        'Clear notice that step accumulation and HR require hardware',
        'Manual metric entry available as fallback',
      ],
      diagnosticCode: 'HLTH_DEV_NO_WEARABLE',
      renderedComponent: (
        <div className="p-5 rounded-2xl surface-raised border border-[var(--color-border-subtle)] text-center space-y-3">
          <div className="w-10 h-10 rounded-full surface-recessed mx-auto flex items-center justify-center text-[var(--color-text-muted)]">
            <Watch className="w-5 h-5" />
          </div>
          <div>
            <h4 className="text-xs font-bold text-[var(--color-text-primary)]">No Smartwatch Detected</h4>
            <p className="text-[11px] text-[var(--color-text-secondary)] max-w-sm mx-auto mt-0.5">
              Pair your FitCloudPro, Garmin, or WearOS smartwatch to unlock 24/7 heart rate telemetry and sleep staging.
            </p>
          </div>
          <button
            type="button"
            className="px-3.5 py-1.5 rounded-xl bg-accent-gradient text-white text-xs font-semibold shadow-xs cursor-pointer"
          >
            Pair New Smartwatch
          </button>
        </div>
      ),
    },
    {
      id: 'hlth-hc-disconnected',
      category: 'health',
      name: 'Health Connect Disconnected',
      badgeText: 'BRIDGE UNLINKED',
      badgeVariant: 'warning',
      icon: <Link2Off className="w-4 h-4 text-amber-500" />,
      summary: 'Android Health Connect permissions or local synchronization bridge is unlinked.',
      accessibilityFeatures: [
        'Amber warning border + broken link icon',
        'Clear notice regarding Android 14 Health Connect schema',
        'Direct "Grant Permissions" trigger',
      ],
      diagnosticCode: 'HLTH_CONN_BRIDGE_REVOKED',
      renderedComponent: (
        <div className="p-4 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-between gap-3">
          <div className="flex items-center gap-2.5">
            <Link2Off className="w-4 h-4 text-amber-500 flex-shrink-0" />
            <div>
              <div className="text-xs font-bold text-[var(--color-text-primary)]">Android Health Connect Bridge Severed</div>
              <div className="text-[11px] text-[var(--color-text-secondary)]">Companion app permission was revoked or device rebooted.</div>
            </div>
          </div>
          <button
            type="button"
            className="px-3 py-1 rounded-xl bg-amber-500 text-white text-xs font-semibold cursor-pointer"
          >
            Re-Authorize
          </button>
        </div>
      ),
    },
    {
      id: 'hlth-partial-data',
      category: 'health',
      name: 'Partial Data Availability',
      badgeText: 'MISSING SENSORS',
      badgeVariant: 'warning',
      icon: <FileQuestion className="w-4 h-4 text-amber-500" />,
      summary: 'Some metrics (e.g. Heart Rate) are available while others (e.g. SpO2) are missing.',
      accessibilityFeatures: [
        'Strict non-fabrication adherence: Displays explicit unavailable badge',
        'No interpolated fake graph lines or misleading averages',
        'Provider capability checklist included',
      ],
      diagnosticCode: 'HLTH_PARTIAL_SPO2_ABSENT',
      renderedComponent: (
        <div className="p-4 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-2">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2 text-xs font-bold text-[var(--color-text-primary)]">
              <Activity className="w-4 h-4 text-emerald-500" />
              <span>HR Synced (72 bpm)</span>
              <span>•</span>
              <span className="text-amber-500">SpO2 Unavailable</span>
            </div>
            <Badge variant="warning" size="sm">Sensor Missing</Badge>
          </div>
          <p className="text-[11px] text-[var(--color-text-secondary)]">
            FitCloudPro device does not report SpO2 continuous data streams. Sleep and HR telemetry remain 100% authentic.
          </p>
        </div>
      ),
    },
    {
      id: 'hlth-stale-data',
      category: 'health',
      name: 'Stale Health Data',
      badgeText: 'OUTDATED (3d)',
      badgeVariant: 'glass',
      icon: <Clock className="w-4 h-4 text-[var(--color-text-muted)]" />,
      summary: 'Sensor telemetry is valid but has not refreshed within the expected 24h window.',
      accessibilityFeatures: [
        'Clear timestamp of last synchronization ("3 days ago at 08:30 AM")',
        'Subdued visual styling to denote non-current figures',
        'Manual sync refresh control with spinner state',
      ],
      diagnosticCode: 'HLTH_TELEMETRY_STALE',
      renderedComponent: (
        <div className="p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex items-center justify-between gap-3">
          <div className="flex items-center gap-2.5">
            <Clock className="w-4 h-4 text-[var(--color-text-muted)]" />
            <div>
              <div className="text-xs font-bold text-[var(--color-text-primary)]">Telemetry Stale (Last synced: 3 days ago)</div>
              <div className="text-[11px] text-[var(--color-text-secondary)]">Sync watch via companion Bluetooth to view today's active metrics.</div>
            </div>
          </div>
          <button
            type="button"
            className="px-3 py-1 rounded-xl surface-raised border border-[var(--color-border-subtle)] text-xs font-medium hover:text-[var(--color-accent)] cursor-pointer"
          >
            Force Sync
          </button>
        </div>
      ),
    },
    {
      id: 'hlth-unsupported-metric',
      category: 'health',
      name: 'Unsupported Metric',
      badgeText: 'HARDWARE LIMIT',
      badgeVariant: 'glass',
      icon: <ShieldAlert className="w-4 h-4 text-[var(--color-text-muted)]" />,
      summary: 'Requested telemetry (such as ECG or Blood Glucose) is physically absent on current hardware.',
      accessibilityFeatures: [
        'Explicit hardware limitation explanation',
        'Zero fake numbers or synthetic curves',
        'Disabled state with clear explanatory tooltip',
      ],
      diagnosticCode: 'HLTH_METRIC_NOT_SUPPORTED',
      renderedComponent: (
        <div className="p-4 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] opacity-75 flex items-center justify-between gap-3">
          <div>
            <div className="text-xs font-bold text-[var(--color-text-secondary)]">VO2 Max & Medical ECG</div>
            <div className="text-[11px] text-[var(--color-text-muted)]">Unsupported by paired hardware (FitCloudPro FT-90)</div>
          </div>
          <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-[var(--color-surface-secondary)] text-[var(--color-text-muted)]">N/A</span>
        </div>
      ),
    },

    // ==========================================
    // 4. DEVICES (3 states)
    // ==========================================
    {
      id: 'dev-phone-disconnected',
      category: 'devices',
      name: 'Phone Disconnected',
      badgeText: 'DEVICE OFFLINE',
      badgeVariant: 'warning',
      icon: <Smartphone className="w-4 h-4 text-amber-500" />,
      summary: 'Android companion phone mesh connection timed out or socket was closed.',
      accessibilityFeatures: [
        'Amber warning card with phone icon and strike-through badge',
        'Last seen telemetry ping counter ("Last seen 12m ago")',
        'Clear troubleshooting step: Wake phone or verify local Wi-Fi mesh',
      ],
      diagnosticCode: 'DEV_COMPANION_DROPPED',
      renderedComponent: (
        <div className="p-4 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-xl bg-amber-500/20 text-amber-600 dark:text-amber-400 flex items-center justify-center">
              <Smartphone className="w-4 h-4" />
            </div>
            <div>
              <div className="text-xs font-bold text-[var(--color-text-primary)]">Pixel 8 Pro Disconnected</div>
              <div className="text-[11px] text-[var(--color-text-secondary)]">P2P mesh socket lost. Notification relay paused.</div>
            </div>
          </div>
          <button
            type="button"
            className="px-3 py-1 rounded-xl bg-amber-500 text-white text-xs font-semibold cursor-pointer"
          >
            Ping Device
          </button>
        </div>
      ),
    },
    {
      id: 'dev-bt-disconnected',
      category: 'devices',
      name: 'Bluetooth Output Disconnected',
      badgeText: 'AUDIO FALLBACK',
      badgeVariant: 'glass',
      icon: <Bluetooth className="w-4 h-4 text-sky-400" />,
      summary: 'Bluetooth wireless headset disconnected; system automatically reverted to desktop speakers.',
      accessibilityFeatures: [
        'Notice of seamless audio fallback prevents sudden silence panic',
        'Visual confirmation of active output device',
        'Auto-reconnect toggle switch',
      ],
      diagnosticCode: 'DEV_BT_AUDIO_ROUTED_DEFAULT',
      renderedComponent: (
        <div className="p-4 rounded-2xl surface-raised border border-[var(--color-border-subtle)] flex items-center justify-between gap-3">
          <div className="flex items-center gap-2.5">
            <Bluetooth className="w-4 h-4 text-sky-400" />
            <div>
              <div className="text-xs font-bold text-[var(--color-text-primary)]">Sony WH-1000XM5 Disconnected</div>
              <div className="text-[11px] text-[var(--color-text-secondary)]">Audio routed to: Realtek High Definition Audio (Default)</div>
            </div>
          </div>
          <Badge variant="glass" size="sm">Fallback Active</Badge>
        </div>
      ),
    },
    {
      id: 'dev-mic-unavailable',
      category: 'devices',
      name: 'Microphone Unavailable',
      badgeText: 'MIC MUTED/BUSY',
      badgeVariant: 'danger',
      icon: <MicOff className="w-4 h-4 text-rose-500" />,
      summary: 'Hardware microphone is claimed by another application or OS permission was denied.',
      accessibilityFeatures: [
        'Crimson alert card with strike-through microphone glyph',
        'Clear explanation: OS microphone privacy lock',
        'Direct link to system sound settings',
      ],
      diagnosticCode: 'DEV_AUDIO_MIC_PERMISSION_REVOKED',
      renderedComponent: (
        <div className="p-4 rounded-2xl bg-rose-500/10 border border-rose-500/30 flex items-center justify-between gap-3">
          <div className="flex items-center gap-2.5">
            <MicOff className="w-4 h-4 text-rose-500" />
            <div>
              <div className="text-xs font-bold text-rose-600 dark:text-rose-400">Microphone Input Unavailable</div>
              <div className="text-[11px] text-[var(--color-text-secondary)]">Input is locked in exclusive mode by another process or privacy setting.</div>
            </div>
          </div>
          <button
            type="button"
            className="px-3 py-1 rounded-xl bg-rose-600 text-white text-xs font-semibold cursor-pointer"
          >
            Check Device
          </button>
        </div>
      ),
    },

    // ==========================================
    // 5. TASKS (3 states)
    // ==========================================
    {
      id: 'task-no-tasks',
      category: 'tasks',
      name: 'No Tasks in Current View',
      badgeText: 'ALL CLEAR',
      badgeVariant: 'success',
      icon: <CheckCircle2 className="w-4 h-4 text-emerald-500" />,
      summary: 'All scheduled tasks for this category have been marked complete.',
      accessibilityFeatures: [
        'Positive reinforcement card with green check icon',
        'Clear action button to add a new task',
        'Clean, uncluttered visual rhythm',
      ],
      diagnosticCode: 'TASK_LIST_ZERO_PENDING',
      renderedComponent: (
        <div className="p-6 rounded-2xl surface-raised border border-[var(--color-border-subtle)] text-center space-y-3">
          <div className="w-10 h-10 rounded-full bg-emerald-500/15 text-emerald-500 mx-auto flex items-center justify-center">
            <CheckCircle2 className="w-5 h-5" />
          </div>
          <div>
            <h4 className="text-xs font-bold text-[var(--color-text-primary)]">All Tasks Complete</h4>
            <p className="text-[11px] text-[var(--color-text-secondary)] mt-0.5">Nothing due today. Enjoy your focus block!</p>
          </div>
          <button
            type="button"
            className="px-3.5 py-1.5 rounded-xl bg-accent-gradient text-white text-xs font-semibold cursor-pointer"
          >
            + Create New Task
          </button>
        </div>
      ),
    },
    {
      id: 'task-overdue',
      category: 'tasks',
      name: 'Overdue Task Alert',
      badgeText: 'PAST DUE',
      badgeVariant: 'danger',
      icon: <AlertCircle className="w-4 h-4 text-rose-500" />,
      summary: 'Task due date and time have lapsed without completion confirmation.',
      accessibilityFeatures: [
        'Rose warning badge with past-due elapsed time',
        'Strikethrough prevention: Overdue status clearly highlighted before title',
        'Quick snooze or reschedule action buttons with visible focus rings',
      ],
      diagnosticCode: 'TASK_ITEM_OVERDUE_ALERT',
      renderedComponent: (
        <div className="p-4 rounded-2xl bg-rose-500/10 border border-rose-500/30 flex items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-xl bg-rose-500 text-white flex items-center justify-center flex-shrink-0">
              <AlertCircle className="w-4 h-4" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xs font-bold text-[var(--color-text-primary)]">Quantization throughput test</span>
                <span className="text-[9px] font-mono px-1.5 py-0.2 rounded bg-rose-500 text-white font-bold">OVERDUE (2h)</span>
              </div>
              <div className="text-[11px] text-rose-600 dark:text-rose-400 mt-0.5">Was due at 09:00 AM today</div>
            </div>
          </div>
          <div className="flex items-center gap-1.5">
            <button
              type="button"
              className="px-2.5 py-1 rounded-lg surface-raised text-xs font-medium cursor-pointer"
            >
              Reschedule
            </button>
            <button
              type="button"
              className="px-2.5 py-1 rounded-lg bg-emerald-600 text-white text-xs font-semibold cursor-pointer"
            >
              Done
            </button>
          </div>
        </div>
      ),
    },
    {
      id: 'task-sync-pending',
      category: 'tasks',
      name: 'Sync Pending (Offline Queue)',
      badgeText: 'LOCAL CACHE',
      badgeVariant: 'accent',
      icon: <RotateCcw className="w-4 h-4 animate-spin text-[var(--color-accent)]" />,
      summary: 'Task changes are cached locally and awaiting companion socket synchronization.',
      accessibilityFeatures: [
        'Sync pending icon and queue item counter (2 changes queued)',
        'Guaranteed non-data loss notice: Saved in SQLite database',
        'Manual "Sync Now" button',
      ],
      diagnosticCode: 'TASK_OFFLINE_MUTATION_QUEUED',
      renderedComponent: (
        <div className="p-4 rounded-2xl surface-raised border border-[var(--color-border-subtle)] flex items-center justify-between gap-3">
          <div className="flex items-center gap-2.5">
            <RotateCcw className="w-4 h-4 text-[var(--color-accent)]" />
            <div>
              <div className="text-xs font-bold text-[var(--color-text-primary)]">2 Task Updates Queued for Sync</div>
              <div className="text-[11px] text-[var(--color-text-secondary)]">Safely cached in local storage. Will sync to phone when link is restored.</div>
            </div>
          </div>
          <button
            type="button"
            className="px-3 py-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-xs font-medium hover:text-[var(--color-accent)] cursor-pointer"
          >
            Retry Sync
          </button>
        </div>
      ),
    },

    // ==========================================
    // 6. ASSISTANT (6 states)
    // ==========================================
    {
      id: 'ast-idle',
      category: 'assistant',
      name: 'Assistant: Idle',
      badgeText: 'STANDBY',
      badgeVariant: 'glass',
      icon: <Bot className="w-4 h-4 text-[var(--color-text-muted)]" />,
      summary: 'Assistant is awaiting keyboard command, hotkey prompt, or voice wake word.',
      accessibilityFeatures: [
        'Subtle status indicator with ready state description',
        'High contrast text and accessible keyboard focus',
        'Zero distracting animations during idle mode',
      ],
      diagnosticCode: 'AST_STATE_IDLE_READY',
      renderedComponent: (
        <div className="p-4 rounded-2xl surface-raised border border-[var(--color-border-subtle)] flex items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-xl surface-recessed text-[var(--color-accent)] flex items-center justify-center border border-[var(--color-border-subtle)]">
              <Bot className="w-4 h-4" />
            </div>
            <div>
              <div className="text-xs font-bold text-[var(--color-text-primary)]">Aura is Idle & Ready</div>
              <div className="text-[11px] text-[var(--color-text-secondary)]">Listening for "Hey Aura" or Enter key prompt</div>
            </div>
          </div>
          <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-[var(--color-surface-secondary)] text-[var(--color-text-secondary)] font-semibold">IDLE</span>
        </div>
      ),
    },
    {
      id: 'ast-listening',
      category: 'assistant',
      name: 'Assistant: Listening',
      badgeText: 'AUDIO TRANSCRIBING',
      badgeVariant: 'danger',
      icon: <Mic className="w-4 h-4 text-rose-500 animate-pulse" />,
      summary: 'Local Whisper audio transcription is capturing microphone input in real time.',
      accessibilityFeatures: [
        'Pulsing microphone icon + live audio waveform feedback',
        'aria-live="polite" captioning region',
        'Prominent escape/cancel button to immediately cut microphone capture',
      ],
      diagnosticCode: 'AST_STATE_VAD_CAPTURING',
      renderedComponent: (
        <div className="p-4 rounded-2xl bg-rose-500/10 border border-rose-500/30 flex items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-xl bg-rose-500 text-white flex items-center justify-center animate-pulse">
              <Mic className="w-4 h-4" />
            </div>
            <div>
              <div className="text-xs font-bold text-rose-600 dark:text-rose-400">Listening to voice input...</div>
              <div className="text-[11px] text-[var(--color-text-secondary)]">Local Whisper-large-v3 model active on GPU</div>
            </div>
          </div>
          <div className="flex items-center gap-1">
            <span className="w-1 h-3 bg-rose-500 rounded-full animate-bounce" style={{ animationDelay: '0ms' }} />
            <span className="w-1 h-5 bg-rose-500 rounded-full animate-bounce" style={{ animationDelay: '150ms' }} />
            <span className="w-1 h-4 bg-rose-500 rounded-full animate-bounce" style={{ animationDelay: '300ms' }} />
          </div>
        </div>
      ),
    },
    {
      id: 'ast-thinking',
      category: 'assistant',
      name: 'Assistant: Thinking',
      badgeText: 'INFERENCE COMPUTING',
      badgeVariant: 'accent',
      icon: <Brain className="w-4 h-4 text-[var(--color-accent)] animate-pulse" />,
      summary: 'Local neural network is evaluating prompt, retrieving context, and generating tokens.',
      accessibilityFeatures: [
        'Animated pulse + explicit token prediction speed indicator',
        'aria-busy="true" declared',
        'Stop generating button available immediately',
      ],
      diagnosticCode: 'AST_STATE_TOKEN_GENERATION',
      renderedComponent: (
        <div className="p-4 rounded-2xl surface-raised border border-[var(--color-accent)]/40 flex items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-xl bg-accent-gradient text-white flex items-center justify-center">
              <Brain className="w-4 h-4 animate-pulse" />
            </div>
            <div>
              <div className="text-xs font-bold text-[var(--color-text-primary)]">Synthesizing response...</div>
              <div className="text-[11px] text-[var(--color-text-secondary)]">Evaluating local context • 42.4 tok/sec</div>
            </div>
          </div>
          <button
            type="button"
            className="px-3 py-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-xs font-medium text-rose-500 hover:bg-rose-500/10 cursor-pointer"
          >
            Stop
          </button>
        </div>
      ),
    },
    {
      id: 'ast-speaking',
      category: 'assistant',
      name: 'Assistant: Speaking',
      badgeText: 'TTS SYNTHESIS',
      badgeVariant: 'accent',
      icon: <Volume2 className="w-4 h-4 text-emerald-500 animate-bounce" />,
      summary: 'Neural speech synthesis (Piper / Kokoro) is actively delivering vocal response.',
      accessibilityFeatures: [
        'Clear speech volume indicator and audio mute control',
        'Simultaneous text transcript rendered on screen',
        'Immediate interrupt response on user keypress or speech',
      ],
      diagnosticCode: 'AST_STATE_TTS_SPEAKING',
      renderedComponent: (
        <div className="p-4 rounded-2xl surface-raised border border-emerald-500/40 flex items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-xl bg-emerald-500 text-white flex items-center justify-center">
              <Volume2 className="w-4 h-4" />
            </div>
            <div>
              <div className="text-xs font-bold text-[var(--color-text-primary)]">Speaking voice answer</div>
              <div className="text-[11px] text-[var(--color-text-secondary)]">Kokoro-v1.0 (en-US) • Outputting to Default Audio</div>
            </div>
          </div>
          <button
            type="button"
            className="px-3 py-1 rounded-xl bg-emerald-500 text-white text-xs font-semibold cursor-pointer"
          >
            Mute Voice
          </button>
        </div>
      ),
    },
    {
      id: 'ast-interrupted',
      category: 'assistant',
      name: 'Assistant: Interrupted',
      badgeText: 'USER PRIORITY',
      badgeVariant: 'warning',
      icon: <AlertTriangle className="w-4 h-4 text-amber-500" />,
      summary: 'Assistant speech generation halted immediately when user barged in with speech or click.',
      accessibilityFeatures: [
        'User priority protocol acknowledged',
        'Amber warning card confirms speech synthesis was stopped cleanly',
        'Instant re-engagement ready without system lockup',
      ],
      diagnosticCode: 'AST_STATE_BARGE_IN_HALT',
      renderedComponent: (
        <div className="p-4 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-xl bg-amber-500 text-white flex items-center justify-center">
              <AlertTriangle className="w-4 h-4" />
            </div>
            <div>
              <div className="text-xs font-bold text-[var(--color-text-primary)]">Vocal Output Interrupted</div>
              <div className="text-[11px] text-[var(--color-text-secondary)]">Speech output halted on user barge-in. Ready for next command.</div>
            </div>
          </div>
          <Badge variant="warning" size="sm">Barge-in Safe</Badge>
        </div>
      ),
    },
    {
      id: 'ast-reconnecting',
      category: 'assistant',
      name: 'Assistant: Reconnecting',
      badgeText: 'SOCKET RECOVER',
      badgeVariant: 'accent',
      icon: <RefreshCw className="w-4 h-4 animate-spin text-[var(--color-accent)]" />,
      summary: 'Assistant daemon connection lost and actively attempting socket handshake recovery.',
      accessibilityFeatures: [
        'Rotating icon + live exponential backoff countdown',
        'State announcement for screen readers',
        'Manual retry control prevents user helplessness',
      ],
      diagnosticCode: 'AST_STATE_SOCKET_RECONNECT',
      renderedComponent: (
        <div className="p-4 rounded-2xl surface-raised border border-[var(--color-border-subtle)] flex items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-xl surface-recessed text-[var(--color-accent)] flex items-center justify-center">
              <RefreshCw className="w-4 h-4 animate-spin" />
            </div>
            <div>
              <div className="text-xs font-bold text-[var(--color-text-primary)]">Reconnecting to Neural Service...</div>
              <div className="text-[11px] text-[var(--color-text-secondary)]">Attempting handshake with port 8000 (2s retry)</div>
            </div>
          </div>
          <button
            type="button"
            className="px-3 py-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-xs font-medium text-[var(--color-accent)] cursor-pointer"
          >
            Reconnect Now
          </button>
        </div>
      ),
    },
  ];

  // Filtering by category and search
  const filteredStates = stateExamples.filter((item) => {
    if (selectedCategory !== 'all' && item.category !== selectedCategory) {
      return false;
    }
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      return (
        item.name.toLowerCase().includes(q) ||
        item.summary.toLowerCase().includes(q) ||
        item.diagnosticCode.toLowerCase().includes(q) ||
        item.category.toLowerCase().includes(q)
      );
    }
    return true;
  });

  const categories: { id: StateCategory; label: string; count: number }[] = [
    { id: 'all', label: 'All States', count: stateExamples.length },
    { id: 'general', label: 'General', count: stateExamples.filter((s) => s.category === 'general').length },
    { id: 'ai', label: 'AI Runtime', count: stateExamples.filter((s) => s.category === 'ai').length },
    { id: 'health', label: 'Health', count: stateExamples.filter((s) => s.category === 'health').length },
    { id: 'devices', label: 'Devices', count: stateExamples.filter((s) => s.category === 'devices').length },
    { id: 'tasks', label: 'Tasks', count: stateExamples.filter((s) => s.category === 'tasks').length },
    { id: 'assistant', label: 'Assistant', count: stateExamples.filter((s) => s.category === 'assistant').length },
  ];

  return (
    <div id="application-states-showcase" className="space-y-6 animate-in fade-in duration-200">
      {/* 1. Header Banner */}
      <div className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-2xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm flex-shrink-0 shadow-md">
            <Layers className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2 flex-wrap">
              <h2 className="text-lg sm:text-xl font-bold text-[var(--color-text-primary)]">
                Application States & System Resiliency
              </h2>
              <Badge variant="accent" size="sm">
                27 Verified States
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] mt-0.5 max-w-2xl">
              Comprehensive reference matrix for edge cases, error boundaries, hardware disconnects, and accessibility compliance.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 self-start md:self-auto">
          <Badge variant="glass" size="sm" className="font-mono text-[11px]">
            WCAG AA Compliant
          </Badge>
        </div>
      </div>

      {/* 2. Category Navigation Tabs + Search Bar */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3">
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 no-scrollbar">
          {categories.map((cat) => {
            const isActive = selectedCategory === cat.id;
            return (
              <button
                key={cat.id}
                type="button"
                onClick={() => setSelectedCategory(cat.id)}
                className={`px-3 py-1.5 rounded-xl text-xs font-semibold flex items-center gap-1.5 whitespace-nowrap transition-all cursor-pointer select-none ${
                  isActive
                    ? 'surface-raised text-[var(--color-accent)] border border-[var(--color-accent)]/40 shadow-xs'
                    : 'surface-base text-[var(--color-text-secondary)] border border-[var(--color-border-subtle)] hover:text-[var(--color-text-primary)]'
                }`}
              >
                <span>{cat.label}</span>
                <span className={`text-[10px] px-1.5 py-0.2 rounded-full font-mono ${isActive ? 'bg-[var(--color-accent)]/15 text-[var(--color-accent)]' : 'surface-recessed text-[var(--color-text-muted)]'}`}>
                  {cat.count}
                </span>
              </button>
            );
          })}
        </div>

        <div className="w-full sm:w-64 flex-shrink-0">
          <SearchInput
            value={searchQuery}
            onChangeValue={setSearchQuery}
            placeholder="Search state or code..."
          />
        </div>
      </div>

      {/* 3. States Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        {filteredStates.map((state) => (
          <div
            key={state.id}
            id={`state-card-${state.id}`}
            className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4 shadow-sm flex flex-col justify-between hover:border-[var(--color-accent)]/30 transition-all"
          >
            {/* Top Bar: Title, Category, Badge */}
            <div>
              <div className="flex items-center justify-between gap-2 mb-1.5">
                <div className="flex items-center gap-2">
                  <div className="w-6 h-6 rounded-lg surface-recessed flex items-center justify-center border border-[var(--color-border-subtle)] flex-shrink-0">
                    {state.icon}
                  </div>
                  <h3 className="text-sm font-bold text-[var(--color-text-primary)]">
                    {state.name}
                  </h3>
                </div>
                <Badge variant={state.badgeVariant} size="sm">
                  {state.badgeText}
                </Badge>
              </div>

              <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed">
                {state.summary}
              </p>
            </div>

            {/* Live Rendered Component */}
            <div className="pt-1">
              <span className="text-[10px] font-mono text-[var(--color-text-muted)] uppercase tracking-wider block mb-1.5">
                Polished UI Render:
              </span>
              {state.renderedComponent}
            </div>

            {/* Accessibility Audit Notes & Diagnostic Payload */}
            <div className="pt-3 border-t border-[var(--color-border-subtle)] space-y-2">
              <div className="space-y-1">
                <span className="text-[10px] font-semibold text-[var(--color-text-secondary)] flex items-center gap-1">
                  <ShieldCheck className="w-3 h-3 text-emerald-500" />
                  <span>Accessibility & Non-Color Redundancy:</span>
                </span>
                <ul className="text-[11px] text-[var(--color-text-muted)] space-y-0.5 list-disc list-inside">
                  {state.accessibilityFeatures.map((feat, idx) => (
                    <li key={idx}>{feat}</li>
                  ))}
                </ul>
              </div>

              <div className="flex items-center justify-between pt-2 text-[10px] font-mono text-[var(--color-text-muted)]">
                <div className="flex items-center gap-1.5">
                  <span>Diagnostic:</span>
                  <span className="text-[var(--color-accent)] font-semibold">{state.diagnosticCode}</span>
                </div>

                <button
                  type="button"
                  onClick={() => handleCopy(state.diagnosticCode)}
                  className="flex items-center gap-1 px-2 py-0.5 rounded surface-recessed hover:text-[var(--color-text-primary)] cursor-pointer transition-colors"
                  title="Copy diagnostic code"
                >
                  {copiedCode === state.diagnosticCode ? (
                    <>
                      <Check className="w-2.5 h-2.5 text-emerald-500" />
                      <span className="text-emerald-500 font-bold">Copied</span>
                    </>
                  ) : (
                    <>
                      <Copy className="w-2.5 h-2.5" />
                      <span>Copy Code</span>
                    </>
                  )}
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};
