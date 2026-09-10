import React from 'react';
import { Cpu, Zap, ShieldAlert, Sparkles, Server, Check } from 'lucide-react';
import { Toggle } from '../../ui/Toggle';
import { useTheme } from '../../../context/ThemeContext';

export interface AiSettingsState {
  modelRoutingStrategy: 'smart_auto' | 'always_primary' | 'speed_priority';
  primaryModelId: string;
  speculativeDecoding: boolean;
  performanceProfile: 'max_performance' | 'balanced' | 'power_saver';
  cloudFallbackPolicy: 'strict_airgap' | 'prompt_confirm' | 'hybrid_cloud';
  kvCacheQuantization: boolean;
  gpuLayerOffload: number; // 0 to 33
}

interface AiSectionProps {
  settings: AiSettingsState;
  onUpdate: <K extends keyof AiSettingsState>(key: K, value: AiSettingsState[K]) => void;
}

export const AiSection: React.FC<AiSectionProps> = ({ settings, onUpdate }) => {
  const { mode } = useTheme();

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h2 className="text-base font-bold text-[var(--color-text-primary)] flex items-center gap-2">
          <Cpu className="w-5 h-5 text-[var(--color-accent)]" />
          AI Architecture & Local Hardware Routing
        </h2>
        <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
          Tune inference dispatching across unified memory, manage thermal profiles, and enforce airgap rules.
        </p>
      </div>

      {/* 1. Model Routing */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
          <Sparkles className="w-4 h-4" />
          Intelligent Model Routing Strategy
        </h3>

        <div className="space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            {[
              {
                id: 'smart_auto',
                title: 'Smart Intent Routing',
                desc: 'Routes complex reasoning to Llama-3.1-8B, coding to Qwen-2.5, and rapid chitchat to Phi-3.5.',
              },
              {
                id: 'always_primary',
                title: 'Always Primary Model',
                desc: 'Bypasses multi-model router and dispatches all queries strictly to your selected primary model.',
              },
              {
                id: 'speed_priority',
                title: 'Latency Priority',
                desc: 'Prioritizes lightweight quantized models to maintain 60+ tokens/sec responsiveness.',
              },
            ].map((strat) => {
              const isSelected = settings.modelRoutingStrategy === strat.id;
              return (
                <button
                  key={strat.id}
                  type="button"
                  onClick={() => onUpdate('modelRoutingStrategy', strat.id as any)}
                  className={`p-4 rounded-2xl border text-left transition-all ${
                    isSelected
                      ? 'border-[var(--color-accent)] bg-[var(--color-surface-elevated)] ring-2 ring-[var(--color-accent)]/20 shadow-sm'
                      : 'border-[var(--color-border-subtle)] bg-[var(--color-surface-elevated)]/40 hover:bg-[var(--color-surface-elevated)]'
                  }`}
                >
                  <div className="flex items-center justify-between">
                    <h4 className="text-xs font-bold text-[var(--color-text-primary)]">
                      {strat.title}
                    </h4>
                    {isSelected && <Check className="w-3.5 h-3.5 text-[var(--color-accent)]" />}
                  </div>
                  <p className="text-xs text-[var(--color-text-secondary)] mt-1 leading-relaxed">
                    {strat.desc}
                  </p>
                </button>
              );
            })}
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-2">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-[var(--color-text-primary)]">
                Default Primary Local Model
              </label>
              <select
                value={settings.primaryModelId}
                onChange={(e) => onUpdate('primaryModelId', e.target.value)}
                style={{ colorScheme: mode }}
                className="w-full px-3.5 py-2.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] font-medium focus:outline-none focus:border-[var(--color-accent)] transition-all cursor-pointer shadow-xs"
              >
                <option value="llama-3.1-8b-instruct" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Llama-3.1-8B-Instruct (Q4_K_M - 4.9GB)</option>
                <option value="qwen-2.5-coder-7b" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Qwen-2.5-Coder-7B (Q5_K_M - 5.4GB)</option>
                <option value="phi-3.5-mini-3.8b" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Phi-3.5-Mini (Q4_K_S - 2.2GB)</option>
                <option value="mistral-nemo-12b" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Mistral-Nemo-12B (Q4_K_M - 7.1GB)</option>
              </select>
            </div>

            <div className="flex items-center justify-between p-3.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] self-end">
              <div>
                <span className="text-xs font-semibold text-[var(--color-text-primary)] block">
                  Speculative Decoding
                </span>
                <p className="text-[11px] text-[var(--color-text-secondary)]">
                  Use 1B draft model to accelerate token generation by 1.8x.
                </p>
              </div>
              <Toggle
                checked={settings.speculativeDecoding}
                onChange={(val) => onUpdate('speculativeDecoding', val)}
                size="sm"
              />
            </div>
          </div>
        </div>
      </div>

      {/* 2. Performance Profile */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
          <Zap className="w-4 h-4" />
          Default Hardware Performance Profile
        </h3>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          {[
            {
              id: 'max_performance',
              title: 'Max Performance',
              badge: 'Plugged In',
              desc: '100% GPU offload (33/33 layers in VRAM), 16k context window, unquantized f16 KV cache.',
            },
            {
              id: 'balanced',
              title: 'Balanced (Default)',
              badge: 'Recommended',
              desc: 'Optimized memory pressure, 8k context window, dynamic thermal throttling prevention.',
            },
            {
              id: 'power_saver',
              title: 'Power Saver',
              badge: 'Battery Optimized',
              desc: 'Quantized Q4_0 KV cache, reduces CPU/GPU peak draw by 40% on mobile laptop battery.',
            },
          ].map((profile) => {
            const isSelected = settings.performanceProfile === profile.id;
            return (
              <button
                key={profile.id}
                type="button"
                onClick={() => onUpdate('performanceProfile', profile.id as any)}
                className={`p-4 rounded-2xl border text-left transition-all relative flex flex-col justify-between ${
                  isSelected
                    ? 'border-[var(--color-accent)] bg-[var(--color-surface-elevated)] ring-2 ring-[var(--color-accent)]/20 shadow-sm'
                    : 'border-[var(--color-border-subtle)] bg-[var(--color-surface-elevated)]/40 hover:bg-[var(--color-surface-elevated)]'
                }`}
              >
                <div>
                  <div className="flex items-center justify-between">
                    <h4 className="text-xs font-bold text-[var(--color-text-primary)]">
                      {profile.title}
                    </h4>
                    <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[var(--color-surface-secondary)] text-[var(--color-text-muted)]">
                      {profile.badge}
                    </span>
                  </div>
                  <p className="text-xs text-[var(--color-text-secondary)] mt-1 leading-relaxed">
                    {profile.desc}
                  </p>
                </div>
              </button>
            );
          })}
        </div>
      </div>

      {/* 3. Cloud Fallback */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
            <ShieldAlert className="w-4 h-4" />
            Cloud Fallback & Airgap Security Policy
          </h3>
          <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-emerald-600 dark:text-emerald-400 font-bold">
            Airgap Active
          </span>
        </div>

        <div className="space-y-3">
          {[
            {
              id: 'strict_airgap',
              title: 'Strict Local Airgap (100% Offline)',
              desc: 'Never transmit prompts or context to any external server. If local compute is saturated, queue or fail gracefully.',
              secure: true,
            },
            {
              id: 'prompt_confirm',
              title: 'Prompt for Confirmation',
              desc: 'Ask for explicit user permission with a detailed payload review modal before attempting external inference.',
              secure: false,
            },
            {
              id: 'hybrid_cloud',
              title: 'Transparent Hybrid Cloud Fallback',
              desc: 'Automatically offload queries requiring 70B+ parameters to privacy-hardened zero-retention cloud endpoints.',
              secure: false,
            },
          ].map((policy) => {
            const isSelected = settings.cloudFallbackPolicy === policy.id;
            return (
              <button
                key={policy.id}
                type="button"
                onClick={() => onUpdate('cloudFallbackPolicy', policy.id as any)}
                className={`w-full p-4 rounded-2xl border text-left transition-all flex items-start justify-between gap-3 ${
                  isSelected
                    ? 'border-[var(--color-accent)] bg-[var(--color-surface-elevated)] ring-2 ring-[var(--color-accent)]/20 shadow-sm'
                    : 'border-[var(--color-border-subtle)] bg-[var(--color-surface-elevated)]/40 hover:bg-[var(--color-surface-elevated)]'
                }`}
              >
                <div>
                  <div className="flex items-center gap-2">
                    <h4 className="text-sm font-semibold text-[var(--color-text-primary)]">
                      {policy.title}
                    </h4>
                    {policy.secure && (
                      <span className="text-[10px] font-mono px-2 py-0.2 rounded-full bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 font-bold">
                        Zero Data Exfiltration
                      </span>
                    )}
                  </div>
                  <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
                    {policy.desc}
                  </p>
                </div>
                {isSelected && <Check className="w-4 h-4 text-[var(--color-accent)] flex-shrink-0 mt-1" />}
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
};
