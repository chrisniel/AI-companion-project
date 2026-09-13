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
  is_loaded: boolean;
  active_model: string | null;
  active_profile: 'eco' | 'balanced' | 'maximum';
  available_models: string[];
  context_size: number;
  gpu_layers: number;
  idle_timeout_seconds: number;
  seconds_until_unload: number | null;
  seconds_until_idle?: number | null;
  runtime_state?: LLMRuntimeState;
  generation_active?: boolean;
  managed_by_core?: boolean;
  engine_version?: string | null;
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
