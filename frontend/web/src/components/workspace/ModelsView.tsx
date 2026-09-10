import React, { useState } from 'react';
import { Cpu, Layers, HardDrive, Zap, RefreshCw, CheckCircle2 } from 'lucide-react';
import { Badge } from '../ui/Badge';
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
  // Local state for models and active selections
  const [models, setModels] = useState<LocalModel[]>(mockLocalModels);
  const [internalModelId, setInternalModelId] = useState<string>('m-1');
  const activeModelId = controlledModelId || internalModelId;

  // Performance Profile state
  const [internalProfile, setInternalProfile] = useState<PerformanceProfile>(controlledProfile);
  const activeProfile = controlledProfile || internalProfile;

  const handleProfileChange = (newProfile: PerformanceProfile) => {
    setInternalProfile(newProfile);
    onChangePerformanceProfile?.(newProfile);

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

  // Actions
  const handleActivateModel = (modelId: string) => {
    setModels((prev) =>
      prev.map((m) => {
        if (m.id === modelId) {
          return { ...m, status: 'loaded' };
        }
        return m;
      })
    );
    setInternalModelId(modelId);
    onSelectModel?.(modelId);
  };

  const handleUnloadModel = (modelId: string) => {
    setModels((prev) =>
      prev.map((m) => {
        if (m.id === modelId) {
          return { ...m, status: 'unloaded' };
        }
        return m;
      })
    );
  };

  const handleOpenDetails = (model: LocalModel) => {
    setSelectedDetailsModel(model);
    setIsDetailsOpen(true);
  };

  return (
    <div id="models-and-runtime-view" className="space-y-6 max-w-7xl mx-auto pb-12">
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
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
            <span>Local Engine:</span>
            <span className="font-semibold text-[var(--color-text-primary)]">
              {currentModel.engine}
            </span>
          </div>
        </div>
      </div>

      {/* 2. Current Model Hero (Rich Telemetry without Terminal Clutter) */}
      <CurrentModelHero
        model={currentModel}
        onUnload={handleUnloadModel}
        onOpenDetails={handleOpenDetails}
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
