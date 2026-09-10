import React from 'react';
import { Cpu, Server, Cloud, CheckCircle2, RefreshCw, Layers, ExternalLink } from 'lucide-react';
import { Badge } from '../../ui/Badge';
import { Card } from '../../ui/Card';
import { ModelProviderInfo, ModelProviderType } from '../../../types';

interface ModelProvidersCardProps {
  providers: ModelProviderInfo[];
  activeProviderFilter: ModelProviderType | 'all';
  onSelectProviderFilter: (provider: ModelProviderType | 'all') => void;
  onRefreshProvider?: (providerId: ModelProviderType) => void;
}

export const ModelProvidersCard: React.FC<ModelProvidersCardProps> = ({
  providers,
  activeProviderFilter,
  onSelectProviderFilter,
  onRefreshProvider,
}) => {
  return (
    <Card id="model-providers-card" className="space-y-4">
      {/* Header with Replaceable Architecture Badge */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-2 border-b border-[var(--color-border-subtle)]">
        <div>
          <div className="flex items-center gap-2">
            <h2 className="text-sm sm:text-base font-semibold text-[var(--color-text-primary)]">
              Replaceable Inference Providers
            </h2>
            <Badge variant="accent" size="sm">
              Multi-Runtime Architecture
            </Badge>
          </div>
          <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
            Local AI Core orchestrates modular backends without hardcoding to a single runtime.
          </p>
        </div>

        {/* Filter segment controls */}
        <div className="flex items-center gap-1 p-1 rounded-xl surface-recessed border border-[var(--color-border-subtle)] self-start sm:self-auto">
          <button
            type="button"
            onClick={() => onSelectProviderFilter('all')}
            className={`px-2.5 py-1 text-xs rounded-lg transition-all ${
              activeProviderFilter === 'all'
                ? 'surface-raised font-semibold text-[var(--color-accent)] shadow-sm'
                : 'text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
            }`}
          >
            All Providers ({providers.length})
          </button>
          {providers.map((p) => (
            <button
              key={p.id}
              type="button"
              onClick={() => onSelectProviderFilter(p.id)}
              className={`px-2.5 py-1 text-xs rounded-lg transition-all capitalize ${
                activeProviderFilter === p.id
                  ? 'surface-raised font-semibold text-[var(--color-accent)] shadow-sm'
                  : 'text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
              }`}
            >
              {p.id}
            </button>
          ))}
        </div>
      </div>

      {/* Provider Cards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3.5">
        {providers.map((provider) => {
          const isSelected = activeProviderFilter === provider.id;
          const isLocal = provider.type === 'local';

          return (
            <div
              key={provider.id}
              onClick={() =>
                onSelectProviderFilter(
                  activeProviderFilter === provider.id ? 'all' : provider.id
                )
              }
              className={`p-4 rounded-2xl border transition-all cursor-pointer select-none relative group ${
                isSelected
                  ? 'surface-raised border-[var(--color-accent)] ring-2 ring-[var(--color-accent)]/20 shadow-md'
                  : 'surface-base border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 hover:shadow-sm'
              }`}
            >
              {/* Top Row: Icon & Status */}
              <div className="flex items-start justify-between gap-2 mb-2.5">
                <div className="flex items-center gap-2.5">
                  <div
                    className={`w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 shadow-sm ${
                      isLocal
                        ? 'bg-sky-500/10 dark:bg-sky-500/20 text-sky-500 border border-sky-500/30'
                        : 'bg-violet-500/10 dark:bg-violet-500/20 text-violet-500 border border-violet-500/30'
                    }`}
                  >
                    {provider.id === 'llama.cpp' ? (
                      <Cpu className="w-4 h-4" />
                    ) : provider.id === 'ollama' ? (
                      <Server className="w-4 h-4" />
                    ) : (
                      <Cloud className="w-4 h-4" />
                    )}
                  </div>
                  <div>
                    <div className="flex items-center gap-1.5">
                      <span className="text-sm font-bold text-[var(--color-text-primary)]">
                        {provider.name}
                      </span>
                    </div>
                    <span className="text-[11px] text-[var(--color-text-muted)] font-mono block truncate max-w-[140px]">
                      {provider.version}
                    </span>
                  </div>
                </div>

                <Badge
                  variant={
                    provider.status === 'running' || provider.status === 'connected'
                      ? 'success'
                      : 'warning'
                  }
                  size="sm"
                >
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse mr-1" />
                  {provider.status === 'running'
                    ? 'Running'
                    : provider.status === 'connected'
                    ? 'Connected'
                    : 'Standby'}
                </Badge>
              </div>

              {/* Description */}
              <p className="text-[11px] text-[var(--color-text-secondary)] line-clamp-2 min-h-[32px] leading-relaxed mb-3">
                {provider.description}
              </p>

              {/* Technical Endpoint & Latency */}
              <div className="p-2 rounded-xl surface-recessed border border-[var(--color-border-subtle)] space-y-1 text-[11px] font-mono">
                <div className="flex items-center justify-between text-[var(--color-text-secondary)]">
                  <span className="text-[var(--color-text-muted)] text-[10px]">Endpoint:</span>
                  <span className="truncate max-w-[150px]">{provider.endpoint}</span>
                </div>
                <div className="flex items-center justify-between text-[var(--color-text-secondary)]">
                  <span className="text-[var(--color-text-muted)] text-[10px]">Latency:</span>
                  <span className="text-[var(--color-accent)] font-medium">
                    {provider.latencyText}
                  </span>
                </div>
              </div>

              {/* Footer: Active Model / Formats */}
              <div className="flex items-center justify-between pt-2.5 mt-2 border-t border-[var(--color-border-subtle)] text-[10px] text-[var(--color-text-muted)]">
                <div className="flex items-center gap-1 truncate max-w-[170px]">
                  <span className="font-semibold text-[var(--color-text-secondary)]">Active:</span>
                  <span className="truncate text-[var(--color-text-primary)] font-mono">
                    {provider.activeModelName || 'None'}
                  </span>
                </div>
                <span className="px-1.5 py-0.5 rounded surface-recessed font-mono">
                  {isLocal ? 'Local Core' : 'Cloud API'}
                </span>
              </div>
            </div>
          );
        })}
      </div>
    </Card>
  );
};
