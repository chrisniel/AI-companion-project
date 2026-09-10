import React, { useState } from 'react';
import { Volume2, Mic, Radio, Sliders, Play, Check, VolumeX, Globe, ShieldCheck, Cpu } from 'lucide-react';
import { Toggle } from '../../ui/Toggle';
import { Slider } from '../../ui/Slider';
import { NeumorphicButton } from '../../ui/NeumorphicButton';
import { ProgressBar } from '../../ui/ProgressBar';
import { useTheme } from '../../../context/ThemeContext';
import { SpeechRecognitionLanguageMode } from '../../../types';
import { voiceLanguageCapabilities } from '../../../mock/multilingualData';

export interface VoiceSettingsState {
  ttsProvider: string;
  ttsVoice: string;
  speechRate: number; // 0.8 to 1.5
  speechPitch: number; // 0.8 to 1.2
  sttProvider: string;
  streamingTranscription: boolean;
  listeningMode: 'vad' | 'push_to_talk' | 'wake_word';
  wakeWordPhrase: string;
  vadSensitivity: number; // 0 to 100
  echoCancellation: boolean;
  noiseSuppression: boolean;
  audioDucking: boolean;
  speechRecognitionMode?: SpeechRecognitionLanguageMode;
  speechRecognitionLanguage?: string;
  mixedLanguageRecognition?: boolean;
}

interface VoiceSectionProps {
  settings: VoiceSettingsState;
  onUpdate: <K extends keyof VoiceSettingsState>(key: K, value: VoiceSettingsState[K]) => void;
}

export const VoiceSection: React.FC<VoiceSectionProps> = ({ settings, onUpdate }) => {
  const { mode } = useTheme();
  const [isPlayingTestAudio, setIsPlayingTestAudio] = useState(false);

  const handleTestAudio = () => {
    setIsPlayingTestAudio(true);
    setTimeout(() => {
      setIsPlayingTestAudio(false);
    }, 2800);
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h2 className="text-base font-bold text-[var(--color-text-primary)] flex items-center gap-2">
          <Volume2 className="w-5 h-5 text-[var(--color-accent)]" />
          Voice, Speech Synthesis & Acoustic Engine
        </h2>
        <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
          Configure zero-latency neural speech generation, local Whisper transcription, and acoustic filters.
        </p>
      </div>

      {/* 1. TTS Provider (Text-to-Speech) */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
            <Volume2 className="w-4 h-4" />
            Neural TTS Synthesis Engine
          </h3>
          <NeumorphicButton
            variant="primary"
            size="sm"
            onClick={handleTestAudio}
            icon={isPlayingTestAudio ? <span className="w-2 h-2 rounded-full bg-white animate-ping" /> : <Play className="w-3.5 h-3.5" />}
          >
            {isPlayingTestAudio ? 'Synthesizing...' : 'Preview Voice'}
          </NeumorphicButton>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-[var(--color-text-primary)]">
              TTS Provider Architecture
            </label>
            <select
              value={settings.ttsProvider}
              onChange={(e) => onUpdate('ttsProvider', e.target.value)}
              style={{ colorScheme: mode }}
              className="w-full px-3.5 py-2.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] font-medium focus:outline-none focus:border-[var(--color-accent)] transition-all cursor-pointer shadow-xs"
            >
              <option value="kokoro-82m" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Kokoro-82M (Local Neural, 84ms RTF 0.02)</option>
              <option value="piper-tts" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Piper TTS (Ultra-lightweight ONNX)</option>
              <option value="whisper-tts" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Whisper.cpp Local TTS</option>
              <option value="web-speech" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Web Speech API (Browser Fallback)</option>
            </select>
          </div>

          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-[var(--color-text-primary)]">
              Selected Neural Voice Model
            </label>
            <select
              value={settings.ttsVoice}
              onChange={(e) => onUpdate('ttsVoice', e.target.value)}
              style={{ colorScheme: mode }}
              className="w-full px-3.5 py-2.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] font-medium focus:outline-none focus:border-[var(--color-accent)] transition-all cursor-pointer shadow-xs"
            >
              <option value="af_sarah" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>af_sarah (Warm, expressive female - 24kHz)</option>
              <option value="am_adam" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>am_adam (Confident, articulate male - 24kHz)</option>
              <option value="af_bella" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>af_bella (Crisp, conversational female)</option>
              <option value="am_michael" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>am_michael (Deep, resonant executive male)</option>
            </select>
          </div>
        </div>

        {/* Speed & Pitch sliders */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-2">
          <div className="space-y-1">
            <div className="flex justify-between text-xs">
              <span className="font-medium text-[var(--color-text-secondary)]">Speech Rate</span>
              <span className="font-mono text-[var(--color-accent)] font-bold">{settings.speechRate.toFixed(2)}x</span>
            </div>
            <Slider
              value={settings.speechRate}
              onChange={(val) => onUpdate('speechRate', val)}
              min={0.8}
              max={1.5}
              step={0.05}
            />
          </div>

          <div className="space-y-1">
            <div className="flex justify-between text-xs">
              <span className="font-medium text-[var(--color-text-secondary)]">Vocal Pitch</span>
              <span className="font-mono text-[var(--color-accent)] font-bold">{settings.speechPitch.toFixed(2)}x</span>
            </div>
            <Slider
              value={settings.speechPitch}
              onChange={(val) => onUpdate('speechPitch', val)}
              min={0.8}
              max={1.2}
              step={0.05}
            />
          </div>
        </div>
      </div>

      {/* 2. STT Provider (Speech-to-Text) */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
          <Mic className="w-4 h-4" />
          Speech-to-Text (STT) Transcription Pipeline
        </h3>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-[var(--color-text-primary)]">
              Transcription Model & Accelerator
            </label>
            <select
              value={settings.sttProvider}
              onChange={(e) => onUpdate('sttProvider', e.target.value)}
              style={{ colorScheme: mode }}
              className="w-full px-3.5 py-2.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] font-medium focus:outline-none focus:border-[var(--color-accent)] transition-all cursor-pointer shadow-xs"
            >
              <option value="whisper-small-metal" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Whisper.cpp Small (Metal GPU Accel - 140ms)</option>
              <option value="whisper-tiny" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Whisper.cpp Tiny (Fastest - 45ms latency)</option>
              <option value="silero-stt" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Silero STT Stream Engine</option>
            </select>
          </div>

          <div className="flex items-center justify-between p-3.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] self-end">
            <div>
              <span className="text-xs font-semibold text-[var(--color-text-primary)] block">
                Streaming Real-time Tokens
              </span>
              <p className="text-[11px] text-[var(--color-text-secondary)]">
                Emit transcribed words dynamically before utterance ends.
              </p>
            </div>
            <Toggle
              checked={settings.streamingTranscription}
              onChange={(val) => onUpdate('streamingTranscription', val)}
              size="sm"
            />
          </div>
        </div>

        {/* BATCH 12.1: Speech Recognition Language & Multilingual Acoustic Config */}
        <div className="pt-4 border-t border-[var(--color-border-subtle)] space-y-4">
          <div className="flex items-center justify-between">
            <h4 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
              <Globe className="w-4 h-4" />
              Speech Recognition Language (STT)
            </h4>
            <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[var(--color-accent)]/10 text-[var(--color-accent)] font-semibold">
              Multilingual VAD
            </span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-[var(--color-text-primary)]">
                Acoustic Language Detection Mode
              </label>
              <select
                value={settings.speechRecognitionMode || 'auto_detect'}
                onChange={(e) => onUpdate('speechRecognitionMode', e.target.value as any)}
                style={{ colorScheme: mode }}
                className="w-full px-3.5 py-2.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] font-medium focus:outline-none focus:border-[var(--color-accent)] transition-all cursor-pointer shadow-xs"
              >
                <option value="auto_detect" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Automatic Language Identification (Whisper LID)</option>
                <option value="manual_primary" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Fixed Primary Language Only</option>
                <option value="multilingual_simultaneous" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Simultaneous Multilingual Acoustic Beam (EN+FIL+JA)</option>
              </select>
            </div>

            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-[var(--color-text-primary)]">
                Speech Input Target Dialect
              </label>
              <select
                value={settings.speechRecognitionLanguage || 'auto'}
                onChange={(e) => onUpdate('speechRecognitionLanguage', e.target.value)}
                style={{ colorScheme: mode }}
                className="w-full px-3.5 py-2.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] font-medium focus:outline-none focus:border-[var(--color-accent)] transition-all cursor-pointer shadow-xs"
              >
                <option value="auto" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Auto-Detect (Eng, Tagalog, Nihongo)</option>
                <option value="en" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>English (US / Global Accents)</option>
                <option value="fil" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Filipino / Tagalog (tl-PH)</option>
                <option value="ja" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Japanese (ja-JP 日本語)</option>
                <option value="mixed" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Mixed Code-Switching (Taglish / Eng-Jap)</option>
              </select>
            </div>
          </div>

          <div className="flex items-center justify-between p-3.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)]">
            <div>
              <span className="text-xs font-semibold text-[var(--color-text-primary)] block">
                Mixed-Language Speech Recognition (Intra-sentence Code-Switching)
              </span>
              <p className="text-[11px] text-[var(--color-text-secondary)]">
                Enables cross-lingual phoneme beam search so you can fluidly speak Taglish or English+Japanese in one breath without transcription errors.
              </p>
            </div>
            <Toggle
              checked={settings.mixedLanguageRecognition ?? true}
              onChange={(val) => onUpdate('mixedLanguageRecognition', val)}
              size="sm"
            />
          </div>
        </div>

        {/* Voice Language Capabilities Metadata Display */}
        <div className="pt-4 border-t border-[var(--color-border-subtle)] space-y-3">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-[var(--color-text-primary)] flex items-center gap-1.5">
              <Cpu className="w-3.5 h-3.5 text-[var(--color-accent)]" />
              Engine Language Capabilities & Acoustic Fidelity
            </span>
            <span className="text-[10px] text-[var(--color-text-muted)] font-mono">
              Zero Cloud Dependencies
            </span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            {voiceLanguageCapabilities.map((cap) => (
              <div
                key={cap.code}
                className="p-3 rounded-2xl surface-base border border-[var(--color-border-subtle)] space-y-2 hover:border-[var(--color-accent)]/30 transition-all"
              >
                <div className="flex items-start justify-between">
                  <div>
                    <h5 className="text-xs font-bold text-[var(--color-text-primary)] flex items-center gap-1.5">
                      <span>{cap.code === 'en' ? '🇺🇸' : cap.code === 'fil' ? '🇵🇭' : cap.code === 'ja' ? '🇯🇵' : '🌐'}</span>
                      <span>{cap.name}</span>
                    </h5>
                    <span className="text-[10px] text-[var(--color-text-muted)] font-mono block">
                      {cap.nativeName}
                    </span>
                  </div>
                  <span className="text-[10px] font-mono px-1.5 py-0.5 rounded surface-recessed text-[var(--color-accent)] font-semibold border border-[var(--color-border-subtle)]">
                    {cap.codeSwitchSupported ? 'Code-Switch Ready' : 'Single Lexicon'}
                  </span>
                </div>

                <div className="space-y-1 text-[10px]">
                  <div className="flex justify-between font-mono">
                    <span className="text-[var(--color-text-secondary)]">STT Accuracy</span>
                    <span className="text-[var(--color-accent)] font-bold">{cap.sttFidelity}%</span>
                  </div>
                  <ProgressBar value={cap.sttFidelity} size="xs" variant="accent" />

                  <div className="flex justify-between font-mono pt-1">
                    <span className="text-[var(--color-text-secondary)]">TTS Naturalness</span>
                    <span className="text-emerald-500 font-bold">{cap.ttsFidelity}%</span>
                  </div>
                  <ProgressBar value={cap.ttsFidelity} size="xs" variant="success" />
                </div>

                <p className="text-[10px] text-[var(--color-text-secondary)] leading-relaxed pt-1 border-t border-[var(--color-border-subtle)]/50">
                  {cap.notes}
                </p>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* 3. Listening Mode */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
          <Radio className="w-4 h-4" />
          Microphone Listening Mode
        </h3>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          {[
            {
              id: 'vad',
              title: 'Continuous VAD',
              desc: 'Silero Voice Activity Detection automatically starts transcription when speaking.',
            },
            {
              id: 'push_to_talk',
              title: 'Push-to-Talk',
              desc: 'Microphone engages only while holding Spacebar or clicking the microphone icon.',
            },
            {
              id: 'wake_word',
              title: 'Local Wake Word',
              desc: '5ms offline DSP detector triggers on "Hey Iris" with zero microphone streaming to RAM.',
            },
          ].map((modeOpt) => {
            const isSelected = settings.listeningMode === modeOpt.id;
            return (
              <button
                key={modeOpt.id}
                type="button"
                onClick={() => onUpdate('listeningMode', modeOpt.id as any)}
                className={`p-4 rounded-2xl border text-left transition-all ${
                  isSelected
                    ? 'border-[var(--color-accent)] bg-[var(--color-surface-elevated)] ring-2 ring-[var(--color-accent)]/20 shadow-sm'
                    : 'border-[var(--color-border-subtle)] bg-[var(--color-surface-elevated)]/40 hover:bg-[var(--color-surface-elevated)]'
                }`}
              >
                <div className="flex items-center justify-between">
                  <h4 className="text-xs font-bold text-[var(--color-text-primary)]">
                    {modeOpt.title}
                  </h4>
                  {isSelected && <Check className="w-3.5 h-3.5 text-[var(--color-accent)]" />}
                </div>
                <p className="text-xs text-[var(--color-text-secondary)] mt-1 leading-relaxed">
                  {modeOpt.desc}
                </p>
              </button>
            );
          })}
        </div>
      </div>

      {/* 4. Audio Behavior & DSP Filters */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
          <Sliders className="w-4 h-4" />
          Acoustic DSP & Behavior
        </h3>

        <div className="space-y-3.5">
          <div className="flex items-center justify-between gap-4">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Acoustic Echo Cancellation (AEC)
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Prevents speaker playback loops from contaminating microphone input.
              </p>
            </div>
            <Toggle
              checked={settings.echoCancellation}
              onChange={(val) => onUpdate('echoCancellation', val)}
              size="sm"
            />
          </div>

          <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Real-Time Neural Noise Suppression (RNNoise)
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Filters mechanical keyboard clicks, air conditioners, and ambient fan noise.
              </p>
            </div>
            <Toggle
              checked={settings.noiseSuppression}
              onChange={(val) => onUpdate('noiseSuppression', val)}
              size="sm"
            />
          </div>

          <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Smart Background Audio Ducking
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Automatically lower Spotify, music, or video volume by 12dB while Iris is speaking.
              </p>
            </div>
            <Toggle
              checked={settings.audioDucking}
              onChange={(val) => onUpdate('audioDucking', val)}
              size="sm"
            />
          </div>
        </div>
      </div>
    </div>
  );
};
