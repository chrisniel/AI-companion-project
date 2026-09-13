/**
 * Model runtime and VRAM lifecycle management API services.
 */

import { apiFetch } from './client';

export type LLMRuntimeState =
  | 'SERVER_STOPPED'
  | 'SERVER_STARTING'
  | 'MODEL_UNLOADED'
  | 'MODEL_LOADING'
  | 'MODEL_READY'
  | 'MODEL_SLEEPING'
  | 'MODEL_UNLOADING'
  | 'MODEL_ERROR'
  | 'SERVER_ERROR';

export interface ModelStatusResponse {
  provider: string;
  engine_version?: string | null;

  // Router process state
  router_running: boolean;
  managed_by_core: boolean;
  runtime_state: LLMRuntimeState;

  // Model status & residency
  active_model: string | null;
  model_resident: boolean; // Physical VRAM compute residency (True ONLY when MODEL_READY)
  model_loaded: boolean;   // Logical residency: worker exists, model registered (READY or SLEEPING)
  model_awake: boolean;    // GPU/RAM compute readiness (True for READY, False for SLEEPING)

  // Hardware profile & configurations: requested vs verified applied
  requested_profile: string;
  applied_profile: string | null;
  applied_context_size: number | null;
  applied_gpu_layers: number | null;
  requested_mmproj_offload: boolean;
  applied_mmproj_offload: boolean | null;

  // Activity & diagnostics
  generation_active: boolean;
  last_runtime_error: string | null;

  // Backward-compatibility fields (preserved for existing clients until Phase 4 reconciliation)
  mmproj_offload: boolean;
  is_loaded: boolean;
  active_profile: string;
  context_size: number;
  gpu_layers: number;
  idle_timeout_seconds: number;
  seconds_until_idle: number | null;
  seconds_until_unload: number | null;
  available_models: string[];
  available_registry?: string[] | null;
}

export async function getModelStatus(): Promise<ModelStatusResponse> {
  return apiFetch<ModelStatusResponse>('/api/v1/models');
}

export async function loadModel(
  modelName?: string,
  profile?: 'eco' | 'balanced' | 'maximum'
): Promise<ModelStatusResponse> {
  return apiFetch<ModelStatusResponse>('/api/v1/models/load', {
    method: 'POST',
    body: JSON.stringify({
      model_name: modelName || null,
      profile: profile || null,
    }),
  });
}

export async function unloadModel(): Promise<ModelStatusResponse> {
  return apiFetch<ModelStatusResponse>('/api/v1/models/unload', {
    method: 'POST',
  });
}

export async function updateModelProfile(
  profile: 'eco' | 'balanced' | 'maximum'
): Promise<ModelStatusResponse> {
  return apiFetch<ModelStatusResponse>('/api/v1/models/profile', {
    method: 'PATCH',
    body: JSON.stringify({ profile }),
  });
}
