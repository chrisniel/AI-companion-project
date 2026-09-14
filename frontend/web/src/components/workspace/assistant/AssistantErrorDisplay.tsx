import React from 'react';
import { Zap, RefreshCw, AlertCircle } from 'lucide-react';
import { ModelStatusResponse } from '../../../services/api';

export type AssistantErrorCode =
  | 'CORE_OFFLINE'
  | 'MODEL_NOT_LOADED'
  | 'MODEL_SLEEPING'
  | 'WAKE_FAILED'
  | 'STREAM_CONNECTION_FAILED'
  | 'STREAM_TERMINATED'
  | 'MODEL_GENERATION_FAILED'
  | 'USER_CANCELLED';

export interface ClassifiedStreamError {
  code: AssistantErrorCode;
  visibleMessage: string;
}

export function classifyStreamError(
  err: Error | unknown,
  isOnline: boolean,
  modelStatus: ModelStatusResponse | null | undefined
): ClassifiedStreamError {
  const errObj = err instanceof Error ? err : new Error(String(err));
  const errMessage = errObj.message || 'Stream terminated unexpectedly';
  const apiCode = (errObj as { code?: string }).code;

  // 1. User cancellation
  if (
    errObj.name === 'AbortError' ||
    errMessage.toLowerCase().includes('abort') ||
    errMessage.toLowerCase().includes('cancel')
  ) {
    return {
      code: 'USER_CANCELLED',
      visibleMessage: `Generation stopped by user. [USER_CANCELLED]`,
    };
  }

  // 2. Core Offline
  if (!isOnline) {
    return {
      code: 'CORE_OFFLINE',
      visibleMessage: `Local AI Core is offline. Ensure Local AI Core is running on :8000. [CORE_OFFLINE: ${errMessage}]`,
    };
  }

  // 3. Stream Terminated unexpectedly (premature EOF)
  if (apiCode === 'STREAM_TERMINATED' || errMessage.includes('STREAM_TERMINATED')) {
    return {
      code: 'STREAM_TERMINATED',
      visibleMessage: `Stream ended abruptly before explicit completion. [STREAM_TERMINATED: ${errMessage}]`,
    };
  }

  // 4. Model sleeping or wake failure
  const isWakeFailed =
    errMessage.toLowerCase().includes('wake') || (apiCode && apiCode.includes('WAKE'));
  if (isWakeFailed) {
    return {
      code: 'WAKE_FAILED',
      visibleMessage: `Model wake failed. Wake the model manually in Models view. [WAKE_FAILED: ${errMessage}]`,
    };
  }
  if (modelStatus?.runtime_state === 'MODEL_SLEEPING') {
    return {
      code: 'MODEL_SLEEPING',
      visibleMessage: `Model is currently sleeping. Wake the model in Models view or retry to wake. [MODEL_SLEEPING: ${errMessage}]`,
    };
  }

  // 5. Model Not Loaded
  const isUnloaded =
    !modelStatus?.model_loaded ||
    modelStatus?.runtime_state === 'MODEL_UNLOADED' ||
    apiCode === 'LLM_UNAVAILABLE' ||
    errMessage.includes('LLM_UNAVAILABLE');
  if (isUnloaded) {
    return {
      code: 'MODEL_NOT_LOADED',
      visibleMessage: `No active model loaded. Ensure an LLM model is loaded in Models view. [MODEL_NOT_LOADED: ${errMessage}]`,
    };
  }

  // 6. Explicit model generation failure (SSE error event, GPU OOM, context overflow)
  if (
    apiCode === 'MODEL_GENERATION_FAILED' ||
    errMessage.toLowerCase().includes('gpu out of memory') ||
    errMessage.toLowerCase().includes('out of memory') ||
    errMessage.toLowerCase().includes('context') ||
    errMessage.toLowerCase().includes('generation failed')
  ) {
    return {
      code: 'MODEL_GENERATION_FAILED',
      visibleMessage: `Model generation failed: ${errMessage}. [MODEL_GENERATION_FAILED]`,
    };
  }

  // 7. Transport / Stream Connection failure while Core and Model are ready
  const isTransportError =
    errMessage.toLowerCase().includes('failed to fetch') ||
    errMessage.toLowerCase().includes('networkerror') ||
    errMessage.toLowerCase().includes('load failed') ||
    errMessage.toLowerCase().includes('stream failed with status 500') ||
    errMessage.toLowerCase().includes('internal server error');

  if (modelStatus?.model_loaded && isTransportError) {
    return {
      code: 'STREAM_CONNECTION_FAILED',
      visibleMessage: `Connection to the Assistant stream failed. Core and model status remain available. [STREAM_CONNECTION_FAILED: ${errMessage}]`,
    };
  }

  // 8. General / Fallback Model Generation Failure
  return {
    code: 'MODEL_GENERATION_FAILED',
    visibleMessage: `Model generation failed: ${errMessage}. [MODEL_GENERATION_FAILED]`,
  };
}

export interface AssistantErrorDisplayProps {
  isOnline: boolean;
  isModelSleeping?: boolean;
  isModelUnloaded?: boolean;
  isRouterOffline?: boolean;
  isModelLoading?: boolean;
  onLoadModel?: () => void;
  error?: string | null;
  onDismissError?: () => void;
}

export const AssistantErrorDisplay: React.FC<AssistantErrorDisplayProps> = ({
  isOnline,
  isModelSleeping,
  isModelUnloaded,
  isRouterOffline,
  isModelLoading,
  onLoadModel,
  error,
  onDismissError,
}) => {
  return (
    <div className="space-y-2">
      {/* Sleeping Model Notice */}
      {isOnline && isModelSleeping && (
        <div className="p-3 rounded-2xl bg-purple-500/10 border border-purple-500/30 flex items-center justify-between text-xs text-purple-300">
          <div className="flex items-center gap-2">
            <Zap className="w-4 h-4 text-purple-400 flex-shrink-0" />
            <span>Model is sleeping in RAM (VRAM released). Sending a message will wake the model.</span>
          </div>
          <span className="text-[11px] font-mono px-2 py-0.5 rounded bg-purple-500/20 text-purple-300">
            Native Sleep
          </span>
        </div>
      )}

      {/* Unloaded Model Alert Notice */}
      {isOnline && isModelUnloaded && !isRouterOffline && (
        <div className="p-3 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-between text-xs text-amber-400">
          <div className="flex items-center gap-2">
            <Zap className="w-4 h-4 flex-shrink-0" />
            <span>No model is currently loaded. Click Load Model or choose a model from the Models tab.</span>
          </div>
          <button
            type="button"
            disabled={isModelLoading}
            onClick={() => onLoadModel?.()}
            className="px-3 py-1 rounded-xl bg-amber-500/20 hover:bg-amber-500/30 font-semibold flex items-center gap-1.5 transition-all disabled:opacity-50"
          >
            {isModelLoading ? <RefreshCw className="w-3.5 h-3.5 animate-spin" /> : <Zap className="w-3.5 h-3.5" />}
            <span>Load Model</span>
          </button>
        </div>
      )}

      {/* Explicit Error Banner */}
      {error && (
        <div className="p-3 rounded-2xl bg-rose-500/10 border border-rose-500/30 flex items-center justify-between text-xs text-rose-300">
          <div className="flex items-center gap-2">
            <AlertCircle className="w-4 h-4 text-rose-400 flex-shrink-0" />
            <span>{error}</span>
          </div>
          {onDismissError && (
            <button
              type="button"
              onClick={onDismissError}
              className="text-rose-400 hover:text-rose-200 text-sm font-bold ml-2"
              aria-label="Dismiss error"
            >
              ×
            </button>
          )}
        </div>
      )}
    </div>
  );
};
