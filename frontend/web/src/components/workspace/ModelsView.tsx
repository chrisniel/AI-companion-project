import React, { useState, useEffect } from 'react';
import { Cpu, Layers, HardDrive, Zap, RefreshCw, CheckCircle2, AlertCircle, X } from 'lucide-react';
import { Badge } from '../ui/Badge';
import { useBackend } from '../../context/BackendContext';
import {
  mockLocalModels,
  mockModelProviders,
} from '../../mock/localAiData';
import {
  LocalModel,
  ModelProviderType,
  PerformanceProfile,
  ProviderRoutingPolicy,
} from '../../types';
import { ModelProvidersCard } from './models/ModelProvidersCard';
import { CurrentModelHero } from './models/CurrentModelHero';
import { PerformanceProfileSelector } from './models/PerformanceProfileSelector';
import { VramTargetSlider } from './models/VramTargetSlider';
import { ProviderRoutingCard } from './models/ProviderRoutingCard';
import { ModelLibraryGrid } from './models/ModelLibraryGrid';
import { ModelDetailsModal } from './models/ModelDetailsModal';
import { AdvancedRuntimeSettings } from './models/AdvancedRuntimeSettings';

export interface ModelsViewProps {
  currentModelId?: string;
  onSelectModel?: (modelId: string) => void;
  performanceProfile?: PerformanceProfile;
  onChangePerformanceProfile?: (profile: PerformanceProfile) => void;
}

export const ModelsView: React.FC<ModelsViewProps> = ({
  currentModelId: controlledModelId,
  onSelectModel,
  performanceProfile: controlledProfile = 'balanced',
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
  } = useBackend();

  const [keyInput, setKeyInput] = useState(apiKey || '');

  useEffect(() => {
    if (apiKey) {
      setKeyInput(apiKey);
    }
  }, [apiKey]);

  // Local state for models and active selections
  const [models, setModels] = useState<LocalModel[]>(mockLocalModels);
  const [internalModelId, setInternalModelId] = useState<string>('m-1');
  const activeModelId = controlledModelId || internalModelId;

  // Performance Profile state (prefer backend profile if available)
  const backendProfile = modelStatus?.active_profile as PerformanceProfile | undefined;
  const [internalProfile, setInternalProfile] = useState<PerformanceProfile>(backendProfile || controlledProfile);
  const activeProfile = backendProfile || controlledProfile || internalProfile;

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

  // VRAM Target Slider state
  const [vramTargetGb, setVramTargetGb] = useState<number>(2.5);

  // Provider filter for library
  const [providerFilter, setProviderFilter] = useState<ModelProviderType | 'all'>('all');

  // Provider Routing and Cloud Fallback state
  const [routingPolicy, setRoutingPolicy] = useState<ProviderRoutingPolicy>('local_first');
  const [allowCloudFallback, setAllowCloudFallback] = useState<boolean>(true);
  const [askBeforeCloudUse, setAskBeforeCloudUse] = useState<boolean>(false);
  const [useCloudForComplexOnly, setUseCloudForComplexOnly] = useState<boolean>(true);

  // Model Details Modal state
  const [selectedDetailsModel, setSelectedDetailsModel] = useState<LocalModel | null>(null);
  const [isDetailsOpen, setIsDetailsOpen] = useState(false);

  // Find active model object
  const currentModel =
    models.find((m) => m.id === activeModelId) || models[0];

  const isQwenModel = currentModel.id === 'm-1' || currentModel.name.toLowerCase().includes('qwen');
  const isSelectedModelLoaded = Boolean(
    modelStatus?.is_loaded && (
      (isQwenModel && (modelStatus.active_model?.includes('Qwen') || !modelStatus.active_model)) ||
      (modelStatus.active_model && currentModel.name.includes(modelStatus.active_model))
    )
  );

  // Dynamic active model reflecting real backend status without overriding selected model identity
  const liveActiveModel: LocalModel = {
    ...currentModel,
    status: isSelectedModelLoaded ? 'loaded' : 'unloaded',
    engine: currentModel.isCloud
      ? currentModel.engine
      : (modelStatus?.provider === 'llama_cpp' ? 'llama.cpp (Vulkan)' : currentModel.engine),
    contextWindow: isSelectedModelLoaded && modelStatus?.context_size ? modelStatus.context_size : currentModel.contextWindow,
    layersOffloaded: isSelectedModelLoaded && modelStatus?.gpu_layers !== undefined ? modelStatus.gpu_layers : (isSelectedModelLoaded ? 28 : 0),
    vramUsageGb: isSelectedModelLoaded ? 4.5 : 0.0,
  };

  // Actions
  const handleActivateModel = async (modelId: string) => {
    const selected = models.find((m) => m.id === modelId) || currentModel;
    setInternalModelId(modelId);
    onSelectModel?.(modelId);

    // Only attempt local VRAM loading if model is local and on disk
    if (!selected.isCloud) {
      const isTargetOnDisk = selected.id === 'm-1' || Boolean(
        modelStatus?.available_models?.some((avail) =>
          avail.toLowerCase().includes(selected.name.toLowerCase()) ||
          selected.name.toLowerCase().includes(avail.toLowerCase())
        )
      );

      if (isTargetOnDisk) {
        try {
          await loadModel(
            selected.id === 'm-1' ? (modelStatus?.available_models?.[0] || 'Qwen2.5-7B-Instruct-Q4_K_M.gguf') : selected.name,
            (activeProfile === 'turbo' ? 'maximum' : activeProfile) as 'eco' | 'balanced' | 'maximum'
          );
        } catch {
          // Handled in context error state
        }
      }
    }
  };

  const handleUnloadModel = async () => {
    try {
      await unloadModel();
      setModels((prev) =>
        prev.map((m) => {
          if (m.id === activeModelId) {
            return { ...m, status: 'unloaded' };
          }
          return m;
        })
      );
    } catch {
      // Handled in context error state
    }
  };

  const handleOpenDetails = (model: LocalModel) => {
    setSelectedDetailsModel(model);
    setIsDetailsOpen(true);
  };

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
            <span className={`w-2 h-2 rounded-full ${isOnline ? 'bg-emerald-500 animate-pulse' : 'bg-rose-500'}`} />
            <span>Local AI Core:</span>
            <span className="font-semibold text-[var(--color-text-primary)]">
              {isOnline ? (modelStatus?.is_loaded ? 'VRAM Active' : 'Online (Standby)') : 'Offline (:8000)'}
            </span>
          </div>
        </div>
      </div>

      {/* 2. Current Model Hero (Rich Telemetry with Load/Unload Admin Actions) */}
      <CurrentModelHero
        model={liveActiveModel}
        isModelLoading={isModelLoading}
        onLoad={() => handleActivateModel(activeModelId)}
        onUnload={handleUnloadModel}
        onOpenDetails={handleOpenDetails}
        idleCountdownSeconds={modelStatus?.seconds_until_unload}
      />

      {/* 3. Performance Profiles & VRAM Target (Tactile Grid) */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Performance Profiles (Eco, Balanced, Maximum) */}
        <PerformanceProfileSelector
          currentProfile={activeProfile}
          onSelectProfile={handleProfileChange}
        />

        {/* AI VRAM Target Slider (e.g. 2.5 GB / 8 GB UI-only) */}
        <VramTargetSlider
          vramTargetGb={vramTargetGb}
          totalVramGb={8.0}
          currentModelVramGb={currentModel.isCloud ? 0.0 : currentModel.vramUsageGb || 4.9}
          onChangeVramTarget={setVramTargetGb}
        />
      </div>

      {/* 4. Replaceable Model Providers (llama.cpp, Ollama, Gemini) */}
      <ModelProvidersCard
        providers={mockModelProviders}
        activeProviderFilter={providerFilter}
        onSelectProviderFilter={setProviderFilter}
      />

      {/* 5. Provider Routing Policy & Cloud Fallback Controls */}
      <ProviderRoutingCard
        routingPolicy={routingPolicy}
        onChangeRoutingPolicy={setRoutingPolicy}
        allowCloudFallback={allowCloudFallback}
        onToggleAllowCloudFallback={setAllowCloudFallback}
        askBeforeCloudUse={askBeforeCloudUse}
        onToggleAskBeforeCloudUse={setAskBeforeCloudUse}
        useCloudForComplexOnly={useCloudForComplexOnly}
        onToggleUseCloudForComplexOnly={setUseCloudForComplexOnly}
      />

      {/* 6. Model Library Grid (Activate, Unload, Details) */}
      <ModelLibraryGrid
        models={models}
        currentModelId={activeModelId}
        providerFilter={providerFilter}
        onActivateModel={handleActivateModel}
        onUnloadModel={handleUnloadModel}
        onOpenDetails={handleOpenDetails}
      />

      {/* 7. Advanced Technical Settings (Collapsed Accordion) */}
      <AdvancedRuntimeSettings />

      {/* 8. Model Details Modal */}
      <ModelDetailsModal
        model={selectedDetailsModel}
        isOpen={isDetailsOpen}
        onClose={() => setIsDetailsOpen(false)}
        isActive={selectedDetailsModel?.id === activeModelId}
        onActivate={handleActivateModel}
      />
    </div>
  );
};
