import React, { useState } from 'react';
import {
  Cpu,
  Layers,
  HardDrive,
  Zap,
  Play,
  Check,
  Power,
  Info,
  Search,
  Filter,
  Cloud,
  CheckCircle2,
} from 'lucide-react';
import { Badge } from '../../ui/Badge';
import { Card } from '../../ui/Card';
import { LocalModel, ModelProviderType } from '../../../types';

interface ModelLibraryGridProps {
  models: LocalModel[];
  selectedModelId?: string | null;
  activeModelId?: string | null;
  currentModelId?: string | null; // Backwards-compatible prop
  modelStatus?: import('../../../services/api').ModelStatusResponse | null;
  providerFilter: ModelProviderType | 'all';
  onSelectModel?: (modelId: string) => void;
  onActivateModel: (modelId: string) => void;
  onUnloadModel: (modelId: string) => void;
  onOpenDetails: (model: LocalModel) => void;
}

export const ModelLibraryGrid: React.FC<ModelLibraryGridProps> = ({
  models,
  selectedModelId: explicitSelectedModelId,
  activeModelId,
  currentModelId,
  modelStatus,
  providerFilter,
  onSelectModel,
  onActivateModel,
  onUnloadModel,
  onOpenDetails,
}) => {
  const selectedId = explicitSelectedModelId ?? currentModelId ?? null;
  const [searchQuery, setSearchQuery] = useState('');

  // Filter models based on search query and provider filter
  const filteredModels = models.filter((m) => {
    const matchesProvider =
      providerFilter === 'all' ? true : m.engine === providerFilter;
    const matchesSearch =
      m.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      m.family.toLowerCase().includes(searchQuery.toLowerCase()) ||
      m.quantization.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesProvider && matchesSearch;
  });

  return (
    <Card id="model-library-card" className="space-y-4">
      {/* 1. Header with Search and Stats */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-2 border-b border-[var(--color-border-subtle)]">
        <div>
          <div className="flex items-center gap-2">
            <h2 className="text-sm sm:text-base font-semibold text-[var(--color-text-primary)]">
              Model Library
            </h2>
            <Badge variant="default" size="sm">
              {filteredModels.length} {filteredModels.length === 1 ? 'Model' : 'Models'} Available
            </Badge>
          </div>
          <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
            Locally stored GGUF quantized weights and hot-swappable cloud provider endpoints.
          </p>
        </div>

        {/* Search input */}
        <div className="relative w-full sm:w-64">
          <Search className="w-3.5 h-3.5 absolute left-3 top-1/2 -translate-y-1/2 text-[var(--color-text-muted)]" />
          <input
            type="text"
            id="model-library-search-input"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search models, family, quants..."
            className="w-full pl-8 pr-3 py-1.5 text-xs rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-[var(--color-text-primary)] placeholder-[var(--color-text-muted)] focus:outline-none focus:border-[var(--color-accent)] transition-all font-mono"
          />
        </div>
      </div>

      {/* 2. Models Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {filteredModels.map((model) => {
          const isSelected = selectedId === model.id;
          const isLoaded = Boolean(activeModelId && activeModelId === model.id);
          const isSleeping = isLoaded && modelStatus?.runtime_state === 'MODEL_SLEEPING';
          const isCloud = model.isCloud || model.engine === 'gemini';

          return (
            <div
              key={model.id}
              id={`model-card-${model.id}`}
              onClick={() => onSelectModel?.(model.id)}
              className={`p-4 rounded-2xl border transition-all duration-150 flex flex-col justify-between relative group cursor-pointer ${
                isSelected && isLoaded
                  ? 'surface-raised border-2 border-[var(--color-accent)] ring-2 ring-[var(--color-accent)]/20 shadow-md'
                  : isSelected
                  ? 'surface-raised border-2 border-[var(--color-accent)] ring-2 ring-[var(--color-accent)]/20 shadow-md'
                  : isLoaded
                  ? 'surface-raised border-2 border-emerald-500/50 shadow-sm'
                  : 'surface-base border border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 hover:shadow-sm'
              }`}
            >
              <div>
                {/* Header: Title & Badges */}
                <div className="flex items-start justify-between gap-2 mb-2">
                  <div>
                    <div className="flex items-center gap-1.5 flex-wrap">
                      <h3 className="text-sm font-bold text-[var(--color-text-primary)] group-hover:text-[var(--color-accent)] transition-colors">
                        {model.name}
                      </h3>
                      {/* Variant badge */}
                      {model.variant === 'thinking' && (
                        <span className="text-[10px] px-1.5 py-0.5 rounded-full bg-purple-500/20 text-purple-300 font-medium">
                          Thinking 🧠
                        </span>
                      )}
                      {model.variant === 'instruct' && (
                        <span className="text-[10px] px-1.5 py-0.5 rounded-full bg-sky-500/20 text-sky-300 font-medium">
                          Instruct
                        </span>
                      )}
                      {model.variant === 'base' && (
                        <span className="text-[10px] px-1.5 py-0.5 rounded-full bg-zinc-500/20 text-zinc-300 font-medium">
                          Base
                        </span>
                      )}
                      {model.variant && model.variant !== 'thinking' && model.variant !== 'instruct' && model.variant !== 'base' && (
                        <span className="text-[10px] px-1.5 py-0.5 rounded-full bg-zinc-500/20 text-zinc-300 font-medium">
                          {model.variant.charAt(0).toUpperCase() + model.variant.slice(1)}
                        </span>
                      )}
                      {/* Companion / Vision degradation warning (Text remains loadable) */}
                      {(model.capabilities?.includes('vision') || model.hasCompanion) && (
                        !model.companionFilesValid ? (
                          <span
                            className="text-[10px] px-1.5 py-0.5 rounded-full bg-amber-500/20 text-amber-400 font-medium font-mono"
                            title="Vision companion missing: Text inference remains available, but vision features are unavailable."
                          >
                            ⚠ Vision companion missing (Degraded)
                          </span>
                        ) : (
                          <span
                            className="text-[10px] px-1.5 py-0.5 rounded-full bg-emerald-500/20 text-emerald-400 font-medium font-mono"
                            title="Vision projector validated"
                          >
                            Vision
                          </span>
                        )
                      )}
                    </div>
                    <span className="text-[11px] text-[var(--color-text-muted)] font-mono block mt-0.5">
                      {model.family} • {model.parameters}
                    </span>
                  </div>

                  <div className="flex flex-col items-end gap-1 flex-shrink-0">
                    {isLoaded ? (
                      <Badge variant={isSleeping ? 'accent' : 'success'} size="sm">
                        <span className={`w-1.5 h-1.5 rounded-full mr-1 ${isSleeping ? 'bg-purple-500' : 'bg-emerald-500 animate-pulse'}`} />
                        {isSleeping ? 'Loaded (Sleeping)' : 'Loaded'}
                      </Badge>
                    ) : (
                      <Badge variant="default" size="sm">
                        {isCloud ? 'Cloud API' : 'On Disk'}
                      </Badge>
                    )}
                    {isSelected && (
                      <Badge variant="accent" size="sm">
                        <span className="flex items-center gap-1 font-semibold">
                          <CheckCircle2 className="w-3 h-3" /> Selected
                        </span>
                      </Badge>
                    )}
                  </div>
                </div>

                {/* Technical Specifications Grid */}
                <div className="grid grid-cols-2 gap-2 p-2.5 my-2.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] text-[11px] font-mono text-[var(--color-text-secondary)]">
                  <div className="flex items-center justify-between">
                    <span className="text-[var(--color-text-muted)]">Quant:</span>
                    <span className="font-semibold text-[var(--color-text-primary)]">
                      {model.quantization}
                    </span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-[var(--color-text-muted)]">Size:</span>
                    <span>{isCloud ? 'Cloud' : (model.sizeGb != null && model.sizeGb > 0 ? `${model.sizeGb.toFixed(2)} GB` : 'Unavailable')}</span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-[var(--color-text-muted)]">Runtime:</span>
                    <span className="truncate max-w-[70px] text-sky-400 font-medium">
                      {model.engine}
                    </span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-[var(--color-text-muted)]">Context:</span>
                    <span>{model.contextWindow != null && model.contextWindow > 0 ? (model.contextWindow >= 1000000 ? '1M' : `${Math.round(model.contextWindow / 1024)}k`) : 'Unknown'}</span>
                  </div>
                </div>

                <p className="text-[11px] text-[var(--color-text-muted)] line-clamp-2 min-h-[30px] leading-relaxed">
                  {model.description}
                </p>
              </div>

              {/* Action Buttons: Activate, Unload, Details */}
              <div
                className="flex items-center justify-between gap-1.5 pt-3 mt-3 border-t border-[var(--color-border-subtle)]"
                onClick={(e) => e.stopPropagation()}
              >
                {/* Details Button */}
                <button
                  type="button"
                  id={`model-details-btn-${model.id}`}
                  onClick={() => onOpenDetails(model)}
                  className="px-2.5 py-1.5 rounded-xl surface-base border border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/50 text-[11px] font-medium text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] flex items-center gap-1 transition-all"
                  title="View tensor architecture and offload specifications"
                >
                  <Info className="w-3 h-3 text-[var(--color-accent)]" />
                  <span>Details</span>
                </button>

                <div className="flex items-center gap-1.5">
                  {/* Unload Button (if loaded and not cloud) */}
                  {!isCloud && isLoaded && (
                    <button
                      type="button"
                      id={`model-unload-btn-${model.id}`}
                      onClick={() => onUnloadModel(model.id)}
                      className="px-2.5 py-1.5 rounded-xl surface-recessed border border-rose-500/40 text-[11px] font-semibold text-rose-500 hover:bg-rose-500/10 flex items-center gap-1 transition-all"
                      title="Unload from VRAM"
                    >
                      <Power className="w-3 h-3" />
                      <span>Unload</span>
                    </button>
                  )}

                  {/* Activate / Load / Selected Button */}
                  {isLoaded ? (
                    <div className="px-3 py-1.5 rounded-xl surface-raised border border-emerald-500/40 text-[11px] font-bold text-emerald-500 flex items-center gap-1 shadow-sm font-mono">
                      <Check className="w-3 h-3" />
                      <span>Loaded</span>
                    </div>
                  ) : (
                    <button
                      type="button"
                      id={`model-activate-btn-${model.id}`}
                      onClick={() => onActivateModel(model.id)}
                      className="px-3 py-1.5 rounded-xl bg-accent-gradient text-white hover:opacity-90 text-[11px] font-semibold flex items-center gap-1 transition-all shadow-sm"
                    >
                      <Play className="w-3 h-3 fill-current" />
                      <span>{isSelected ? 'Load' : 'Activate'}</span>
                    </button>
                  )}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </Card>
  );
};
