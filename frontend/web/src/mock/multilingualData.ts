import {
  LanguagePreferences,
  VoiceLanguageCapability,
  CharacterLanguageStyle,
  SupportedLanguageCode,
  JapaneseDisplayFormat,
} from '../types';

export interface LanguageOption {
  code: SupportedLanguageCode;
  name: string;
  nativeName: string;
  flag: string;
  badge: string;
  description: string;
}

export const SUPPORTED_LANGUAGES: LanguageOption[] = [
  {
    code: 'en',
    name: 'English',
    nativeName: 'English',
    flag: '🇺🇸',
    badge: 'Standard',
    description: 'Universal language for prompt orchestration, tool definitions, and system telemetry.',
  },
  {
    code: 'fil',
    name: 'Filipino / Tagalog',
    nativeName: 'Wikang Filipino',
    flag: '🇵🇭',
    badge: 'High Accuracy',
    description: 'Native Tagalog and modern conversational Taglish with honorific particle nuances.',
  },
  {
    code: 'ja',
    name: 'Japanese',
    nativeName: '日本語 (Nihongo)',
    flag: '🇯🇵',
    badge: 'Neural Kana',
    description: 'Natural Kanji/Kana syntax with configurable Furigana phonetic hints and Keigo formality.',
  },
  {
    code: 'mixed',
    name: 'Mixed-Language (Code-Switching)',
    nativeName: 'Taglish / Eng-Jap / Trilingual',
    flag: '🌐',
    badge: 'Adaptive VAD',
    description: 'Fluid intra-sentence code-switching combining English, Tagalog, and Japanese.',
  },
];

export const defaultLanguagePreferences: LanguagePreferences = {
  primaryLanguage: 'en',
  understoodLanguages: ['en', 'fil', 'ja'],
  codeSwitchingEnabled: true,
  responseLanguage: 'auto',
  technicalResponseLanguage: 'preserve_english',
  japaneseDisplayFormat: 'kanji_furigana',
};

export const defaultCharacterLanguageStyles: Record<string, CharacterLanguageStyle> = {
  // Aura: Executive cognitive assistant, adapts smoothly with natural code-switching
  'p-1': {
    primaryLanguage: 'match_user',
    secondaryLanguages: ['en', 'fil', 'ja'],
    matchUserLanguage: true,
    codeSwitchingFrequency: 'natural',
    tagalogParticleFrequency: 'natural',
    japaneseHonorificsFrequency: 'polite_desu_masu',
    japaneseTone: 'polite_desu_masu',
  },
  // Chronos: Precise task architect, structured and polite
  'p-2': {
    primaryLanguage: 'en',
    secondaryLanguages: ['en', 'ja'],
    matchUserLanguage: true,
    codeSwitchingFrequency: 'rare',
    tagalogParticleFrequency: 'minimal',
    japaneseHonorificsFrequency: 'formal_keigo',
    japaneseTone: 'business_keigo',
  },
  // Nexus: Code & systems specialist, preserves English tech keywords
  'p-3': {
    primaryLanguage: 'en',
    secondaryLanguages: ['en', 'ja', 'fil'],
    matchUserLanguage: true,
    codeSwitchingFrequency: 'natural',
    tagalogParticleFrequency: 'minimal',
    japaneseHonorificsFrequency: 'casual',
    japaneseTone: 'casual_teineigo',
  },
  // Lyra: Warm wellness guide, gentle Taglish and supportive Japanese
  'p-4': {
    primaryLanguage: 'match_user',
    secondaryLanguages: ['en', 'fil', 'ja'],
    matchUserLanguage: true,
    codeSwitchingFrequency: 'natural',
    tagalogParticleFrequency: 'natural',
    japaneseHonorificsFrequency: 'polite_desu_masu',
    japaneseTone: 'warm_conversational',
  },
  // Zephyr: Creative lateral synthesizer, highly expressive multilingual blend
  'p-5': {
    primaryLanguage: 'match_user',
    secondaryLanguages: ['en', 'fil', 'ja'],
    matchUserLanguage: true,
    codeSwitchingFrequency: 'frequent',
    tagalogParticleFrequency: 'colloquial',
    japaneseHonorificsFrequency: 'casual',
    japaneseTone: 'warm_conversational',
  },
};

export const voiceLanguageCapabilities: VoiceLanguageCapability[] = [
  {
    code: 'en',
    name: 'English (US / UK)',
    nativeName: 'English',
    sttFidelity: 100,
    ttsFidelity: 100,
    engine: 'Whisper.cpp Small (Metal/CUDA) + Kokoro-82M / Piper',
    codeSwitchSupported: true,
    notes: 'Zero-latency native acoustic mapping; 100% token accuracy across technical lexicons.',
  },
  {
    code: 'fil',
    name: 'Filipino / Tagalog',
    nativeName: 'Tagalog (Pilipinas)',
    sttFidelity: 96,
    ttsFidelity: 94,
    engine: 'Whisper.cpp Multilingual + Piper ONNX Tagalog Acoustic Model',
    codeSwitchSupported: true,
    notes: 'Optimized for modern Taglish, colloquial affixes (nag-, mag-, um-), and respect particles (po, opo).',
  },
  {
    code: 'ja',
    name: 'Japanese',
    nativeName: '日本語 (Japan)',
    sttFidelity: 98,
    ttsFidelity: 97,
    engine: 'Kokoro-82M (Japanese Phonemes) + MeCab / UniDic Tokenizer',
    codeSwitchSupported: true,
    notes: 'Native pitch-accent synthesis, Furigana phoneme alignment, and accurate Keigo/Desu-Masu cadence.',
  },
  {
    code: 'mixed',
    name: 'Mixed-Language (Code-Switching)',
    nativeName: 'Taglish / Eng-Jap / Trilingual',
    sttFidelity: 94,
    ttsFidelity: 92,
    engine: 'Interleaved Acoustic Decoder with Continuous Multi-lingual VAD',
    codeSwitchSupported: true,
    notes: 'Tracks intra-utterance transitions between English technical terms, Tagalog sentence structures, and Japanese greetings.',
  },
];

export interface MultilingualDialogueSample {
  id: string;
  category: 'taglish' | 'eng_jap' | 'tagalog_jap' | 'trilingual' | 'pure_tagalog' | 'pure_japanese';
  title: string;
  description: string;
  userInput: string;
  assistantOutput: {
    en: string;
    kanjiText?: string;
    furiganaText?: string;
    romajiText?: string;
    tagalogGlossary?: string[];
  };
  characterName: string;
}

export const mockMultilingualDialogues: MultilingualDialogueSample[] = [
  {
    id: 'dlg-taglish',
    category: 'taglish',
    title: 'English + Tagalog (Taglish)',
    description: 'Workstation orchestration with natural Filipino sentence particles and English technical terminology.',
    userInput: 'Aura, pakicheck naman yung schedule natin for today, and let’s verify if the llama.cpp benchmark is finished na.',
    assistantOutput: {
      en: 'Noted, Chris! Chinek ko na ang local task queue. May 3 events ka for today, at tapos na rin ang Q4_K_M benchmark run with 42.8 tokens/sec. Lahat nominal at on-track.',
      tagalogGlossary: ['pakicheck (please check)', 'chinek (checked)', 'may (there are)', 'tapos na (already finished)', 'lahat (everything)'],
    },
    characterName: 'Aura',
  },
  {
    id: 'dlg-eng-jap',
    category: 'eng_jap',
    title: 'English + Japanese (Eng-Jap)',
    description: 'Polite Japanese greetings combined with English system engineering metrics.',
    userInput: 'Aura, konnichiwa! Can you check the current GPU VRAM utilization and temperature?',
    assistantOutput: {
      en: 'こんにちは、Chrisさん！ (Konnichiwa, Chris-san!) GPU memory is stable at 8.6 GB VRAM out of 16.0 GB. 温度は54°Cで非常に良好です (Temperature is 54°C, running cool and optimal).',
      kanjiText: 'こんにちは、Chrisさん！GPUメモリは安定しており、VRAMは8.6GB使用中です。温度は54°Cで非常に良好です。',
      furiganaText: 'こんにちは、Chrisさん！GPUメモリは[安定|あんてい]しており、VRAMは8.6GB[使用中|しようちゅう]です。[温度|おんど]は54°Cで[非常|ひじょう]に[良好|りょうこう]です。',
      romajiText: 'Konnichiwa, Chris-san! GPU memori wa antei shite ori, VRAM wa hachi ten roku gigabyte shiyouchuu desu. Ondo wa gojuuyon do de hijou ni ryoukou desu.',
    },
    characterName: 'Aura',
  },
  {
    id: 'dlg-tagalog-jap',
    category: 'tagalog_jap',
    title: 'Tagalog + Japanese',
    description: 'Warm daily check-in with Tagalog pacing and Japanese cultural respect expressions.',
    userInput: 'Kamusta Aura, daijoubu ba ang status ng workstation natin ngayong hapon?',
    assistantOutput: {
      en: 'Mabuti naman, Chris! Daijoubu desu (大丈夫です). Lahat ng local daemons ay maayos na tumatakbo. Otsukaresama desu sa focus session mo kanina!',
      kanjiText: '大丈夫です。全てのローカルデーモンは順調に動作しています。お疲れ様でした！',
      furiganaText: '[大丈夫|だいじょうぶ]です。[全|すべ]てのローカルデーモンは[順調|じゅんちょう]に[動作|どうさ]しています。お[疲|つか]れ[様|さま]でした！',
      romajiText: 'Daijoubu desu. Subete no rookaru deemon wa junchou ni dousa shite imasu. Otsukaresama deshita!',
      tagalogGlossary: ['mabuti naman (doing well)', 'ngayong hapon (this afternoon)', 'tumatakbo (running)', 'kanina (earlier)'],
    },
    characterName: 'Lyra',
  },
  {
    id: 'dlg-trilingual',
    category: 'trilingual',
    title: 'Trilingual (English + Tagalog + Japanese)',
    description: 'Comprehensive code-switching seamlessly blending three languages.',
    userInput: 'Good morning Aura! Paki-summarize naman the health stats, tapos check natin if ready na ang code editor. Ganbatte tayo today!',
    assistantOutput: {
      en: 'Ohayou gozaimasu (おはようございます), Chris! Handa na ang workspace natin. Your sleep score last night was 88% with 7h 48m duration. Chinek ko na rin ang VS Code and local runtime—ready to code na tayo. 今日も一日、頑張りましょう (Let’s do our best today)!',
      kanjiText: 'おはようございます、Chrisさん！準備は整いました。今日も一日、頑張りましょう！',
      furiganaText: 'おはようございます、Chrisさん！[準備|じゅんび]は[整|ととの]いました。[今日|きょう]も[一日|いちにち]、[頑張|がんば]りましょう！',
      romajiText: 'Ohayou gozaimasu, Chris-san! Junbi wa totonoimashita. Kyou mo ichinichi, ganbarimashou!',
      tagalogGlossary: ['handa na (ready now)', 'chinek ko na rin (also checked)', 'tayo (we/us)'],
    },
    characterName: 'Zephyr',
  },
];

export function getLanguageAwareGreeting(
  language: SupportedLanguageCode | 'auto_detect',
  userName: string,
  hour: number = new Date().getHours()
): { greeting: string; subtitle: string; flag: string; langLabel: string } {
  const isMorning = hour >= 5 && hour < 12;
  const isAfternoon = hour >= 12 && hour < 17;
  const isEvening = hour >= 17 && hour < 22;

  switch (language) {
    case 'fil':
      if (isMorning) {
        return {
          greeting: `Magandang umaga, ${userName}!`,
          subtitle: 'Handa na ang local neural core at maayos ang takbo ng lahat ng system daemons.',
          flag: '🇵🇭',
          langLabel: 'Filipino / Tagalog',
        };
      } else if (isAfternoon) {
        return {
          greeting: `Magandang hapon, ${userName}!`,
          subtitle: 'Kasalukuyang naka-standby ang AI companion para sa iyong afternoon tasks at focus blocks.',
          flag: '🇵🇭',
          langLabel: 'Filipino / Tagalog',
        };
      } else if (isEvening) {
        return {
          greeting: `Magandang gabi, ${userName}!`,
          subtitle: 'Lahat ng daily telemetry ay naka-sync at handa na para sa iyong evening review.',
          flag: '🇵🇭',
          langLabel: 'Filipino / Tagalog',
        };
      } else {
        return {
          greeting: `Magandang gabi, ${userName}! Matulog nang mahimbing.`,
          subtitle: 'Nasa quiet mode ang audio subsystem at naka-throttle ang background daemons.',
          flag: '🇵🇭',
          langLabel: 'Filipino / Tagalog',
        };
      }

    case 'ja':
      if (isMorning) {
        return {
          greeting: `おはようございます、${userName}さん。`,
          subtitle: 'ローカルAIコアは正常に起動しています。本日のタスクとスケジュールを確認できます。',
          flag: '🇯🇵',
          langLabel: '日本語 (Japanese)',
        };
      } else if (isAfternoon) {
        return {
          greeting: `こんにちは、${userName}さん。`,
          subtitle: 'システムは安定して稼働中です。午後の作業準備が整っています。',
          flag: '🇯🇵',
          langLabel: '日本語 (Japanese)',
        };
      } else if (isEvening) {
        return {
          greeting: `こんばんは、${userName}さん。お疲れ様です。`,
          subtitle: '本日の生体ログとタスク履歴が同期完了しました。',
          flag: '🇯🇵',
          langLabel: '日本語 (Japanese)',
        };
      } else {
        return {
          greeting: `おやすみなさい、${userName}さん。`,
          subtitle: 'バックグラウンド推論は省電力モードに移行しました。',
          flag: '🇯🇵',
          langLabel: '日本語 (Japanese)',
        };
      }

    case 'mixed':
      if (isMorning) {
        return {
          greeting: `Good morning, ${userName}! Handa na ang AI core natin.`,
          subtitle: 'All 3 events are synced. Konnichiwa sa panibagong araw ng deep work at coding!',
          flag: '🌐',
          langLabel: 'Taglish / Multilingual',
        };
      } else if (isAfternoon) {
        return {
          greeting: `Good afternoon, ${userName}! Kamusta ang workflow mo?`,
          subtitle: 'Daijoubu ang GPU thermals at ready na ang local model for quick queries.',
          flag: '🌐',
          langLabel: 'Taglish / Multilingual',
        };
      } else if (isEvening) {
        return {
          greeting: `Good evening, ${userName}! Otsukaresama sa araw na ito.`,
          subtitle: 'Everything is locked and indexed into local memory without any cloud leaks.',
          flag: '🌐',
          langLabel: 'Taglish / Multilingual',
        };
      } else {
        return {
          greeting: `Good night, ${userName}! Pahinga na po nang maayos.`,
          subtitle: 'System is entering quiet circadian sleep state with zero cloud telemetry.',
          flag: '🌐',
          langLabel: 'Taglish / Multilingual',
        };
      }

    case 'en':
    default:
      if (isMorning) {
        return {
          greeting: `Good morning, ${userName}.`,
          subtitle: 'Local AI core standing by on Llama-3.1-8B-Instruct with all background daemons nominal.',
          flag: '🇺🇸',
          langLabel: 'English',
        };
      } else if (isAfternoon) {
        return {
          greeting: `Good afternoon, ${userName}.`,
          subtitle: 'Here’s what’s happening today. All tasks and circadian focus blocks are balanced.',
          flag: '🇺🇸',
          langLabel: 'English',
        };
      } else if (isEvening) {
        return {
          greeting: `Good evening, ${userName}.`,
          subtitle: 'Daily telemetry synced with local SQLite memory store. Zero cloud transmission.',
          flag: '🇺🇸',
          langLabel: 'English',
        };
      } else {
        return {
          greeting: `Good night, ${userName}.`,
          subtitle: 'Workstation in quiet mode. Ready to orchestrate tomorrow’s schedule whenever you are.',
          flag: '🇺🇸',
          langLabel: 'English',
        };
      }
  }
}
