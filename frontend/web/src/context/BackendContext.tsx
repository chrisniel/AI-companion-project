import React, { createContext, useContext, useState, useEffect, useCallback, useRef, ReactNode } from 'react';
import {
  checkHealth,
  getModelStatus,
  ModelStatusResponse,
  getApiBaseUrl,
  setApiBaseUrl as saveApiBaseUrl,
  getApiKey,
  setApiKey as saveApiKey,
  fetchModelRegistry,
  RegistryEntry,
  setSessionToken, createBrowserClaim, exchangeBrowserClaim, revokeProfileSession,
  ProfileSession, BrowserClaim, ApiError,
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
  const isModelLoading = false;
  const [registry, setRegistry] = useState<RegistryEntry[]>([]);
  const [apiUrlState, setApiUrlState] = useState<string>(getApiBaseUrl());
  const [apiKeyState, setApiKeyState] = useState<string>(getApiKey());
  const [lastError, setLastError] = useState<string | null>(null);
  const [session, setSession] = useState<ProfileSession | null>(null);
  const [claim, setClaim] = useState<BrowserClaim | null>(null);
  const [sessionError, setSessionError] = useState<string | null>(null);
  const [requesting, setRequesting] = useState(false);
  const [sessionEpoch, setSessionEpoch] = useState(0);
  const claimEpoch = useRef(0);

  const clearSession = useCallback(() => {
    claimEpoch.current++;
    setSessionToken('');
    setApiKeyState('');
    setSession(null);
    setClaim(null);
    setModelStatus(null);
    setRegistry([]);
    setSessionEpoch(value => value + 1);
  }, []);

  const requestApproval = useCallback(async () => {
    clearSession();
    const epoch = claimEpoch.current;
    setRequesting(true);
    setSessionError(null);
    try {
      const next = await createBrowserClaim();
      if (claimEpoch.current === epoch) setClaim(next);
    } catch (error) {
      if (claimEpoch.current === epoch) setSessionError(error instanceof Error ? error.message : 'Approval request failed.');
    } finally { setRequesting(false); }
  }, [clearSession]);

  useEffect(() => {
    if (!claim) return;
    let cancelled = false;
    let busy = false;
    const epoch = claimEpoch.current;
    const poll = async () => {
      if (busy || cancelled) return;
      if (Date.now() >= Date.parse(claim.expires_at)) {
        clearSession(); setSessionError('Approval request expired. Request approval again.'); return;
      }
      busy = true;
      try {
        const approved = await exchangeBrowserClaim(claim);
        if (cancelled || epoch !== claimEpoch.current) return;
        setSessionToken(approved.token);
        setApiKeyState(approved.token);
        setSession(approved);
        setClaim(null);
        setSessionEpoch(value => value + 1);
      } catch (error) {
        if (!cancelled && epoch === claimEpoch.current && (!(error instanceof ApiError) || error.status !== 409)) {
          clearSession(); setSessionError(error instanceof Error ? error.message : 'Approval failed.');
        }
      } finally { busy = false; }
    };
    const interval = setInterval(poll, 1000);
    return () => { cancelled = true; clearInterval(interval); };
  }, [claim, clearSession]);

  useEffect(() => {
    if (!session) return;
    const timer = setTimeout(clearSession, Math.max(0, Date.parse(session.expires_at) - Date.now()));
    return () => clearTimeout(timer);
  }, [session, clearSession]);

  useEffect(() => () => { claimEpoch.current++; setSessionToken(''); }, []);
  useEffect(() => {
    window.addEventListener('companion-session-invalid', clearSession);
    return () => window.removeEventListener('companion-session-invalid', clearSession);
  }, [clearSession]);

  const clearError = useCallback(() => setLastError(null), []);

  const setApiUrl = useCallback((url: string) => {
    if (session) void revokeProfileSession().catch(() => {});
    clearSession();
    saveApiBaseUrl(url);
    setApiUrlState(url);
  }, [session, clearSession]);

  const setApiKey = useCallback((key: string) => {
    saveApiKey(key);
  }, []);

  const refreshRegistry = useCallback(async () => {
    try {
      const entries = await fetchModelRegistry(apiKeyState);
      if (Array.isArray(entries)) {
        setRegistry(entries);
      }
    } catch {
      // Preserve last-known registry on failure; do not inject fabricated defaults
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
          setLastError('Request Profile access and approve it in Flutter Desktop.');
        }
      }

      // 3. Model registry probe
      try {
        const entries = await fetchModelRegistry(apiKeyState);
        if (Array.isArray(entries)) {
          setRegistry(entries);
        }
      } catch {
        // Preserve last-known registry on failure; do not inject fabricated defaults
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

  const unavailableAdmin = useCallback(async () => {
    const message = 'Model administration is available in Flutter Desktop.';
    setLastError(message);
    throw new Error(message);
  }, []);
  const loadModel = unavailableAdmin;
  const unloadModel = unavailableAdmin;
  const changeProfile = unavailableAdmin;

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
      <section aria-label="Profile access" className="p-3 text-sm surface-raised">
        {session ? <>
          <span>Profile session: {session.profile_id}</span>{' '}
          <button onClick={() => { const pending = revokeProfileSession(); clearSession(); void pending.catch(() => setSessionError('Local access cleared; host revocation could not be confirmed.')); }}>Sign out</button>
        </> : <>
          <button disabled={requesting || !!claim} onClick={requestApproval}>Request Desktop approval</button>
          {claim && <p>Select a Profile in Flutter Desktop and approve request {claim.request_id} from {claim.origin}. Expires {claim.expires_at}.</p>}
          {claim && <button onClick={clearSession}>Cancel request</button>}
        </>}
        {sessionError && <p role="alert">{sessionError}</p>}
      </section>
      <React.Fragment key={sessionEpoch}>{children}</React.Fragment>
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
