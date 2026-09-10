import React, { useState } from 'react';
import { Wrench, Flame, Terminal, Code2, AlertCircle, RotateCcw, Check } from 'lucide-react';
import { Toggle } from '../../ui/Toggle';
import { Slider } from '../../ui/Slider';
import { NeumorphicButton } from '../../ui/NeumorphicButton';

export interface AdvancedSettingsState {
  developerMode: boolean;
  exposeSwaggerDocs: boolean;
  metalVulkanLogging: boolean;
  streamingThrottleMs: number;
  multiAgentDebate: boolean;
  voiceBargeIn: boolean;
  visionScreenAnalyzer: boolean;
}

interface AdvancedSectionProps {
  settings: AdvancedSettingsState;
  onUpdate: <K extends keyof AdvancedSettingsState>(key: K, value: AdvancedSettingsState[K]) => void;
  onResetAll: () => void;
}

export const AdvancedSection: React.FC<AdvancedSectionProps> = ({ settings, onUpdate, onResetAll }) => {
  const [showResetConfirm, setShowResetConfirm] = useState(false);
  const [resetSuccess, setResetSuccess] = useState(false);

  const confirmReset = () => {
    onResetAll();
    setShowResetConfirm(false);
    setResetSuccess(true);
    setTimeout(() => setResetSuccess(false), 3000);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h2 className="text-base font-bold text-[var(--color-text-primary)] flex items-center gap-2">
          <Wrench className="w-5 h-5 text-[var(--color-accent)]" />
          Advanced Developer & Experimental Lab
        </h2>
        <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
          Access low-level hardware debugging hooks, Swagger endpoints, and bleeding-edge autonomous experimental flags.
        </p>
      </div>

      {resetSuccess && (
        <div className="p-3.5 rounded-2xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-700 dark:text-emerald-300 text-xs flex items-center gap-2">
          <Check className="w-4 h-4 text-emerald-500" />
          <span>All application preferences and settings have been restored to factory defaults.</span>
        </div>
      )}

      {/* 1. Developer Settings */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
          <Terminal className="w-4 h-4" />
          Developer & Engine Tooling
        </h3>

        <div className="space-y-4">
          <div className="flex items-center justify-between gap-4">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Enable Developer Mode
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Unlocks raw token telemetry headers, model KV debug overlays, and latency breakdowns.
              </p>
            </div>
            <Toggle
              checked={settings.developerMode}
              onChange={(val) => onUpdate('developerMode', val)}
              size="sm"
            />
          </div>

          <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Expose FastAPI Interactive Swagger UI
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Mounts OpenAPI documentation endpoint at <code className="text-xs font-mono text-[var(--color-accent)]">http://127.0.0.1:8000/docs</code>.
              </p>
            </div>
            <Toggle
              checked={settings.exposeSwaggerDocs}
              onChange={(val) => onUpdate('exposeSwaggerDocs', val)}
              size="sm"
            />
          </div>

          <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Verbose Metal / Vulkan Kernel Logging
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Outputs GPU tensor memory barriers and shader dispatch times into the Event Viewer.
              </p>
            </div>
            <Toggle
              checked={settings.metalVulkanLogging}
              onChange={(val) => onUpdate('metalVulkanLogging', val)}
              size="sm"
            />
          </div>

          <div className="pt-3 border-t border-[var(--color-border-subtle)] space-y-2">
            <div className="flex items-center justify-between">
              <div>
                <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                  Token Streaming Delay Simulation
                </span>
                <p className="text-xs text-[var(--color-text-secondary)]">
                  Add artificial delay per token to inspect UI typing smoothness and frame stability.
                </p>
              </div>
              <span className="text-xs font-mono text-[var(--color-accent)] font-bold">
                {settings.streamingThrottleMs}ms delay
              </span>
            </div>
            <Slider
              value={settings.streamingThrottleMs}
              onChange={(val) => onUpdate('streamingThrottleMs', val)}
              min={0}
              max={100}
              step={5}
            />
          </div>
        </div>
      </div>

      {/* 2. Experimental Features */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-amber-500 flex items-center gap-1.5">
          <Flame className="w-4 h-4" />
          Experimental Research Flags
        </h3>

        <div className="space-y-4">
          <div className="flex items-center justify-between gap-4">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Multi-Agent Debate Mode
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Executes a dual-model critique loop (Llama-3.1 proposes, Qwen-2.5 challenges) before returning complex reasoning solutions.
              </p>
            </div>
            <Toggle
              checked={settings.multiAgentDebate}
              onChange={(val) => onUpdate('multiAgentDebate', val)}
              size="sm"
            />
          </div>

          <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Voice Barge-In / Real-time Interruption
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Instantly abort TTS audio synthesis and hardware speaker output the millisecond user starts speaking.
              </p>
            </div>
            <Toggle
              checked={settings.voiceBargeIn}
              onChange={(val) => onUpdate('voiceBargeIn', val)}
              size="sm"
            />
          </div>

          <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Local Vision Frame Analyzer (Llava-1.6)
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Enable local multi-modal screen capture analysis for coding and document questions.
              </p>
            </div>
            <Toggle
              checked={settings.visionScreenAnalyzer}
              onChange={(val) => onUpdate('visionScreenAnalyzer', val)}
              size="sm"
            />
          </div>
        </div>
      </div>

      {/* 3. Reset to Defaults */}
      <div className="p-5 rounded-3xl surface-raised border border-rose-500/20 space-y-3">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <h3 className="text-sm font-bold text-rose-600 dark:text-rose-400 flex items-center gap-1.5">
              <RotateCcw className="w-4 h-4" />
              Reset All Preferences
            </h3>
            <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
              Restore all 10 settings sections to pristine factory defaults.
            </p>
          </div>
          <NeumorphicButton
            variant="ghost"
            size="sm"
            onClick={() => setShowResetConfirm(true)}
            icon={<RotateCcw className="w-3.5 h-3.5 text-rose-500" />}
          >
            Reset to Defaults
          </NeumorphicButton>
        </div>

        {showResetConfirm && (
          <div className="p-4 rounded-2xl bg-rose-500/10 border border-rose-500/30 space-y-3 mt-3">
            <div className="flex items-start gap-2.5">
              <AlertCircle className="w-4 h-4 text-rose-500 flex-shrink-0 mt-0.5" />
              <p className="text-xs text-rose-700 dark:text-rose-300">
                Are you sure you want to reset all settings? This will revert your theme, voice model, audio devices, and custom parameters.
              </p>
            </div>
            <div className="flex items-center gap-2 pt-1">
              <button
                type="button"
                onClick={confirmReset}
                className="px-3 py-1.5 rounded-xl bg-rose-600 text-white font-semibold text-xs hover:bg-rose-700 transition-colors shadow-xs"
              >
                Yes, Reset Everything
              </button>
              <button
                type="button"
                onClick={() => setShowResetConfirm(false)}
                className="px-3 py-1.5 rounded-xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] text-xs font-semibold hover:text-[var(--color-text-primary)]"
              >
                Cancel
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
