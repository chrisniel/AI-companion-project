/**
 * Model Registry API — fetches the live model list from the backend.
 * Master Plan §16.2, §16.3 — Schema v3 ModelRegistry Contract
 */
import { apiFetch, getApiKey } from './client';

export type ModelAssetType = 'gguf' | 'mmproj' | 'lora' | 'embedding' | 'tokenizer';

export type ModelVariant = 'instruct' | 'thinking' | 'base' | 'code' | 'unknown';

export type InputModality = 'text' | 'image' | 'audio' | 'video';

export type ModelDiscoveryState = 'discovered' | 'registered' | 'verified' | 'incompatible';

export type ReasoningMode = 'always_on' | 'toggleable' | 'unsupported' | 'unknown';

export type CapabilityProvenance = 'declared' | 'detected' | 'verified' | 'unknown';

export type ValidationStatus =
  | 'verified'
  | 'missing_primary'
  | 'missing_companion'
  | 'unregistered'
  | 'incompatible';

export type ModelCapability =
  | 'chat'
  | 'vision'
  | 'reasoning'
  | 'structured_output'
  | 'tool_calling'
  | 'multilingual';

export type RegistrySource = 'factory' | 'installed';

export interface CompanionFile {
  role: string;
  path: string;
  sha256?: string | null;
}

export interface CapabilityEntry {
  capability: ModelCapability;
  supported?: boolean;
  provenance?: CapabilityProvenance;
}

export interface CompanionArtifactStatus {
  artifact: CompanionFile;
  exists: boolean;
}

export interface GenerationDefaults {
  temperature?: number | null;
  top_p?: number | null;
  top_k?: number | null;
  min_p?: number | null;
  repeat_penalty?: number | null;
}

export interface ModelManifest {
  id: string;
  display_name: string;
  asset_type?: ModelAssetType;
  family?: string;
  architecture?: string;
  variant?: ModelVariant;
  parameters?: string;
  quantization?: string;
  reasoning_mode?: ReasoningMode;
  capabilities?: ModelCapability[];
  input_modalities?: InputModality[];
  model_max_context?: number | null;
  runtime_compatibility?: string[];
  primary_file: string;
  companion_files?: CompanionFile[];
  chat_template?: string | null;
  license?: string;
  source?: string;
  sha256_primary?: string | null;
}

export interface ModelLibraryState {
  discovery_state?: ModelDiscoveryState;
  validation_status?: ValidationStatus;
  primary_file_exists?: boolean;
  size_gb?: number | null;
  companion_artifact_statuses?: CompanionArtifactStatus[];
  available_capabilities?: ModelCapability[];
  capability_provenance?: CapabilityEntry[];
}

export interface ModelRuntimeHints {
  recommended_profiles?: string[];
  estimated_vram_gb?: number;
  estimated_ram_gb?: number;
  generation_defaults?: GenerationDefaults | null;
}

export interface RegistryEntry {
  manifest: ModelManifest;
  library_state: ModelLibraryState;
  hints: ModelRuntimeHints;
  runtime_model_id: string;
  registry_source: RegistrySource;
}

export function getRegistryEntryId(entry: RegistryEntry): string {
  return entry.manifest.id;
}

export function getRegistryEntryDisplayName(entry: RegistryEntry): string {
  return entry.manifest.display_name || entry.manifest.id;
}

export function registryEntryMatchesIdentifier(
  entry: RegistryEntry,
  identifier: string | null | undefined
): boolean {
  if (!identifier) return false;
  if (entry.manifest.id === identifier) return true;
  if (entry.runtime_model_id && entry.runtime_model_id === identifier) return true;
  if (entry.manifest.primary_file === identifier) return true;
  const primaryBasename = entry.manifest.primary_file.split(/[/\\]/).pop();
  if (primaryBasename && primaryBasename === identifier) return true;
  return false;
}

export async function fetchModelRegistry(apiKey?: string | null): Promise<RegistryEntry[]> {
  const options: RequestInit = {};
  if (apiKey) {
    options.headers = { Authorization: `Bearer ${apiKey}` };
  }
  return await apiFetch<RegistryEntry[]>('/api/v1/models/registry', options);
}
