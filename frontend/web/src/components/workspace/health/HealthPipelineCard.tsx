import React, { useState } from 'react';
import {
  ArrowRight,
  CheckCircle2,
  ChevronDown,
  Cpu,
  Layers,
  RefreshCw,
  Smartphone,
  Watch,
  Activity,
  Shield,
} from 'lucide-react';
import { Card } from '../../ui/Card';
import { Badge } from '../../ui/Badge';
import { HealthPipelineStage, HealthSourceProvider } from '../../../types';

interface HealthPipelineCardProps {
  selectedProvider: HealthSourceProvider;
  providers: HealthSourceProvider[];
  pipelineStages: HealthPipelineStage[];
  onSelectProvider: (provider: HealthSourceProvider) => void;
  isSyncing: boolean;
  onRefreshSync: () => void;
}

export const HealthPipelineCard: React.FC<HealthPipelineCardProps> = ({
  selectedProvider,
  providers,
  pipelineStages,
  onSelectProvider,
  isSyncing,
  onRefreshSync,
}) => {
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);

  return (
    <Card
      id="health-source-pipeline-card"
      variant="elevated"
      padding="md"
      className="space-y-4"
    >
      {/* Header with Source Architecture & Switcher */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-3 pb-3 border-b border-[var(--color-border-subtle)]">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm flex-shrink-0">
            <Layers className="w-4 h-4" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <span className="text-xs font-semibold text-[var(--color-text-secondary)] uppercase tracking-wider">
                Telemetry Pipeline & Ingestion Source
              </span>
              <Badge variant="success" size="sm" className="gap-1 font-mono">
                <CheckCircle2 className="w-3 h-3" />
                Live Sync
              </Badge>
            </div>
            <h2 className="text-sm font-bold text-[var(--color-text-primary)]">
              Multi-Tier Local Health Architecture
            </h2>
          </div>
        </div>

        {/* Source Switcher & Actions */}
        <div className="flex items-center gap-2 self-start md:self-auto relative">
          <div className="relative">
            <button
              id="health-source-provider-select"
              type="button"
              onClick={() => setIsDropdownOpen(!isDropdownOpen)}
              className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-xs font-semibold text-[var(--color-text-primary)] hover:border-[var(--color-accent)]/40 transition-colors cursor-pointer"
              title="Change active wearable source provider"
            >
              <Watch className="w-3.5 h-3.5 text-[var(--color-accent)]" />
              <span>Source: <strong className="text-[var(--color-accent)]">{selectedProvider.name}</strong></span>
              <ChevronDown className={`w-3.5 h-3.5 text-[var(--color-text-muted)] transition-transform ${isDropdownOpen ? 'rotate-180' : ''}`} />
            </button>

            {/* Provider Switcher Dropdown */}
            {isDropdownOpen && (
              <div
                id="health-source-dropdown-menu"
                className="absolute right-0 top-full mt-1.5 w-72 rounded-2xl surface-raised border border-[var(--color-border-highlight)] shadow-xl p-1.5 z-30 space-y-1"
              >
                <div className="px-2.5 py-1 text-[10px] font-semibold text-[var(--color-text-muted)] uppercase tracking-wider">
                  Configured Wearable Sources
                </div>
                {providers.map((p) => {
                  const isSelected = p.id === selectedProvider.id;
                  return (
                    <button
                      key={p.id}
                      type="button"
                      onClick={() => {
                        onSelectProvider(p);
                        setIsDropdownOpen(false);
                      }}
                      className={`w-full text-left px-3 py-2 rounded-xl text-xs flex items-start gap-2.5 transition-colors cursor-pointer ${
                        isSelected
                          ? 'surface-elevated text-[var(--color-accent)] border border-[var(--color-border-highlight)] font-semibold shadow-xs'
                          : 'text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] hover:bg-black/5 dark:hover:bg-white/5'
                      }`}
                    >
                      <Watch className="w-4 h-4 mt-0.5 flex-shrink-0" />
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between">
                          <span className="font-medium text-[var(--color-text-primary)]">{p.name}</span>
                          {isSelected && <span className="text-[10px] font-mono text-[var(--color-accent)] font-bold">Active</span>}
                        </div>
                        <p className="text-[11px] text-[var(--color-text-muted)] truncate">{p.deviceModel}</p>
                      </div>
                    </button>
                  );
                })}
                <div className="px-2.5 py-1.5 pt-2 border-t border-[var(--color-border-subtle)] text-[10px] text-[var(--color-text-muted)] flex items-center gap-1.5">
                  <Shield className="w-3 h-3 text-[var(--color-accent)]" />
                  <span>Configurable for any Health Connect compliant provider</span>
                </div>
              </div>
            )}
          </div>

          <button
            id="health-sync-refresh-btn"
            type="button"
            onClick={onRefreshSync}
            disabled={isSyncing}
            className="p-1.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] hover:border-[var(--color-accent)]/40 transition-colors cursor-pointer disabled:opacity-50"
            title="Poll for new telemetry batches"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isSyncing ? 'animate-spin text-[var(--color-accent)]' : ''}`} />
          </button>
        </div>
      </div>

      {/* The 4-Stage Ingestion Pipeline Flow: FitCloudPro → Health Connect → Mobile App → Local AI Core */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-2.5 relative">
        {pipelineStages.map((stage, idx) => {
          const getStageIcon = () => {
            switch (stage.step) {
              case 1:
                return <Watch className="w-4 h-4 text-[var(--color-accent)]" />;
              case 2:
                return <Activity className="w-4 h-4 text-emerald-500" />;
              case 3:
                return <Smartphone className="w-4 h-4 text-sky-500" />;
              case 4:
                return <Cpu className="w-4 h-4 text-violet-500" />;
              default:
                return <Layers className="w-4 h-4 text-[var(--color-accent)]" />;
            }
          };

          return (
            <div
              key={stage.step}
              id={`pipeline-step-${stage.step}`}
              className="p-3 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] flex flex-col justify-between relative group hover:border-[var(--color-border-highlight)] transition-colors"
            >
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <div className="w-6 h-6 rounded-lg surface-raised flex items-center justify-center border border-[var(--color-border-subtle)]">
                    {getStageIcon()}
                  </div>
                  <span className="text-[10px] font-mono font-bold text-[var(--color-text-muted)]">
                    STEP {stage.step}
                  </span>
                </div>
                {idx < pipelineStages.length - 1 && (
                  <ArrowRight className="w-3.5 h-3.5 text-[var(--color-text-muted)]/50 hidden lg:block absolute -right-2 top-1/2 -translate-y-1/2 z-10" />
                )}
              </div>

              <div>
                <div className="text-xs font-bold text-[var(--color-text-primary)] truncate">
                  {stage.label}
                </div>
                <div className="text-[11px] font-medium text-[var(--color-accent)]">
                  {stage.detail}
                </div>
                <div className="text-[10px] text-[var(--color-text-muted)] mt-0.5 truncate">
                  {stage.subtext}
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Provider Details & Capability Matrix */}
      <div className="p-3 rounded-2xl surface-base border border-[var(--color-border-subtle)] flex flex-col sm:flex-row sm:items-center justify-between gap-2.5 text-xs">
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-[var(--color-text-muted)]">Device:</span>
          <span className="font-semibold text-[var(--color-text-primary)]">{selectedProvider.deviceModel}</span>
          <span className="text-[var(--color-text-muted)]">•</span>
          <span className="text-[var(--color-text-muted)]">Last Sync:</span>
          <span className="font-mono text-[var(--color-text-secondary)]">{selectedProvider.lastSyncTime}</span>
          <span className="text-[var(--color-text-muted)]">•</span>
          <span className="text-[var(--color-text-muted)]">Samples:</span>
          <span className="font-mono text-[var(--color-accent)]">{selectedProvider.sampleCount.toLocaleString()}</span>
        </div>

        <div className="flex items-center gap-1.5 flex-wrap">
          <span className="text-[11px] text-[var(--color-text-muted)] mr-1">Capabilities:</span>
          <span className="px-2 py-0.5 rounded-md text-[10px] font-medium bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20">
            Continuous HR
          </span>
          <span
            className={`px-2 py-0.5 rounded-md text-[10px] font-medium border ${
              selectedProvider.supportsSpO2
                ? 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border-emerald-500/20'
                : 'bg-amber-500/10 text-amber-600 dark:text-amber-400 border-amber-500/20'
            }`}
          >
            {selectedProvider.supportsSpO2 ? 'SpO2 Spot' : 'No SpO2'}
          </span>
          <span
            className={`px-2 py-0.5 rounded-md text-[10px] font-medium border ${
              selectedProvider.supportsSleepStages
                ? 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border-emerald-500/20'
                : 'bg-black/5 dark:bg-white/5 text-[var(--color-text-muted)] border-[var(--color-border-subtle)]'
            }`}
          >
            {selectedProvider.supportsSleepStages ? 'Sleep Stages (REM)' : 'Duration Only'}
          </span>
        </div>
      </div>
    </Card>
  );
};
