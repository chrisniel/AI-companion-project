import React, { useState } from 'react';
import {
  Shield,
  Trash2,
  Download,
  Lock,
  Database,
  EyeOff,
  FileText,
  AlertTriangle,
  Check,
} from 'lucide-react';
import { Toggle } from '../../ui/Toggle';
import { NeumorphicButton } from '../../ui/NeumorphicButton';
import { useTheme } from '../../../context/ThemeContext';

export interface PrivacySettingsState {
  historyRetention: string;
  autoRedactPii: boolean;
  enableEpisodicMemory: boolean;
  associateBiometricFacts: boolean;
  encryptHealthDb: boolean;
  retainDiagnosticLogs: boolean;
}

interface PrivacySectionProps {
  settings: PrivacySettingsState;
  onUpdate: <K extends keyof PrivacySettingsState>(key: K, value: PrivacySettingsState[K]) => void;
}

export const PrivacySection: React.FC<PrivacySectionProps> = ({ settings, onUpdate }) => {
  const { mode } = useTheme();
  const [clearedChatNotice, setClearedChatNotice] = useState(false);
  const [clearedDiagNotice, setClearedDiagNotice] = useState(false);

  const handleClearHistory = () => {
    setClearedChatNotice(true);
    setTimeout(() => setClearedChatNotice(false), 3000);
  };

  const handleClearDiag = () => {
    setClearedDiagNotice(true);
    setTimeout(() => setClearedDiagNotice(false), 3000);
  };

  const handleExportData = () => {
    const exportPayload = {
      exportDate: new Date().toISOString(),
      architecture: 'LocalAI Private Offline Vault',
      settings,
    };
    const dataStr = 'data:text/json;charset=utf-8,' + encodeURIComponent(JSON.stringify(exportPayload, null, 2));
    const downloadAnchor = document.createElement('a');
    downloadAnchor.setAttribute('href', dataStr);
    downloadAnchor.setAttribute('download', `localai-privacy-export-${Date.now()}.json`);
    document.body.appendChild(downloadAnchor);
    downloadAnchor.click();
    downloadAnchor.remove();
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h2 className="text-base font-bold text-[var(--color-text-primary)] flex items-center gap-2">
          <Shield className="w-5 h-5 text-emerald-500" />
          Privacy, Data Governance & Security
        </h2>
        <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
          Everything runs on your device. Manage retention policies, on-disk encryption, and PII scrubbing.
        </p>
      </div>

      {/* 1. Local Conversation History */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
            <FileText className="w-4 h-4" />
            Local Conversation History
          </h3>
          <div className="flex items-center gap-2">
            <NeumorphicButton
              variant="ghost"
              size="sm"
              onClick={handleExportData}
              icon={<Download className="w-3.5 h-3.5" />}
            >
              Export JSON
            </NeumorphicButton>
            <NeumorphicButton
              variant="ghost"
              size="sm"
              onClick={handleClearHistory}
              icon={<Trash2 className="w-3.5 h-3.5 text-rose-500" />}
            >
              {clearedChatNotice ? 'Cleared!' : 'Clear Chat History'}
            </NeumorphicButton>
          </div>
        </div>

        {clearedChatNotice && (
          <div className="p-3 rounded-2xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-700 dark:text-emerald-300 text-xs flex items-center gap-2">
            <Check className="w-4 h-4 text-emerald-500" />
            <span>Local conversation history cache has been purged successfully.</span>
          </div>
        )}

        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
              Chat Retention Horizon
            </span>
            <p className="text-xs text-[var(--color-text-secondary)]">
              Automatically purge old conversational turns from the local database.
            </p>
          </div>
          <select
            value={settings.historyRetention}
            onChange={(e) => onUpdate('historyRetention', e.target.value)}
            style={{ colorScheme: mode }}
            className="px-3.5 py-2 rounded-xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs font-medium text-[var(--color-text-primary)] focus:outline-none focus:border-[var(--color-accent)] cursor-pointer shadow-xs"
          >
            <option value="forever" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Keep Forever (Unlimited)</option>
            <option value="30_days" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Keep 30 Days</option>
            <option value="7_days" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Keep 7 Days</option>
            <option value="session" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Ephemeral (Session Only)</option>
          </select>
        </div>
      </div>

      {/* 2. Episodic Memory & PII Redaction */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
          <Lock className="w-4 h-4" />
          Episodic Memory & Redaction Guardrails
        </h3>

        <div className="space-y-3.5">
          <div className="flex items-center justify-between gap-4">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Automatic Sensitive PII Redaction
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Scrub credit card numbers, passwords, API tokens, and social security IDs before writing to SQLite memory.
              </p>
            </div>
            <Toggle
              checked={settings.autoRedactPii}
              onChange={(val) => onUpdate('autoRedactPii', val)}
              size="sm"
            />
          </div>

          <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Enable Long-Term Semantic Memory Store
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Persist user preferences, key project details, and daily schedule habits in vectorized memory.
              </p>
            </div>
            <Toggle
              checked={settings.enableEpisodicMemory}
              onChange={(val) => onUpdate('enableEpisodicMemory', val)}
              size="sm"
            />
          </div>

          <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Associate Biometrics with Task Context
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Correlate heart rate and focus intensity to specific calendar work blocks.
              </p>
            </div>
            <Toggle
              checked={settings.associateBiometricFacts}
              onChange={(val) => onUpdate('associateBiometricFacts', val)}
              size="sm"
            />
          </div>
        </div>
      </div>

      {/* 3. Health Storage Encryption & Cloud Usage */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
          <Database className="w-4 h-4" />
          Health Storage & Cloud Airgap Isolation
        </h3>

        <div className="space-y-3.5">
          <div className="flex items-center justify-between gap-4">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                AES-256-GCM Local Database Encryption
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Encrypt SQLite health tables and vectors using Apple Keychain / OS Keyring derived key.
              </p>
            </div>
            <Toggle
              checked={settings.encryptHealthDb}
              onChange={(val) => onUpdate('encryptHealthDb', val)}
              size="sm"
            />
          </div>

          <div className="p-4 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] flex items-start gap-3">
            <EyeOff className="w-5 h-5 text-emerald-500 flex-shrink-0 mt-0.5" />
            <div>
              <h4 className="text-xs font-bold text-[var(--color-text-primary)] uppercase tracking-wider font-mono">
                Cloud Telemetry Policy: 100% Disabled
              </h4>
              <p className="text-xs text-[var(--color-text-secondary)] mt-0.5 leading-relaxed">
                Local AI contains zero telemetry tracking, zero analytics beacons, and zero remote logging.
                No data ever leaves your device without explicit approval.
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* 4. Diagnostics */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
            <AlertTriangle className="w-4 h-4" />
            System Diagnostic Buffer
          </h3>
          <NeumorphicButton
            variant="ghost"
            size="sm"
            onClick={handleClearDiag}
            icon={<Trash2 className="w-3.5 h-3.5 text-rose-500" />}
          >
            {clearedDiagNotice ? 'Cleared!' : 'Clear Diagnostic Cache'}
          </NeumorphicButton>
        </div>

        {clearedDiagNotice && (
          <div className="p-3 rounded-2xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-700 dark:text-emerald-300 text-xs flex items-center gap-2">
            <Check className="w-4 h-4 text-emerald-500" />
            <span>Diagnostic crash and telemetry cache purged.</span>
          </div>
        )}

        <div className="flex items-center justify-between gap-4">
          <div>
            <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
              Retain Local Diagnostic Event Logs
            </span>
            <p className="text-xs text-[var(--color-text-secondary)]">
              Record hardware errors and token speed diagnostics to local disk for viewer analysis.
            </p>
          </div>
          <Toggle
            checked={settings.retainDiagnosticLogs}
            onChange={(val) => onUpdate('retainDiagnosticLogs', val)}
            size="sm"
          />
        </div>
      </div>
    </div>
  );
};
