import React, { createContext, useContext, useState, useEffect, useCallback, ReactNode } from 'react';
import {
  checkHealth,
  getModelStatus,
  loadModel as apiLoadModel,
  unloadModel as apiUnloadModel,
  updateModelProfile as apiUpdateModelProfile,
  ModelStatusResponse,
  getApiBaseUrl,
  setApiBaseUrl as saveApiBaseUrl,
  getApiKey,
  setApiKey as saveApiKey,
  fetchModelRegistry,
  RegistryEntry,
  DEFAULT_INSTALLED_REGISTRY,
} from '../services/api';

export interface BackendContextType {
  isOnline: boolean;
  modelStatus: ModelStatusResponse | null;
  isModelLoading: boolean;
  registry: RegistryEntry[];
  apiUrl: string;
  setApiUrl: (url: string) => void;
  apiKey: string;
  setApiKey: (key: string) => void;
  lastError: string | null;
  clearError: () => void;
  loadModel: (modelName?: string, profile?: 'eco' | 'balanced' | 'maximum') => Promise<void>;
  unloadModel: () => Promise<void>;
  changeProfile: (profile: 'eco' | 'balanced' | 'maximum') => Promise<void>;
  refreshStatus: () => Promise<void>;
  refreshRegistry: () => Promise<void>;
}

const BackendContext = createContext<BackendContextType | undefined>(undefined);

export const BackendProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [isOnline, setIsOnline] = useState<boolean>(false);
  const [modelStatus, setModelStatus] = useState<ModelStatusResponse | null>(null);
  const [isModelLoading, setIsModelLoading] = useState<boolean>(false);
  const [registry, setRegistry] = useState<RegistryEntry[]>(DEFAULT_INSTALLED_REGISTRY);
  const [apiUrlState, setApiUrlState] = useState<string>(getApiBaseUrl());
  const [apiKeyState, setApiKeyState] = useState<string>(getApiKey());
  const [lastError, setLastError] = useState<string | null>(null);

  const clearError = useCallback(() => setLastError(null), []);

  const setApiUrl = useCallback((url: string) => {
    saveApiBaseUrl(url);
    setApiUrlState(url);
  }, []);

  const setApiKey = useCallback((key: string) => {
    saveApiKey(key);
    setApiKeyState(key);
  }, []);

  const refreshRegistry = useCallback(async () => {
    try {
      const entries = await fetchModelRegistry(apiKeyState);
      if (entries && entries.length > 0) {
        setRegistry(entries);
      }
    } catch {
      // Keep baseline installed registry
    }
  }, [apiKeyState]);

  const refreshStatus = useCallback(async () => {
    try {
      // 1. Health probe
      await checkHealth();
      setIsOnline(true);

      // 2. Model telemetry probe
      try {
        const status = await getModelStatus();
        setModelStatus(status);
        setLastError(null);
      } catch (modelErr: unknown) {
        // Model endpoint might require auth if key not set
        if (modelErr instanceof Error && modelErr.message.includes('401')) {
          setLastError('Authentication required. Configure pairing key in Settings.');
        }
      }

      // 3. Model registry probe
      try {
        const entries = await fetchModelRegistry(apiKeyState);
        if (entries && entries.length > 0) {
          setRegistry(entries);
        }
      } catch {
        // Keep baseline installed registry
      }
    } catch {
      setIsOnline(false);
      setModelStatus(null);
    }
  }, [apiKeyState]);

  // Periodic heartbeat polling (every 5 seconds)
  useEffect(() => {
    refreshStatus();
    const interval = setInterval(refreshStatus, 5000);
    return () => clearInterval(interval);
  }, [refreshStatus]);

  const loadModel = useCallback(
    async (modelName?: string, profile?: 'eco' | 'balanced' | 'maximum') => {
      setIsModelLoading(true);
      setLastError(null);
      try {
        const status = await apiLoadModel(modelName, profile);
        setModelStatus(status);
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : 'Failed to load model into VRAM.';
        setLastError(msg);
        throw err;
      } finally {
        setIsModelLoading(false);
      }
    },
    []
  );

  const unloadModel = useCallback(async () => {
    setIsModelLoading(true);
    setLastError(null);
    try {
      const status = await apiUnloadModel();
      setModelStatus(status);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to unload model from VRAM.';
      setLastError(msg);
      throw err;
    } finally {
      setIsModelLoading(false);
    }
  }, []);

  const changeProfile = useCallback(
    async (profile: 'eco' | 'balanced' | 'maximum') => {
      setLastError(null);
      try {
        const status = await apiUpdateModelProfile(profile);
        setModelStatus(status);
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : 'Failed to change hardware profile.';
        setLastError(msg);
        throw err;
      }
    },
    []
  );

  return (
    <BackendContext.Provider
      value={{
        isOnline,
        modelStatus,
        isModelLoading,
        registry,
        apiUrl: apiUrlState,
        setApiUrl,
        apiKey: apiKeyState,
        setApiKey,
        lastError,
        clearError,
        loadModel,
        unloadModel,
        changeProfile,
        refreshStatus,
        refreshRegistry,
      }}
    >
      {children}
    </BackendContext.Provider>
  );
};

export const useBackend = (): BackendContextType => {
  const context = useContext(BackendContext);
  if (!context) {
    throw new Error('useBackend must be used within a BackendProvider');
  }
  return context;
};
