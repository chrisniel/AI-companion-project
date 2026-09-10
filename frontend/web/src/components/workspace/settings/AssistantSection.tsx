import React, { useState } from 'react';
import { Bot, Sparkles, User, ShieldCheck, HeartHandshake, Globe, Check, BookOpen, Layers } from 'lucide-react';
import { Toggle } from '../../ui/Toggle';
import { Slider } from '../../ui/Slider';
import { useTheme } from '../../../context/ThemeContext';
import {
  LanguagePreferences,
  SupportedLanguageCode,
  JapaneseDisplayFormat,
  TechnicalResponseLanguageMode,
  ResponseLanguageMode,
} from '../../../types';
import {
  defaultLanguagePreferences,
  SUPPORTED_LANGUAGES,
  mockMultilingualDialogues,
} from '../../../mock/multilingualData';
import { JapaneseTextRenderer } from '../../ui/JapaneseTextRenderer';

export interface AssistantSettingsState {
  defaultCharacterId: string;
  proactiveSuggestions: boolean;
  concisenessLevel: number; // 0: Terse, 50: Balanced, 100: Detailed
  empathyLevel: number; // 0: Neutral, 50: Moderate, 100: Warm
  strictFactualGrounding: boolean;
  autoExtractMemories: boolean;
  customSystemPromptAddendum: string;
  languagePreferences?: LanguagePreferences;
}

interface AssistantSectionProps {
  settings: AssistantSettingsState;
  onUpdate: <K extends keyof AssistantSettingsState>(key: K, value: AssistantSettingsState[K]) => void;
}

const CHARACTERS = [
  {
    id: 'p-1',
    name: 'Iris',
    title: 'Primary Companion',
    avatar: '🌸',
    description: 'Warm, intuitive, and contextual. Balances productivity tracking with thoughtful wellness nudges.',
    tag: 'Recommended Default',
  },
  {
    id: 'p-2',
    name: 'Marcus',
    title: 'Strategic Advisor',
    avatar: '🏛️',
    description: 'Crisp, structured, and high-impact. Excels at calendar triage, decision matrices, and task execution.',
    tag: 'Executive Focus',
  },
  {
    id: 'p-3',
    name: 'Echo',
    title: 'Minimalist Assistant',
    avatar: '⚡',
    description: 'Terse, hyper-compact, zero-chitchat assistant. Direct answers with zero conversational overhead.',
    tag: 'Deep Work',
  },
  {
    id: 'p-4',
    name: 'Nova',
    title: 'Creative Synthesizer',
    avatar: '✨',
    description: 'Lateral thinker for brainstorming, architectural ideation, copy refinement, and creative exploration.',
    tag: 'Ideation',
  },
];

export const AssistantSection: React.FC<AssistantSectionProps> = ({ settings, onUpdate }) => {
  const { mode } = useTheme();
  const langPrefs = settings.languagePreferences || defaultLanguagePreferences;
  const [activePreviewSample, setActivePreviewSample] = useState<string>('dlg-taglish');

  const updateLangPref = <K extends keyof LanguagePreferences>(key: K, value: LanguagePreferences[K]) => {
    onUpdate('languagePreferences', {
      ...langPrefs,
      [key]: value,
    });
  };

  const toggleUnderstoodLang = (langCode: 'en' | 'fil' | 'ja') => {
    const current = langPrefs.understoodLanguages;
    if (current.includes(langCode)) {
      if (current.length === 1) return; // Prevent empty
      updateLangPref('understoodLanguages', current.filter((l) => l !== langCode));
    } else {
      updateLangPref('understoodLanguages', [...current, langCode]);
    }
  };

  const currentSample = mockMultilingualDialogues.find((d) => d.id === activePreviewSample) || mockMultilingualDialogues[0];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h2 className="text-base font-bold text-[var(--color-text-primary)] flex items-center gap-2">
          <Bot className="w-5 h-5 text-[var(--color-accent)]" />
          Assistant Persona & Behavior Engine
        </h2>
        <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
          Select your primary conversational persona and tune tone, proactivity, and grounding parameters.
        </p>
      </div>

      {/* 1. Default Character Selection */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
          <User className="w-4 h-4" />
          Default Character Persona
        </h3>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
          {CHARACTERS.map((char) => {
            const isSelected = settings.defaultCharacterId === char.id;
            return (
              <button
                key={char.id}
                type="button"
                onClick={() => onUpdate('defaultCharacterId', char.id)}
                className={`p-4 rounded-2xl border text-left transition-all relative flex items-start gap-3.5 ${
                  isSelected
                    ? 'border-[var(--color-accent)] bg-[var(--color-surface-elevated)] ring-2 ring-[var(--color-accent)]/20 shadow-sm'
                    : 'border-[var(--color-border-subtle)] bg-[var(--color-surface-elevated)]/40 hover:bg-[var(--color-surface-elevated)] hover:border-[var(--color-accent)]/30'
                }`}
              >
                <div className="w-11 h-11 rounded-2xl bg-[var(--color-surface-secondary)] border border-[var(--color-border-subtle)] flex items-center justify-center text-2xl flex-shrink-0">
                  {char.avatar}
                </div>

                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between">
                    <h4 className="text-sm font-bold text-[var(--color-text-primary)]">
                      {char.name}
                    </h4>
                    <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[var(--color-accent)]/10 text-[var(--color-accent)] font-semibold">
                      {char.tag}
                    </span>
                  </div>
                  <span className="text-xs text-[var(--color-text-secondary)] font-medium block">
                    {char.title}
                  </span>
                  <p className="text-xs text-[var(--color-text-secondary)] mt-1 line-clamp-2">
                    {char.description}
                  </p>
                </div>
              </button>
            );
          })}
        </div>
      </div>

      {/* 2. Behavior Preferences */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
          <Sparkles className="w-4 h-4" />
          Behavioral & Conversational Preferences
        </h3>

        <div className="space-y-4">
          <div className="flex items-center justify-between gap-4">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Proactive Daily Suggestions
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Allow the assistant to proactively recommend morning briefings, hydration checks, and schedule prep.
              </p>
            </div>
            <Toggle
              checked={settings.proactiveSuggestions}
              onChange={(val) => onUpdate('proactiveSuggestions', val)}
              size="sm"
            />
          </div>

          <div className="pt-3 border-t border-[var(--color-border-subtle)] space-y-2">
            <div className="flex items-center justify-between">
              <div>
                <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                  Response Conciseness
                </span>
                <p className="text-xs text-[var(--color-text-secondary)]">
                  Balance between compact bullet points and in-depth explanatory answers.
                </p>
              </div>
              <span className="text-xs font-mono text-[var(--color-accent)] font-bold">
                {settings.concisenessLevel < 35
                  ? 'Terse & Direct'
                  : settings.concisenessLevel > 65
                  ? 'Detailed & Explanatory'
                  : 'Balanced Standard'}
              </span>
            </div>
            <Slider
              value={settings.concisenessLevel}
              onChange={(val) => onUpdate('concisenessLevel', val)}
              min={0}
              max={100}
              step={5}
            />
          </div>

          <div className="pt-3 border-t border-[var(--color-border-subtle)] space-y-2">
            <div className="flex items-center justify-between">
              <div>
                <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                  Emotional Resonance & Empathy
                </span>
                <p className="text-xs text-[var(--color-text-secondary)]">
                  Level of warmth, supportive phrasing, and encouragement in conversational replies.
                </p>
              </div>
              <span className="text-xs font-mono text-[var(--color-accent)] font-bold">
                {settings.empathyLevel < 35
                  ? 'Neutral & Objective'
                  : settings.empathyLevel > 65
                  ? 'Warm & Expressive'
                  : 'Gentle & Supportive'}
              </span>
            </div>
            <Slider
              value={settings.empathyLevel}
              onChange={(val) => onUpdate('empathyLevel', val)}
              min={0}
              max={100}
              step={5}
            />
          </div>

          <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Strict Factual Grounding
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Prevent creative embellishment; require cited facts from local knowledge base or tool execution.
              </p>
            </div>
            <Toggle
              checked={settings.strictFactualGrounding}
              onChange={(val) => onUpdate('strictFactualGrounding', val)}
              size="sm"
            />
          </div>

          <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
            <div>
              <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
                Continuous Episodic Memory Extraction
              </span>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Automatically extract and index facts, preferences, and recurring schedule routines into SQLite.
              </p>
            </div>
            <Toggle
              checked={settings.autoExtractMemories}
              onChange={(val) => onUpdate('autoExtractMemories', val)}
              size="sm"
            />
          </div>
        </div>
      </div>

      {/* 3. BATCH 12.1: Language Preferences & Multilingual Engine */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-5">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-xl bg-accent-gradient flex items-center justify-center text-white shadow-xs">
              <Globe className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-sm font-bold text-[var(--color-text-primary)]">
                Language Preferences & Multilingual Engine
              </h3>
              <p className="text-xs text-[var(--color-text-secondary)]">
                Manage system understanding, code-switching, technical lexicon preservation, and Japanese typography.
              </p>
            </div>
          </div>
          <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[var(--color-accent)]/10 text-[var(--color-accent)] font-semibold border border-[var(--color-accent)]/20">
            Batch 12.1 Active
          </span>
        </div>

        {/* Primary Language */}
        <div className="space-y-2">
          <label className="text-xs font-semibold text-[var(--color-text-primary)] block">
            Primary Language
          </label>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5">
            {[
              { id: 'en', label: 'English', flag: '🇺🇸', desc: 'Universal System Standard' },
              { id: 'fil', label: 'Filipino / Tagalog', flag: '🇵🇭', desc: 'Wikang Pambansa / Taglish' },
              { id: 'ja', label: 'Japanese', flag: '🇯🇵', desc: '日本語 (Kanji/Kana)' },
              { id: 'auto_detect', label: 'Auto-Detect', flag: '🌐', desc: 'Whisper Dynamic LID' },
            ].map((lang) => {
              const isSelected = langPrefs.primaryLanguage === lang.id;
              return (
                <button
                  key={lang.id}
                  type="button"
                  onClick={() => updateLangPref('primaryLanguage', lang.id as any)}
                  className={`p-3 rounded-2xl border text-left transition-all ${
                    isSelected
                      ? 'border-[var(--color-accent)] bg-[var(--color-surface-elevated)] ring-2 ring-[var(--color-accent)]/20 shadow-xs'
                      : 'border-[var(--color-border-subtle)] bg-[var(--color-surface-elevated)]/40 hover:bg-[var(--color-surface-elevated)] hover:border-[var(--color-accent)]/30'
                  }`}
                >
                  <div className="flex items-center gap-2 mb-1">
                    <span className="text-base">{lang.flag}</span>
                    <span className="text-xs font-bold text-[var(--color-text-primary)]">{lang.label}</span>
                  </div>
                  <span className="text-[10px] text-[var(--color-text-secondary)] block font-mono">{lang.desc}</span>
                </button>
              );
            })}
          </div>
        </div>

        {/* Understood Languages (Multi-select) */}
        <div className="pt-3 border-t border-[var(--color-border-subtle)] space-y-2">
          <div className="flex items-center justify-between">
            <div>
              <span className="text-xs font-semibold text-[var(--color-text-primary)] block">
                Understood Languages (Input Comprehension)
              </span>
              <p className="text-[11px] text-[var(--color-text-secondary)]">
                Languages the assistant actively transcribes, processes, and reasons over without translation requests.
              </p>
            </div>
            <span className="text-[10px] font-mono text-[var(--color-accent)] font-semibold">
              {langPrefs.understoodLanguages.length} Active
            </span>
          </div>

          <div className="flex flex-wrap gap-2 pt-1">
            {[
              { code: 'en' as const, name: 'English', flag: '🇺🇸', sub: 'Native Prompting' },
              { code: 'fil' as const, name: 'Filipino / Tagalog', flag: '🇵🇭', sub: 'Tagalog & Taglish' },
              { code: 'ja' as const, name: 'Japanese (日本語)', flag: '🇯🇵', sub: 'Kanji, Kana, Romaji' },
            ].map((lang) => {
              const isChecked = langPrefs.understoodLanguages.includes(lang.code);
              return (
                <button
                  key={lang.code}
                  type="button"
                  onClick={() => toggleUnderstoodLang(lang.code)}
                  className={`px-3.5 py-2 rounded-xl border text-xs font-medium flex items-center gap-2 transition-all ${
                    isChecked
                      ? 'border-[var(--color-accent)] bg-[var(--color-accent)]/10 text-[var(--color-accent)] shadow-xs font-semibold'
                      : 'border-[var(--color-border-subtle)] surface-base text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] opacity-75 hover:opacity-100'
                  }`}
                >
                  <span className="text-sm">{lang.flag}</span>
                  <span>{lang.name}</span>
                  {isChecked && <Check className="w-3.5 h-3.5 ml-1" />}
                </button>
              );
            })}
          </div>
        </div>

        {/* Code-Switching & Mixed Inputs Toggle */}
        <div className="flex items-center justify-between gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
          <div>
            <span className="text-sm font-semibold text-[var(--color-text-primary)] block">
              Enable Mixed-Language Input (Code-Switching)
            </span>
            <p className="text-xs text-[var(--color-text-secondary)]">
              Allows speaking or typing mixed-language sentences (e.g. English + Tagalog, English + Japanese, Tagalog + Japanese, English + Tagalog + Japanese) without segmentation errors.
            </p>
          </div>
          <Toggle
            checked={langPrefs.codeSwitchingEnabled}
            onChange={(val) => updateLangPref('codeSwitchingEnabled', val)}
            size="sm"
          />
        </div>

        {/* Response Language Mode & Technical Language */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-3 border-t border-[var(--color-border-subtle)]">
          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-[var(--color-text-primary)]">
              Assistant Output Language
            </label>
            <select
              value={langPrefs.responseLanguage}
              onChange={(e) => updateLangPref('responseLanguage', e.target.value as ResponseLanguageMode)}
              style={{ colorScheme: mode }}
              className="w-full px-3.5 py-2.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] font-medium focus:outline-none focus:border-[var(--color-accent)] transition-all cursor-pointer shadow-xs"
            >
              <option value="auto" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Auto-Adaptive (Follows conversation flow)</option>
              <option value="user_input" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Match exact user input language</option>
              <option value="primary" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Always reply in Primary Language</option>
              <option value="en" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>English only</option>
              <option value="fil" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Filipino / Tagalog only</option>
              <option value="ja" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Japanese only</option>
            </select>
          </div>

          <div className="space-y-1.5">
            <label className="text-xs font-semibold text-[var(--color-text-primary)]">
              Technical & Engineering Terms
            </label>
            <select
              value={langPrefs.technicalResponseLanguage}
              onChange={(e) => updateLangPref('technicalResponseLanguage', e.target.value as TechnicalResponseLanguageMode)}
              style={{ colorScheme: mode }}
              className="w-full px-3.5 py-2.5 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] font-medium focus:outline-none focus:border-[var(--color-accent)] transition-all cursor-pointer shadow-xs"
            >
              <option value="preserve_english" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Preserve English terms (Recommended: GPU, tokens/sec)</option>
              <option value="match_conversation" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Translate when natural in target language</option>
              <option value="dual_bilingual" className={mode === 'dark' ? 'bg-[#121824] text-slate-100 py-1' : 'bg-white text-slate-900 py-1'}>Dual bilingual notation (Target term + English ref)</option>
            </select>
          </div>
        </div>

        {/* Japanese Display Format */}
        <div className="pt-3 border-t border-[var(--color-border-subtle)] space-y-2">
          <label className="text-xs font-semibold text-[var(--color-text-primary)] block">
            Japanese Text Display Format
          </label>
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
            {[
              { id: 'kanji_furigana' as const, label: 'Kanji + Furigana', sample: '漢字 [かんじ]' },
              { id: 'kanji_only' as const, label: 'Kanji & Kana Only', sample: '漢字のみ' },
              { id: 'romaji_subtext' as const, label: 'Kanji + Romaji Subtext', sample: '漢字 (Kanji)' },
              { id: 'romaji_only' as const, label: 'Romaji Only', sample: 'Romaji' },
            ].map((fmt) => {
              const isSelected = langPrefs.japaneseDisplayFormat === fmt.id;
              return (
                <button
                  key={fmt.id}
                  type="button"
                  onClick={() => updateLangPref('japaneseDisplayFormat', fmt.id)}
                  className={`p-2.5 rounded-xl border text-left transition-all ${
                    isSelected
                      ? 'border-[var(--color-accent)] bg-[var(--color-surface-elevated)] ring-1 ring-[var(--color-accent)]/30 font-semibold shadow-xs'
                      : 'border-[var(--color-border-subtle)] surface-base text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
                  }`}
                >
                  <span className="text-xs font-bold block text-[var(--color-text-primary)]">{fmt.label}</span>
                  <span className="text-[10px] text-[var(--color-accent)] font-mono block mt-0.5">{fmt.sample}</span>
                </button>
              );
            })}
          </div>
        </div>

        {/* Live Multilingual Dialogue Preview Card */}
        <div className="p-4 rounded-2xl bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] space-y-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <BookOpen className="w-4 h-4 text-[var(--color-accent)]" />
              <span className="text-xs font-bold text-[var(--color-text-primary)]">
                Live Code-Switching Output Preview
              </span>
            </div>
            <div className="flex items-center gap-1.5">
              {mockMultilingualDialogues.map((sample) => (
                <button
                  key={sample.id}
                  type="button"
                  onClick={() => setActivePreviewSample(sample.id)}
                  className={`px-2 py-0.5 rounded-md text-[10px] font-mono transition-all ${
                    activePreviewSample === sample.id
                      ? 'bg-[var(--color-accent)] text-white font-bold'
                      : 'text-[var(--color-text-muted)] hover:text-[var(--color-text-primary)] surface-recessed'
                  }`}
                >
                  {sample.category === 'taglish'
                    ? 'Taglish'
                    : sample.category === 'eng_jap'
                    ? 'Eng+Jap'
                    : sample.category === 'tagalog_jap'
                    ? 'Tag+Jap'
                    : 'Trilingual'}
                </button>
              ))}
            </div>
          </div>

          <div className="p-3 rounded-xl surface-recessed border border-[var(--color-border-subtle)] space-y-2">
            <div className="flex items-start gap-2">
              <span className="text-[10px] font-bold font-mono text-[var(--color-text-muted)] uppercase px-1.5 py-0.5 rounded surface-base border border-[var(--color-border-subtle)]">
                User Input
              </span>
              <p className="text-xs text-[var(--color-text-secondary)] italic">
                "{currentSample.userInput}"
              </p>
            </div>

            <div className="pt-2 border-t border-[var(--color-border-subtle)]/60">
              <div className="flex items-center gap-2 mb-1">
                <span className="text-[10px] font-bold font-mono text-[var(--color-accent)] uppercase px-1.5 py-0.5 rounded bg-[var(--color-accent)]/10 border border-[var(--color-accent)]/20">
                  {currentSample.characterName} Synthesis
                </span>
                <span className="text-[10px] text-[var(--color-text-muted)] font-mono">
                  {currentSample.title}
                </span>
              </div>

              <div className="text-xs text-[var(--color-text-primary)] leading-relaxed pl-1">
                {currentSample.assistantOutput.kanjiText ? (
                  <div className="space-y-1.5">
                    <p>{currentSample.assistantOutput.en}</p>
                    <div className="p-2 rounded-lg surface-base border border-[var(--color-border-subtle)]">
                      <JapaneseTextRenderer
                        kanjiText={currentSample.assistantOutput.kanjiText}
                        furiganaText={currentSample.assistantOutput.furiganaText}
                        romajiText={currentSample.assistantOutput.romajiText}
                        format={langPrefs.japaneseDisplayFormat}
                      />
                    </div>
                  </div>
                ) : (
                  <p>{currentSample.assistantOutput.en}</p>
                )}

                {currentSample.assistantOutput.tagalogGlossary && (
                  <div className="flex flex-wrap gap-1.5 mt-2 pt-2 border-t border-[var(--color-border-subtle)]/40">
                    <span className="text-[10px] font-mono text-[var(--color-text-muted)]">Glossary:</span>
                    {currentSample.assistantOutput.tagalogGlossary.map((item, i) => (
                      <span
                        key={i}
                        className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-[var(--color-surface-elevated)] border border-[var(--color-border-subtle)] text-[var(--color-accent)]"
                      >
                        {item}
                      </span>
                    ))}
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
