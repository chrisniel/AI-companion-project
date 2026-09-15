import React, { useState, useEffect, useMemo } from 'react';
import { Cpu, RefreshCw, CheckCircle2, AlertCircle, X } from 'lucide-react';
import { Badge } from '../ui/Badge';
import { useBackend } from '../../context/BackendContext';
import {
  LocalModel,
  PerformanceProfile,
} from '../../types';
import { RegistryEntry } from '../../services/api';
import { CurrentModelHero } from './models/CurrentModelHero';
import { PerformanceProfileSelector } from './models/PerformanceProfileSelector';
import { VramTargetSlider } from './models/VramTargetSlider';
import { ModelLibraryGrid } from './models/ModelLibraryGrid';
import { ModelDetailsModal } from './models/ModelDetailsModal';

export interface ModelsViewProps {
  selectedModelId?: string | null;
  onSelectModel?: (modelId: string) => void;
  currentModelId?: string; // Backwards-compatible alias
  performanceProfile?: PerformanceProfile;
  onChangePerformanceProfile?: (profile: PerformanceProfile) => void;
}

export const ModelsView: React.FC<ModelsViewProps> = ({
  selectedModelId: controlledSelectedId,
  currentModelId: legacyControlledId,
  onSelectModel,
  performanceProfile: controlledProfile,
  onChangePerformanceProfile,
}) => {
  const {
    isOnline,
    modelStatus,
    isModelLoading,
    loadModel,
    unloadModel,
    changeProfile,
    lastError,
    clearError,
    apiKey,
    setApiKey,
    refreshStatus,
    registry,
  } = useBackend();

  const [keyInput, setKeyInput] = useState(apiKey || '');

  useEffect(() => {
    if (apiKey) {
      setKeyInput(apiKey);
    }
  }, [apiKey]);

  // Authoritative Backend Active Model:
  // Derived directly from backend truth (model_loaded = True and active_model populated).
  const backendActiveModelId = (modelStatus?.model_loaded && modelStatus?.active_model)
    ? modelStatus.active_model
    : null;

  // Selected Model (model the user is currently viewing/intends to act on)
  const initialControlled = controlledSelectedId ?? legacyControlledId ?? null;
  const [internalSelectedId, setInternalSelectedId] = useState<string | null>(initialControlled);
  const [hasHydratedSelection, setHasHydratedSelection] = useState(Boolean(initialControlled));

  // On initial startup only: if no explicit selection exists, hydrate selectedModelId from activeModelId
  useEffect(() => {
    if (!hasHydratedSelection) {
      if (initialControlled) {
        setInternalSelectedId(initialControlled);
        setHasHydratedSelection(true);
      } else if (backendActiveModelId) {
        setInternalSelectedId(backendActiveModelId);
        setHasHydratedSelection(true);
      }
    }
  }, [initialControlled, backendActiveModelId, hasHydratedSelection]);

  const selectedModelId = controlledSelectedId ?? legacyControlledId ?? internalSelectedId;

  // Performance Profile state (requested profile)
  const backendRequestedProfile = modelStatus?.requested_profile as PerformanceProfile | undefined;
  const [internalProfile, setInternalProfile] = useState<PerformanceProfile>(
    backendRequestedProfile || controlledProfile || 'balanced'
  );
  const activeProfile = backendRequestedProfile || controlledProfile || internalProfile;

  const handleProfileChange = async (newProfile: PerformanceProfile) => {
    setInternalProfile(newProfile);
    onChangePerformanceProfile?.(newProfile);

    if (newProfile === 'eco' || newProfile === 'balanced' || newProfile === 'maximum') {
      try {
        await changeProfile(newProfile);
      } catch {
        // Handled in context
      }
    }

    // Contextually adjust VRAM target based on selected profile
    if (newProfile === 'eco') {
      setVramTargetGb(2.5);
    } else if (newProfile === 'balanced') {
      setVramTargetGb(4.0);
    } else if (newProfile === 'maximum' || newProfile === 'turbo') {
      setVramTargetGb(8.0);
    }
  };

  // VRAM Target Slider state (informational headroom guide)
  const [vramTargetGb, setVramTargetGb] = useState<number>(2.5);

  // Model Details Modal state
  const [selectedDetailsModel, setSelectedDetailsModel] = useState<LocalModel | null>(null);
  const [isDetailsOpen, setIsDetailsOpen] = useState(false);

  // Derive live model list directly from backend registry
  const liveModels = useMemo<LocalModel[]>(() => {
    if (!registry || registry.length === 0) {
      return [];
    }
    return registry.map((e: RegistryEntry) => {
      const isThisLoaded = Boolean(
        backendActiveModelId &&
        (
          e.id === backendActiveModelId ||
          (e.primary_file && e.primary_file === backendActiveModelId)
        )
      );
      return {
        id: e.id,
        name: e.display_name,
        family: e.family,
        parameters: e.parameters,
        quantization: e.quantization,
        sizeGb: e.size_gb ?? null,
        contextWindow: e.context_limit,
        status: isThisLoaded ? ('loaded' as const) : ('unloaded' as const),
        engine: 'llama.cpp',
        isCloud: false,
        vramUsageGb: e.estimated_vram_gb,
        ramUsageGb: e.estimated_ram_gb,
        filePath: e.primary_file,
        description: `${e.variant} · ${e.capabilities.join(', ')} · ${e.license}`,
        license: e.license,
        tensorType: 'GGUF',
        variant: e.variant,
        capabilities: e.capabilities,
        validationStatus: e.validation_status,
        hasCompanion: e.companion_files.length > 0,
        companionFilesValid: e.companion_files_valid,
      };
    });
  }, [registry, backendActiveModelId]);

  // Find currently selected model object (the one user is viewing in Hero)
  const currentSelectedModel =
    liveModels.find((m) => m.id === selectedModelId) ||
    (backendActiveModelId ? liveModels.find((m) => m.id === backendActiveModelId) : null) ||
    liveModels[0] ||
    null;

  const isSelectedLoaded = Boolean(
    backendActiveModelId &&
    currentSelectedModel &&
    currentSelectedModel.id === backendActiveModelId
  );

  // Dynamic active model reflecting real backend status
  const liveActiveModel: LocalModel | null = currentSelectedModel
    ? {
        ...currentSelectedModel,
        status: isSelectedLoaded ? 'loaded' : 'unloaded',
        engine: currentSelectedModel.engine,
        contextWindow: isSelectedLoaded && modelStatus?.applied_context_size
          ? modelStatus.applied_context_size
          : currentSelectedModel.contextWindow,
        layersOffloaded: isSelectedLoaded && modelStatus?.applied_gpu_layers !== undefined && modelStatus.applied_gpu_layers !== null
          ? modelStatus.applied_gpu_layers
          : undefined,
        vramUsageGb: isSelectedLoaded ? currentSelectedModel.vramUsageGb : undefined,
      }
    : null;

  // Actions
  const handleSelectModel = (modelId: string) => {
    setInternalSelectedId(modelId);
    setHasHydratedSelection(true);
    onSelectModel?.(modelId);
  };

  const handleActivateModel = async (modelId: string) => {
    handleSelectModel(modelId);
    const selected = liveModels.find((m) => m.id === modelId) || currentSelectedModel;
    if (!selected) return;

    // Local VRAM loading
    if (!selected.isCloud) {
      try {
        await loadModel(
          selected.id || selected.filePath || selected.name,
          (activeProfile === 'turbo' ? 'maximum' : activeProfile) as 'eco' | 'balanced' | 'maximum'
        );
      } catch {
        // Handled in context error state
      }
    }
  };

  const handleUnloadModel = async () => {
    try {
      await unloadModel();
    } catch {
      // Handled in context error state
    }
  };

  const handleOpenDetails = (model: LocalModel) => {
    setSelectedDetailsModel(model);
    setIsDetailsOpen(true);
  };

  const getRuntimeStateHeader = (state?: string, online?: boolean): { label: string; dotClass: string } => {
    if (!online) return { label: 'Offline (:8000)', dotClass: 'bg-rose-500' };
    switch (state) {
      case 'SERVER_STOPPED':
        return { label: 'Router Offline', dotClass: 'bg-zinc-500' };
      case 'SERVER_STARTING':
        return { label: 'Router Starting…', dotClass: 'bg-amber-500 animate-pulse' };
      case 'MODEL_UNLOADED':
        return { label: 'Router Ready / No Model Loaded', dotClass: 'bg-sky-500' };
      case 'MODEL_LOADING':
        return { label: 'Loading…', dotClass: 'bg-amber-500 animate-pulse' };
      case 'MODEL_READY':
        return { label: 'Loaded / Awake', dotClass: 'bg-emerald-500 animate-pulse' };
      case 'MODEL_SLEEPING':
        return { label: 'Loaded / Sleeping 💤', dotClass: 'bg-purple-500' };
      case 'MODEL_UNLOADING':
        return { label: 'Unloading…', dotClass: 'bg-amber-500 animate-pulse' };
      case 'MODEL_ERROR':
        return { label: 'Model Error ⚠️', dotClass: 'bg-rose-500' };
      case 'SERVER_ERROR':
        return { label: 'Router Error ⚠️', dotClass: 'bg-rose-500' };
      default:
        return { label: 'Router Ready', dotClass: 'bg-sky-500' };
    }
  };

  const headerRuntime = getRuntimeStateHeader(modelStatus?.runtime_state, isOnline);

  return (
    <div id="models-and-runtime-view" className="space-y-6 max-w-7xl mx-auto pb-12">
      {/* Error Banner / Pairing Input */}
      {lastError && (
        <div className="p-4 rounded-2xl bg-rose-500/10 border border-rose-500/30 text-rose-500 text-xs space-y-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <AlertCircle className="w-4 h-4 flex-shrink-0" />
              <span className="font-semibold">{lastError}</span>
            </div>
            <button type="button" onClick={clearError} className="p-1 hover:bg-rose-500/20 rounded-lg">
              <X className="w-3.5 h-3.5" />
            </button>
          </div>
          {(lastError.toLowerCase().includes('auth') || lastError.toLowerCase().includes('credential')) && (
            <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-2 pt-2 border-t border-rose-500/20">
              <div className="relative flex-1">
                <input
                  type="password"
                  value={keyInput}
                  onChange={(e) => setKeyInput(e.target.value)}
                  placeholder="Paste COMPANION_API_KEY here..."
                  className="w-full px-3 py-1.5 rounded-xl bg-[var(--color-surface-elevated)] border border-rose-500/40 text-xs text-[var(--color-text-primary)] font-mono focus:outline-none focus:border-[var(--color-accent)] transition-all shadow-xs"
                />
              </div>
              <button
                type="button"
                onClick={async () => {
                  setApiKey(keyInput.trim());
                  clearError();
                  await refreshStatus();
                }}
                className="px-3.5 py-1.5 rounded-xl bg-rose-500 hover:bg-rose-600 text-white text-xs font-semibold tracking-wide transition-all shadow-xs flex-shrink-0"
              >
                Save & Connect
              </button>
            </div>
          )}
        </div>
      )}

      {/* 1. View Header */}
      <div className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="flex items-start sm:items-center gap-3.5">
          <div className="w-11 h-11 rounded-2xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm flex-shrink-0 shadow-md">
            <Cpu className="w-5 h-5" />
          </div>
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <h1 className="text-lg sm:text-xl font-bold text-[var(--color-text-primary)]">
                Local AI Models & Runtime
              </h1>
              <Badge variant="accent" size="sm">
                Multi-Runtime Core
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] mt-0.5 max-w-2xl">
              Manage hot-swappable local GGUF models, inference engines, VRAM target budgets, and provider routing.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 self-start md:self-center">
          <div className="px-3 py-1.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] flex items-center gap-2 text-xs font-mono text-[var(--color-text-secondary)]">
            <span className={`w-2 h-2 rounded-full ${headerRuntime.dotClass}`} />
            <span>Local AI Runtime:</span>
            <span className="font-semibold text-[var(--color-text-primary)]">
              {headerRuntime.label}
            </span>
          </div>
        </div>
      </div>

      {/* 2. Current Model Hero (Rich Telemetry with Load/Unload Admin Actions) */}
      {currentSelectedModel && liveActiveModel ? (
        <>
          <CurrentModelHero
            model={liveActiveModel}
            isModelLoading={isModelLoading}
            onLoad={() => handleActivateModel(currentSelectedModel.id)}
            onUnload={handleUnloadModel}
            onOpenDetails={handleOpenDetails}
            idleCountdownSeconds={modelStatus?.seconds_until_idle}
            runtimeState={modelStatus?.runtime_state}
            modelStatus={modelStatus}
            activeModelId={backendActiveModelId}
          />

          {/* 3. Performance Profiles & VRAM Target (Tactile Grid) */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Performance Profiles (Eco, Balanced, Maximum) */}
            <PerformanceProfileSelector
              requestedProfile={modelStatus?.requested_profile || activeProfile}
              appliedProfile={modelStatus?.applied_profile ?? null}
              appliedContextSize={modelStatus?.applied_context_size ?? null}
              appliedGpuLayers={modelStatus?.applied_gpu_layers ?? null}
              requestedMmprojOffload={modelStatus?.requested_mmproj_offload ?? null}
              appliedMmprojOffload={modelStatus?.applied_mmproj_offload ?? null}
              onSelectProfile={handleProfileChange}
            />

            {/* AI VRAM Target Slider (Informational Headroom Guide) */}
            <VramTargetSlider
              vramTargetGb={vramTargetGb}
              totalVramGb={8.0}
              estimatedModelVramGb={currentSelectedModel.isCloud ? null : (currentSelectedModel.vramUsageGb ?? null)}
              onChangeVramTarget={setVramTargetGb}
            />
          </div>
        </>
      ) : (
        <div
          id="no-models-available-card"
          className="p-8 text-center surface-raised border border-[var(--color-border-subtle)] rounded-3xl space-y-3"
        >
          <Cpu className="w-8 h-8 text-[var(--color-text-muted)] mx-auto animate-pulse" />
          <h3 className="text-base font-semibold text-[var(--color-text-primary)]">
            No Models Discovered
          </h3>
          <p className="text-xs text-[var(--color-text-secondary)] max-w-md mx-auto">
            {isOnline
              ? 'Model registry is empty or no installed models were detected in the runtime library.'
              : 'Local AI Runtime is offline. Waiting for model registry connection…'}
          </p>
        </div>
      )}

      {/* 4. Model Library Grid (Activate, Unload, Details) */}
      <ModelLibraryGrid
        models={liveModels}
        selectedModelId={selectedModelId}
        activeModelId={backendActiveModelId}
        modelStatus={modelStatus}
        providerFilter="all"
        onSelectModel={handleSelectModel}
        onActivateModel={handleActivateModel}
        onUnloadModel={handleUnloadModel}
        onOpenDetails={handleOpenDetails}
      />

      {/* 5. Model Details Modal */}
      <ModelDetailsModal
        model={selectedDetailsModel}
        isOpen={isDetailsOpen}
        onClose={() => setIsDetailsOpen(false)}
        isActive={selectedDetailsModel?.id === backendActiveModelId}
        onActivate={handleActivateModel}
      />
    </div>
  );
};
