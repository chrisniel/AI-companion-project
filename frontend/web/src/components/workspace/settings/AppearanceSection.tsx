import React, { useRef, useState, useEffect } from 'react';
import {
  Palette,
  Sun,
  Moon,
  Laptop,
  Sparkles,
  Layers,
  Zap,
  LayoutGrid,
  Check,
  Image as ImageIcon,
  Sliders,
  RefreshCw,
  Upload,
  Trash2,
  Paintbrush,
  Droplet,
  Compass,
} from 'lucide-react';
import { useTheme, ACCENT_PRESETS } from '../../../context/ThemeContext';
import {
  ThemePreference,
  AccentPresetId,
  EffectIntensity,
  InterfaceDensity,
  AnimationPreference,
  BackgroundType,
  BuiltinBackgroundId,
  BackgroundFit,
  BackgroundPosition,
  GradientDirection,
  GlassPreset,
} from '../../../types';
import {
  BUILTIN_BACKGROUND_PRESETS,
  SAMPLE_CUSTOM_IMAGES,
  SOLID_COLOR_PRESETS,
} from '../../../context/backgroundPresets';
import { LiveAppearancePreview } from './LiveAppearancePreview';

export const AppearanceSection: React.FC = () => {
  const {
    mode,
    themePreference,
    setThemePreference,
    accent,
    setAccent,
    customAccentColor,
    setCustomAccentColor,
    effectIntensity,
    setEffectIntensity,
    interfaceDensity,
    setInterfaceDensity,
    animationPreference,
    setAnimationPreference,
    backgroundSettings,
    updateBackgroundSettings,
    setThemePreset,
    resetBackgroundSettings,
    glassSettings,
    updateGlassSettings,
    setGlassPreset,
    resetGlassSettings,
  } = useTheme();

  const fileInputRef = useRef<HTMLInputElement>(null);
  const [customAccentEnabled, setCustomAccentEnabled] = useState(Boolean(customAccentColor));
  const [accentHexInput, setAccentHexInput] = useState(customAccentColor || '#2563eb');
  const [selectedPresetCategory, setSelectedPresetCategory] = useState<'light' | 'dark'>(
    mode === 'dark' ? 'dark' : 'light'
  );

  // Keep preset selector synchronized when active theme changes
  useEffect(() => {
    setSelectedPresetCategory(mode === 'dark' ? 'dark' : 'light');
  }, [mode]);

  const themeOptions: { id: ThemePreference; label: string; icon: React.ReactNode; desc: string }[] = [
    {
      id: 'light',
      label: 'Light',
      icon: <Sun className="w-5 h-5 text-amber-500" />,
      desc: 'Solid darker blue accent on high-contrast crisp neutral surface',
    },
    {
      id: 'dark',
      label: 'Dark',
      icon: <Moon className="w-5 h-5 text-sky-400" />,
      desc: 'Solid lighter sky blue accent on deep OLED slate canvas',
    },
    {
      id: 'system',
      label: 'System',
      icon: <Laptop className="w-5 h-5 text-indigo-400" />,
      desc: 'Synchronizes automatically with your OS light/dark schedule',
    },
  ];

  const glassPresetOptions: {
    id: GlassPreset;
    title: string;
    description: string;
    metrics: string;
  }[] = [
    {
      id: 'reduced',
      title: 'Reduced',
      description: 'High surface opacity, subtle 6px blur, minimal transparency',
      metrics: '85% Opacity • 6px Blur • 90% Tint',
    },
    {
      id: 'normal',
      title: 'Normal (Approved Soft Glass)',
      description: 'Balanced frosted diffusion, refined 16px blur, optimal clarity',
      metrics: '70% Opacity • 16px Blur • 80% Tint',
    },
    {
      id: 'enhanced',
      title: 'Enhanced',
      description: 'Deeper transparency, pronounced 24px blur, richer color',
      metrics: '58% Opacity • 24px Blur • 70% Tint',
    },
  ];

  const intensityOptions: {
    id: EffectIntensity;
    title: string;
    description: string;
    detail: string;
  }[] = [
    {
      id: 'reduced',
      title: 'Reduced',
      description: 'Less blur, shadow, and decorative depth',
      detail: 'Minimal 4px backdrop blur, subtle borders, high contrast and ultra-fast rendering.',
    },
    {
      id: 'normal',
      title: 'Normal',
      description: 'Approved Soft Glass appearance',
      detail: 'Default balanced neumorphic elevation, refined 16px frosted glass, and gentle tactile surfaces.',
    },
    {
      id: 'enhanced',
      title: 'Enhanced',
      description: 'Stronger glass and tactile effects',
      detail: 'Deep 28px glassmorphism, pronounced physical shadows, and rich sculptural tactile depth.',
    },
  ];

  const densityOptions: {
    id: InterfaceDensity;
    title: string;
    description: string;
  }[] = [
    {
      id: 'comfortable',
      title: 'Comfortable (Default)',
      description: 'Spacious padding, generous click targets (44px+), and relaxed typographic rhythm.',
    },
    {
      id: 'compact',
      title: 'Compact Density',
      description: 'Tighter row heights, condensed padding, optimized for high-density multi-pane viewing.',
    },
  ];

  const animationOptions: {
    id: AnimationPreference;
    title: string;
    description: string;
  }[] = [
    {
      id: 'fluid',
      title: 'Fluid (60 FPS)',
      description: 'Smooth spring physics, reactive hover elevations, and graceful layout transitions.',
    },
    {
      id: 'reduced',
      title: 'Reduced Motion',
      description: 'Snappy short transitions (100ms) with no heavy layout shifts or sliding animations.',
    },
    {
      id: 'none',
      title: 'Instant (No Animations)',
      description: 'Immediate state switching with zero transition duration for maximum accessibility.',
    },
  ];

  // Handle local image upload via FileReader
  const handleImageUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (event) => {
        const result = event.target?.result as string;
        if (result) {
          updateBackgroundSettings('customImageUrl', result);
          updateBackgroundSettings('type', 'custom');
        }
      };
      reader.readAsDataURL(file);
    }
  };

  const handleCustomAccentToggle = (enabled: boolean) => {
    setCustomAccentEnabled(enabled);
    if (!enabled) {
      setCustomAccentColor(null);
    } else {
      setCustomAccentColor(accentHexInput);
    }
  };

  const handleCustomAccentHexChange = (hex: string) => {
    setAccentHexInput(hex);
    if (customAccentEnabled && /^#[0-9A-Fa-f]{6}$/.test(hex)) {
      setCustomAccentColor(hex);
    }
  };

  // Filter built-in presets by category
  const lightPresets = Object.values(BUILTIN_BACKGROUND_PRESETS).filter((p) => p.category === 'light');
  const darkPresets = Object.values(BUILTIN_BACKGROUND_PRESETS).filter((p) => p.category === 'dark');

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h2 className="text-base font-bold text-[var(--color-text-primary)] flex items-center gap-2">
          <Palette className="w-5 h-5 text-[var(--color-accent)]" />
          Appearance & Visual Styling
        </h2>
        <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
          Customize environmental background, Soft Glass transparency, tactile effect intensity, and solid accent palettes.
        </p>
      </div>

      {/* 1. Live Appearance & Glass Preview Area */}
      <LiveAppearancePreview />

      {/* 2. Theme Mode Selection (Light / Dark / System) */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
          <Sun className="w-4 h-4" />
          Theme Mode
        </h3>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          {themeOptions.map((opt) => {
            const isSelected = themePreference === opt.id;
            return (
              <button
                key={opt.id}
                type="button"
                onClick={() => setThemePreference(opt.id)}
                className={`p-4 rounded-2xl border text-left transition-all relative flex flex-col justify-between ${
                  isSelected
                    ? 'border-[var(--color-accent)] bg-[var(--color-surface-elevated)] ring-2 ring-[var(--color-accent)]/20 shadow-sm'
                    : 'border-[var(--color-border-subtle)] bg-[var(--color-surface-elevated)]/50 hover:bg-[var(--color-surface-elevated)] hover:border-[var(--color-accent)]/30'
                }`}
              >
                {isSelected && (
                  <span className="absolute top-3 right-3 w-5 h-5 rounded-full bg-[var(--color-accent)] text-white flex items-center justify-center">
                    <Check className="w-3 h-3" />
                  </span>
                )}
                <div className="space-y-2">
                  <div className="p-2 rounded-xl bg-[var(--color-surface-secondary)] w-fit">
                    {opt.icon}
                  </div>
                  <div>
                    <h4 className="text-sm font-bold text-[var(--color-text-primary)]">
                      {opt.label}
                    </h4>
                    <p className="text-xs text-[var(--color-text-secondary)] mt-0.5 leading-relaxed">
                      {opt.desc}
                    </p>
                  </div>
                </div>
                <div className="mt-3 pt-2 border-t border-[var(--color-border-subtle)] flex items-center justify-between text-[11px] font-mono text-[var(--color-text-muted)]">
                  <span>Current: {mode === opt.id ? 'Active' : isSelected ? 'System Sync' : 'Inactive'}</span>
                </div>
              </button>
            );
          })}
        </div>
      </div>

      {/* 3. Background Customization System (Built-in, Custom Image, Gradient, Solid Color) */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-5">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
          <div>
            <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
              <ImageIcon className="w-4 h-4" />
              Application Background
            </h3>
            <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
              Decorative environmental background layer rendered behind frosted glass surfaces across all pages.
            </p>
          </div>

          <button
            type="button"
            onClick={resetBackgroundSettings}
            className="flex items-center gap-1.5 text-xs text-[var(--color-text-muted)] hover:text-[var(--color-accent)] transition-colors self-start sm:self-auto"
          >
            <RefreshCw className="w-3.5 h-3.5" />
            <span>Reset Background</span>
          </button>
        </div>

        {/* Background Source Type Segmented Navigation */}
        <div className="flex items-center p-1 rounded-2xl bg-[var(--color-surface-secondary)] border border-[var(--color-border-subtle)] gap-1 overflow-x-auto">
          {[
            { id: 'builtin' as BackgroundType, label: 'Built-in Presets', icon: <Sparkles className="w-3.5 h-3.5" /> },
            { id: 'custom' as BackgroundType, label: 'Custom Image', icon: <Upload className="w-3.5 h-3.5" /> },
            { id: 'gradient' as BackgroundType, label: 'Gradient', icon: <Droplet className="w-3.5 h-3.5" /> },
            { id: 'solid' as BackgroundType, label: 'Solid Color', icon: <Paintbrush className="w-3.5 h-3.5" /> },
          ].map((tab) => {
            const isSelected = backgroundSettings.type === tab.id;
            return (
              <button
                key={tab.id}
                type="button"
                onClick={() => updateBackgroundSettings('type', tab.id)}
                className={`flex-1 min-w-[120px] py-2 px-3 rounded-xl text-xs font-medium flex items-center justify-center gap-1.5 transition-all ${
                  isSelected
                    ? 'bg-[var(--color-surface-elevated)] text-[var(--color-accent)] shadow-xs font-semibold border border-[var(--color-border-subtle)]'
                    : 'text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] hover:bg-[var(--color-surface-elevated)]/40'
                }`}
              >
                {tab.icon}
                <span>{tab.label}</span>
              </button>
            );
          })}
        </div>

        {/* TAB 1: BUILT-IN PRESETS */}
        {backgroundSettings.type === 'builtin' && (
          <div className="space-y-4">
            {/* Theme Filter Navigation Sub-tabs */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 p-1.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)]">
              <div className="flex items-center gap-1.5 w-full sm:w-auto">
                <button
                  type="button"
                  onClick={() => setSelectedPresetCategory('light')}
                  className={`flex-1 sm:flex-initial py-1.5 px-3.5 rounded-xl text-xs font-medium flex items-center justify-center gap-2 transition-all ${
                    selectedPresetCategory === 'light'
                      ? 'bg-[var(--color-surface-elevated)] text-[var(--color-accent)] font-semibold shadow-xs border border-[var(--color-border-subtle)]'
                      : 'text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
                  }`}
                >
                  <Sun className="w-3.5 h-3.5 text-amber-500" />
                  <span>Light Presets</span>
                  {mode === 'light' && (
                    <span className="px-1.5 py-0.5 rounded-md bg-amber-500/15 text-amber-600 dark:text-amber-400 text-[10px] font-mono font-bold">
                      ACTIVE
                    </span>
                  )}
                </button>

                <button
                  type="button"
                  onClick={() => setSelectedPresetCategory('dark')}
                  className={`flex-1 sm:flex-initial py-1.5 px-3.5 rounded-xl text-xs font-medium flex items-center justify-center gap-2 transition-all ${
                    selectedPresetCategory === 'dark'
                      ? 'bg-[var(--color-surface-elevated)] text-[var(--color-accent)] font-semibold shadow-xs border border-[var(--color-border-subtle)]'
                      : 'text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
                  }`}
                >
                  <Moon className="w-3.5 h-3.5 text-sky-400" />
                  <span>Dark Presets</span>
                  {mode === 'dark' && (
                    <span className="px-1.5 py-0.5 rounded-md bg-sky-500/15 text-sky-600 dark:text-sky-400 text-[10px] font-mono font-bold">
                      ACTIVE
                    </span>
                  )}
                </button>
              </div>

              <div className="text-[11px] text-[var(--color-text-muted)] px-2 sm:px-0">
                {selectedPresetCategory === 'light'
                  ? 'Configuring wallpapers for Light Theme'
                  : 'Configuring wallpapers for Dark Theme'}
              </div>
            </div>

            {/* Explanation / Theme Sync Notice */}
            <div className="p-3 rounded-2xl bg-[var(--color-surface-secondary)]/60 border border-[var(--color-border-subtle)] flex items-center justify-between gap-3 text-xs">
              <div className="flex items-center gap-2 text-[var(--color-text-secondary)]">
                <Sparkles className="w-4 h-4 text-[var(--color-accent)] flex-shrink-0" />
                <span>
                  {selectedPresetCategory === 'light'
                    ? 'Light presets are paired with light Soft Glass to maintain sharp contrast and eliminate dark-mode glare.'
                    : 'Dark presets are tuned for deep obsidian surfaces and glowing accent reflections in dark mode.'}
                </span>
              </div>
              {selectedPresetCategory !== mode && (
                <button
                  type="button"
                  onClick={() => setThemePreference(selectedPresetCategory)}
                  className="flex-shrink-0 px-2.5 py-1 rounded-lg bg-[var(--color-surface-elevated)] hover:bg-[var(--color-accent)] hover:text-white text-[11px] font-semibold text-[var(--color-accent)] border border-[var(--color-border-subtle)] transition-all"
                >
                  Switch to {selectedPresetCategory === 'light' ? 'Light' : 'Dark'} Mode
                </button>
              )}
            </div>

            {/* PRESETS GRID FOR SELECTED THEME */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
              {(selectedPresetCategory === 'light' ? lightPresets : darkPresets).map((p) => {
                const isSelected =
                  backgroundSettings.type === 'builtin' &&
                  (selectedPresetCategory === 'light'
                    ? backgroundSettings.lightPresetId === p.id
                    : backgroundSettings.darkPresetId === p.id);

                return (
                  <button
                    key={p.id}
                    type="button"
                    onClick={() => {
                      setThemePreset(selectedPresetCategory, p.id as BuiltinBackgroundId);
                      updateBackgroundSettings('type', 'builtin');
                    }}
                    className={`p-3 rounded-2xl border text-left transition-all relative overflow-hidden flex flex-col justify-between group ${
                      isSelected
                        ? 'border-[var(--color-accent)] ring-2 ring-[var(--color-accent)]/20 shadow-sm bg-[var(--color-surface-elevated)]'
                        : 'border-[var(--color-border-subtle)] hover:border-[var(--color-accent)]/40 hover:bg-[var(--color-surface-elevated)]/30'
                    }`}
                  >
                    {/* Mini Preview Swatch */}
                    <div
                      className="w-full h-16 rounded-xl mb-2.5 relative overflow-hidden border border-black/5 dark:border-white/10 flex items-end p-2 transition-transform duration-300 group-hover:scale-[1.02]"
                      style={{ backgroundImage: p.css }}
                    >
                      <div className="flex items-center gap-1">
                        {p.colors.map((c, i) => (
                          <span
                            key={i}
                            className="w-2.5 h-2.5 rounded-full border border-black/10 dark:border-white/20 shadow-xs"
                            style={{ backgroundColor: c }}
                          />
                        ))}
                      </div>

                      {isSelected && (
                        <div className="absolute top-1.5 right-1.5 px-1.5 py-0.5 rounded-md bg-black/60 backdrop-blur-xs text-white text-[9px] font-mono uppercase font-bold flex items-center gap-1">
                          <Check className="w-2.5 h-2.5 text-emerald-400" />
                          <span>Selected</span>
                        </div>
                      )}
                    </div>

                    <div>
                      <div className="flex items-center justify-between">
                        <h4 className="text-xs font-bold text-[var(--color-text-primary)]">{p.name}</h4>
                        {isSelected && <Check className="w-3.5 h-3.5 text-[var(--color-accent)]" />}
                      </div>
                      <p className="text-[11px] text-[var(--color-text-secondary)] mt-0.5 line-clamp-2 leading-tight">
                        {p.description}
                      </p>
                    </div>
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {/* TAB 2: CUSTOM IMAGE */}
        {backgroundSettings.type === 'custom' && (
          <div className="space-y-4">
            <div className="flex flex-col sm:flex-row gap-4 items-start">
              {/* Upload Button & Preview */}
              <div className="flex-1 w-full space-y-3">
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/*"
                  onChange={handleImageUpload}
                  className="hidden"
                />

                <div className="flex flex-wrap gap-2">
                  <button
                    type="button"
                    onClick={() => fileInputRef.current?.click()}
                    className="px-4 py-2 rounded-xl surface-raised border border-[var(--color-border-subtle)] text-xs font-semibold text-[var(--color-text-primary)] hover:border-[var(--color-accent)]/40 active:scale-95 transition-all flex items-center gap-2 shadow-xs"
                  >
                    <Upload className="w-3.5 h-3.5 text-[var(--color-accent)]" />
                    <span>Upload Image File</span>
                  </button>

                  {backgroundSettings.customImageUrl && (
                    <button
                      type="button"
                      onClick={() => updateBackgroundSettings('customImageUrl', null)}
                      className="px-3 py-2 rounded-xl surface-raised border border-rose-500/20 text-xs font-medium text-rose-500 hover:bg-rose-500/10 active:scale-95 transition-all flex items-center gap-1.5"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                      <span>Remove Image</span>
                    </button>
                  )}
                </div>

                {/* Curated Sample Wallpapers */}
                <div className="pt-2">
                  <span className="text-[11px] font-semibold text-[var(--color-text-secondary)]">
                    Or select a curated mock wallpaper sample:
                  </span>
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-2.5 mt-2">
                    {SAMPLE_CUSTOM_IMAGES.map((sample) => {
                      const isSelected = backgroundSettings.customImageUrl === sample.url;
                      return (
                        <button
                          key={sample.id}
                          type="button"
                          onClick={() => {
                            updateBackgroundSettings('customImageUrl', sample.url);
                            updateBackgroundSettings('type', 'custom');
                          }}
                          className={`p-2.5 rounded-xl border text-left transition-all ${
                            isSelected
                              ? 'border-[var(--color-accent)] ring-1 ring-[var(--color-accent)] bg-[var(--color-surface-elevated)]'
                              : 'border-[var(--color-border-subtle)] bg-[var(--color-surface-elevated)]/40 hover:bg-[var(--color-surface-elevated)]'
                          }`}
                        >
                          <div
                            className="w-full h-12 rounded-lg mb-1.5 border border-white/10"
                            style={{ backgroundImage: `url("${sample.url}")`, backgroundSize: 'cover' }}
                          />
                          <h5 className="text-[11px] font-bold text-[var(--color-text-primary)] truncate">
                            {sample.name}
                          </h5>
                          <p className="text-[10px] text-[var(--color-text-muted)] line-clamp-1">
                            {sample.description}
                          </p>
                        </button>
                      );
                    })}
                  </div>
                </div>
              </div>
            </div>

            {/* Image Fit & Position Controls */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-3 border-t border-[var(--color-border-subtle)]">
              <div>
                <label className="text-xs font-semibold text-[var(--color-text-secondary)] block mb-1.5">
                  Background Fit
                </label>
                <div className="grid grid-cols-3 gap-1.5">
                  {(['cover', 'contain', 'fill'] as BackgroundFit[]).map((fit) => (
                    <button
                      key={fit}
                      type="button"
                      onClick={() => updateBackgroundSettings('customFit', fit)}
                      className={`py-1.5 px-2 rounded-xl text-xs capitalize border transition-all ${
                        backgroundSettings.customFit === fit
                          ? 'border-[var(--color-accent)] bg-[var(--color-surface-elevated)] text-[var(--color-accent)] font-semibold'
                          : 'border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-elevated)]'
                      }`}
                    >
                      {fit}
                    </button>
                  ))}
                </div>
              </div>

              <div>
                <label className="text-xs font-semibold text-[var(--color-text-secondary)] block mb-1.5">
                  Background Position
                </label>
                <div className="grid grid-cols-5 gap-1.5">
                  {(['center', 'top', 'bottom', 'left', 'right'] as BackgroundPosition[]).map((pos) => (
                    <button
                      key={pos}
                      type="button"
                      onClick={() => updateBackgroundSettings('customPosition', pos)}
                      className={`py-1.5 px-1 rounded-xl text-[11px] capitalize border transition-all ${
                        backgroundSettings.customPosition === pos
                          ? 'border-[var(--color-accent)] bg-[var(--color-surface-elevated)] text-[var(--color-accent)] font-semibold'
                          : 'border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-elevated)]'
                      }`}
                    >
                      {pos}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* TAB 3: GRADIENT */}
        {backgroundSettings.type === 'gradient' && (
          <div className="space-y-4">
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              {/* Primary Color */}
              <div className="p-3 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-2">
                <label className="text-xs font-semibold text-[var(--color-text-primary)] block">
                  Primary Color
                </label>
                <div className="flex items-center gap-2">
                  <input
                    type="color"
                    value={backgroundSettings.gradientPrimary}
                    onChange={(e) => updateBackgroundSettings('gradientPrimary', e.target.value)}
                    className="w-9 h-9 rounded-xl cursor-pointer border border-[var(--color-border-subtle)] bg-transparent p-0.5"
                  />
                  <input
                    type="text"
                    value={backgroundSettings.gradientPrimary}
                    onChange={(e) => updateBackgroundSettings('gradientPrimary', e.target.value)}
                    className="flex-1 px-2.5 py-1.5 rounded-xl border border-[var(--color-border-subtle)] bg-[var(--color-surface-elevated)] font-mono text-xs text-[var(--color-text-primary)]"
                  />
                </div>
              </div>

              {/* Secondary Color */}
              <div className="p-3 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-2">
                <label className="text-xs font-semibold text-[var(--color-text-primary)] block">
                  Secondary Color
                </label>
                <div className="flex items-center gap-2">
                  <input
                    type="color"
                    value={backgroundSettings.gradientSecondary}
                    onChange={(e) => updateBackgroundSettings('gradientSecondary', e.target.value)}
                    className="w-9 h-9 rounded-xl cursor-pointer border border-[var(--color-border-subtle)] bg-transparent p-0.5"
                  />
                  <input
                    type="text"
                    value={backgroundSettings.gradientSecondary}
                    onChange={(e) => updateBackgroundSettings('gradientSecondary', e.target.value)}
                    className="flex-1 px-2.5 py-1.5 rounded-xl border border-[var(--color-border-subtle)] bg-[var(--color-surface-elevated)] font-mono text-xs text-[var(--color-text-primary)]"
                  />
                </div>
              </div>

              {/* Optional 3rd Accent Color */}
              <div className="p-3 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-2">
                <div className="flex items-center justify-between">
                  <label className="text-xs font-semibold text-[var(--color-text-primary)]">
                    Tertiary Accent
                  </label>
                  <label className="flex items-center gap-1.5 text-[11px] text-[var(--color-text-muted)] cursor-pointer">
                    <input
                      type="checkbox"
                      checked={backgroundSettings.hasTertiaryGradient}
                      onChange={(e) => updateBackgroundSettings('hasTertiaryGradient', e.target.checked)}
                      className="rounded border-[var(--color-border-subtle)] text-[var(--color-accent)]"
                    />
                    <span>Enable</span>
                  </label>
                </div>
                <div className="flex items-center gap-2">
                  <input
                    type="color"
                    disabled={!backgroundSettings.hasTertiaryGradient}
                    value={backgroundSettings.gradientTertiary}
                    onChange={(e) => updateBackgroundSettings('gradientTertiary', e.target.value)}
                    className="w-9 h-9 rounded-xl cursor-pointer border border-[var(--color-border-subtle)] bg-transparent p-0.5 disabled:opacity-40"
                  />
                  <input
                    type="text"
                    disabled={!backgroundSettings.hasTertiaryGradient}
                    value={backgroundSettings.gradientTertiary}
                    onChange={(e) => updateBackgroundSettings('gradientTertiary', e.target.value)}
                    className="flex-1 px-2.5 py-1.5 rounded-xl border border-[var(--color-border-subtle)] bg-[var(--color-surface-elevated)] font-mono text-xs text-[var(--color-text-primary)] disabled:opacity-40"
                  />
                </div>
              </div>
            </div>

            {/* Direction Selector */}
            <div>
              <label className="text-xs font-semibold text-[var(--color-text-secondary)] block mb-1.5">
                Gradient Direction
              </label>
              <div className="grid grid-cols-2 sm:grid-cols-5 gap-2">
                {[
                  { id: 'to bottom right' as GradientDirection, label: '↘ 135° Diagonal' },
                  { id: 'to right' as GradientDirection, label: '→ 90° Horizontal' },
                  { id: 'to bottom' as GradientDirection, label: '↓ 180° Vertical' },
                  { id: 'to top right' as GradientDirection, label: '↗ 45° Diagonal' },
                  { id: 'radial' as GradientDirection, label: '◉ Radial Center' },
                ].map((dir) => (
                  <button
                    key={dir.id}
                    type="button"
                    onClick={() => updateBackgroundSettings('gradientDirection', dir.id)}
                    className={`py-2 px-2.5 rounded-xl text-xs border transition-all ${
                      backgroundSettings.gradientDirection === dir.id
                        ? 'border-[var(--color-accent)] bg-[var(--color-surface-elevated)] text-[var(--color-accent)] font-semibold'
                        : 'border-[var(--color-border-subtle)] text-[var(--color-text-secondary)] hover:bg-[var(--color-surface-elevated)]'
                    }`}
                  >
                    {dir.label}
                  </button>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* TAB 4: SOLID COLOR */}
        {backgroundSettings.type === 'solid' && (
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <label className="text-xs font-semibold text-[var(--color-text-secondary)] block">
                Choose Theme-Tuned Swatch or Custom Hex
              </label>
              <span className="text-[11px] font-mono text-[var(--color-text-muted)]">
                Active Theme: {mode.toUpperCase()}
              </span>
            </div>

            {/* Dark Atmosphere Swatches */}
            <div className="space-y-1.5">
              <div className="flex items-center gap-1.5 text-[11px] font-semibold text-[var(--color-text-secondary)]">
                <Moon className="w-3 h-3 text-sky-400" />
                <span>Dark Atmosphere Swatches</span>
                {mode === 'dark' && (
                  <span className="px-1 py-0.2 rounded bg-sky-500/15 text-sky-600 dark:text-sky-400 text-[9px] font-mono font-bold">
                    RECOMMENDED FOR DARK MODE
                  </span>
                )}
              </div>
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5">
                {SOLID_COLOR_PRESETS.slice(0, 4).map((swatch) => {
                  const isSelected = backgroundSettings.solidColor === swatch.color;
                  return (
                    <button
                      key={swatch.color}
                      type="button"
                      onClick={() => updateBackgroundSettings('solidColor', swatch.color)}
                      className={`p-3 rounded-xl border text-left transition-all flex items-center gap-2.5 ${
                        isSelected
                          ? 'border-[var(--color-accent)] ring-1 ring-[var(--color-accent)] bg-[var(--color-surface-elevated)] shadow-xs'
                          : 'border-[var(--color-border-subtle)] bg-[var(--color-surface-elevated)]/40 hover:bg-[var(--color-surface-elevated)]'
                      }`}
                    >
                      <span
                        className="w-5 h-5 rounded-full border border-black/10 shadow-xs flex-shrink-0"
                        style={{ backgroundColor: swatch.color }}
                      />
                      <div className="min-w-0">
                        <div className="text-xs font-semibold text-[var(--color-text-primary)] truncate">
                          {swatch.name}
                        </div>
                        <div className="text-[10px] font-mono text-[var(--color-text-muted)]">
                          {swatch.color}
                        </div>
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>

            {/* Light Atmosphere Swatches */}
            <div className="space-y-1.5 pt-1">
              <div className="flex items-center gap-1.5 text-[11px] font-semibold text-[var(--color-text-secondary)]">
                <Sun className="w-3 h-3 text-amber-500" />
                <span>Light Atmosphere Swatches</span>
                {mode === 'light' && (
                  <span className="px-1 py-0.2 rounded bg-amber-500/15 text-amber-600 dark:text-amber-400 text-[9px] font-mono font-bold">
                    RECOMMENDED FOR LIGHT MODE
                  </span>
                )}
              </div>
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5">
                {SOLID_COLOR_PRESETS.slice(4).map((swatch) => {
                  const isSelected = backgroundSettings.solidColor === swatch.color;
                  return (
                    <button
                      key={swatch.color}
                      type="button"
                      onClick={() => updateBackgroundSettings('solidColor', swatch.color)}
                      className={`p-3 rounded-xl border text-left transition-all flex items-center gap-2.5 ${
                        isSelected
                          ? 'border-[var(--color-accent)] ring-1 ring-[var(--color-accent)] bg-[var(--color-surface-elevated)] shadow-xs'
                          : 'border-[var(--color-border-subtle)] bg-[var(--color-surface-elevated)]/40 hover:bg-[var(--color-surface-elevated)]'
                      }`}
                    >
                      <span
                        className="w-5 h-5 rounded-full border border-black/10 shadow-xs flex-shrink-0"
                        style={{ backgroundColor: swatch.color }}
                      />
                      <div className="min-w-0">
                        <div className="text-xs font-semibold text-[var(--color-text-primary)] truncate">
                          {swatch.name}
                        </div>
                        <div className="text-[10px] font-mono text-[var(--color-text-muted)]">
                          {swatch.color}
                        </div>
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>

            {/* Custom Color Picker input */}
            <div className="flex items-center gap-2 pt-2">
              <input
                type="color"
                value={backgroundSettings.solidColor}
                onChange={(e) => updateBackgroundSettings('solidColor', e.target.value)}
                className="w-9 h-9 rounded-xl cursor-pointer border border-[var(--color-border-subtle)] bg-transparent p-0.5"
              />
              <input
                type="text"
                value={backgroundSettings.solidColor}
                onChange={(e) => updateBackgroundSettings('solidColor', e.target.value)}
                placeholder="#0b0f17"
                className="w-48 px-3 py-1.5 rounded-xl border border-[var(--color-border-subtle)] bg-[var(--color-surface-elevated)] font-mono text-xs text-[var(--color-text-primary)]"
              />
              <span className="text-xs text-[var(--color-text-muted)]">Custom Hex color</span>
            </div>
          </div>
        )}

        {/* 3B. Background Appearance Adjustments (Brightness, Saturation, Blur, Overlay) */}
        <div className="pt-4 border-t border-[var(--color-border-subtle)] space-y-4">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
              <Sliders className="w-3.5 h-3.5" />
              Background Visual Adjustments
            </span>
            <span className="text-[11px] text-[var(--color-text-muted)]">
              Fine-tune wallpaper before glass diffusion
            </span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {/* Brightness */}
            <div className="p-3 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-1.5">
              <div className="flex items-center justify-between text-xs">
                <span className="font-semibold text-[var(--color-text-primary)]">Background Brightness</span>
                <span className="font-mono text-[var(--color-accent)]">{backgroundSettings.brightness}%</span>
              </div>
              <input
                type="range"
                min="50"
                max="150"
                value={backgroundSettings.brightness}
                onChange={(e) => updateBackgroundSettings('brightness', Number(e.target.value))}
                className="w-full accent-[var(--color-accent)] cursor-pointer"
              />
              <div className="flex justify-between text-[10px] text-[var(--color-text-muted)]">
                <span>50% (Subdued)</span>
                <span>100% (Default)</span>
                <span>150% (Vibrant)</span>
              </div>
            </div>

            {/* Saturation */}
            <div className="p-3 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-1.5">
              <div className="flex items-center justify-between text-xs">
                <span className="font-semibold text-[var(--color-text-primary)]">Background Saturation</span>
                <span className="font-mono text-[var(--color-accent)]">{backgroundSettings.saturation}%</span>
              </div>
              <input
                type="range"
                min="0"
                max="150"
                value={backgroundSettings.saturation}
                onChange={(e) => updateBackgroundSettings('saturation', Number(e.target.value))}
                className="w-full accent-[var(--color-accent)] cursor-pointer"
              />
              <div className="flex justify-between text-[10px] text-[var(--color-text-muted)]">
                <span>0% (Monochrome)</span>
                <span>100% (Balanced)</span>
                <span>150% (Rich)</span>
              </div>
            </div>

            {/* Global Wallpaper Blur */}
            <div className="p-3 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-1.5">
              <div className="flex items-center justify-between text-xs">
                <span className="font-semibold text-[var(--color-text-primary)]">Wallpaper Pre-Blur</span>
                <span className="font-mono text-[var(--color-accent)]">{backgroundSettings.blur}px</span>
              </div>
              <input
                type="range"
                min="0"
                max="40"
                value={backgroundSettings.blur}
                onChange={(e) => updateBackgroundSettings('blur', Number(e.target.value))}
                className="w-full accent-[var(--color-accent)] cursor-pointer"
              />
              <div className="flex justify-between text-[10px] text-[var(--color-text-muted)]">
                <span>0px (Crisp)</span>
                <span>16px</span>
                <span>40px (Soft Focus)</span>
              </div>
            </div>

            {/* Scrim / Overlay Opacity (Readability Protection) */}
            <div className="p-3 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-1.5">
              <div className="flex items-center justify-between text-xs">
                <span className="font-semibold text-[var(--color-text-primary)]">Overlay / Scrim Opacity</span>
                <span className="font-mono text-[var(--color-accent)]">{backgroundSettings.overlayOpacity}%</span>
              </div>
              <input
                type="range"
                min="0"
                max="100"
                value={backgroundSettings.overlayOpacity}
                onChange={(e) => updateBackgroundSettings('overlayOpacity', Number(e.target.value))}
                className="w-full accent-[var(--color-accent)] cursor-pointer"
              />
              <div className="flex justify-between text-[10px] text-[var(--color-text-muted)]">
                <span>0% (Wallpaper Pure)</span>
                <span>25% (Optimal Readability)</span>
                <span>100% (Opaque)</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* 4. Glass Appearance Customization (Transparency, Blur, Tint, Saturation) */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-5">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
          <div>
            <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
              <Sparkles className="w-4 h-4" />
              Glass Appearance & Frosted Diffusion
            </h3>
            <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
              Control surface transparency, backdrop blur depth, and tint strength across all glass panels.
            </p>
          </div>

          <button
            type="button"
            onClick={resetGlassSettings}
            className="flex items-center gap-1.5 text-xs text-[var(--color-text-muted)] hover:text-[var(--color-accent)] transition-colors self-start sm:self-auto"
          >
            <RefreshCw className="w-3.5 h-3.5" />
            <span>Reset Glass Defaults</span>
          </button>
        </div>

        {/* Glass Presets (Reduced, Normal, Enhanced) */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          {glassPresetOptions.map((opt) => {
            const isSelected = glassSettings.preset === opt.id;
            return (
              <button
                key={opt.id}
                type="button"
                onClick={() => setGlassPreset(opt.id)}
                className={`p-3.5 rounded-2xl border text-left transition-all relative flex flex-col justify-between ${
                  isSelected
                    ? 'border-[var(--color-accent)] bg-[var(--color-surface-elevated)] ring-2 ring-[var(--color-accent)]/20 shadow-sm'
                    : 'border-[var(--color-border-subtle)] bg-[var(--color-surface-elevated)]/40 hover:bg-[var(--color-surface-elevated)]'
                }`}
              >
                {isSelected && (
                  <span className="absolute top-3 right-3 w-4 h-4 rounded-full bg-[var(--color-accent)] text-white flex items-center justify-center">
                    <Check className="w-2.5 h-2.5" />
                  </span>
                )}
                <div>
                  <h4 className="text-xs font-bold text-[var(--color-text-primary)]">
                    {opt.title}
                  </h4>
                  <p className="text-[11px] text-[var(--color-text-secondary)] mt-0.5 leading-relaxed">
                    {opt.description}
                  </p>
                </div>
                <div className="mt-3 pt-2 border-t border-[var(--color-border-subtle)] text-[10px] font-mono text-[var(--color-accent)] font-semibold">
                  {opt.metrics}
                </div>
              </button>
            );
          })}
        </div>

        {/* Precision Glass Sliders */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-2">
          {/* Transparency / Opacity */}
          <div className="p-3.5 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-1.5">
            <div className="flex items-center justify-between text-xs">
              <div>
                <span className="font-semibold text-[var(--color-text-primary)]">Glass Surface Opacity</span>
                <span className="block text-[10px] text-[var(--color-text-muted)]">Safe range: 40% to 90%</span>
              </div>
              <span className="font-mono text-[var(--color-accent)] font-bold">{glassSettings.transparency}%</span>
            </div>
            <input
              type="range"
              min="40"
              max="90"
              value={glassSettings.transparency}
              onChange={(e) => updateGlassSettings('transparency', Number(e.target.value))}
              className="w-full accent-[var(--color-accent)] cursor-pointer"
            />
            <div className="flex justify-between text-[10px] text-[var(--color-text-muted)]">
              <span>40% (Most Translucent)</span>
              <span>70% (Soft Glass Default)</span>
              <span>90% (Dense)</span>
            </div>
          </div>

          {/* Backdrop Blur */}
          <div className="p-3.5 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-1.5">
            <div className="flex items-center justify-between text-xs">
              <div>
                <span className="font-semibold text-[var(--color-text-primary)]">Frosted Backdrop Blur</span>
                <span className="block text-[10px] text-[var(--color-text-muted)]">Diffusion strength</span>
              </div>
              <span className="font-mono text-[var(--color-accent)] font-bold">{glassSettings.blur}px</span>
            </div>
            <input
              type="range"
              min="4"
              max="32"
              value={glassSettings.blur}
              onChange={(e) => updateGlassSettings('blur', Number(e.target.value))}
              className="w-full accent-[var(--color-accent)] cursor-pointer"
            />
            <div className="flex justify-between text-[10px] text-[var(--color-text-muted)]">
              <span>4px (Sharp)</span>
              <span>16px (Approved Soft Glass)</span>
              <span>32px (Ethereal)</span>
            </div>
          </div>

          {/* Tint Strength */}
          <div className="p-3.5 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-1.5">
            <div className="flex items-center justify-between text-xs">
              <div>
                <span className="font-semibold text-[var(--color-text-primary)]">Glass Tint Strength</span>
                <span className="block text-[10px] text-[var(--color-text-muted)]">Color absorption</span>
              </div>
              <span className="font-mono text-[var(--color-accent)] font-bold">{glassSettings.tintStrength}%</span>
            </div>
            <input
              type="range"
              min="20"
              max="100"
              value={glassSettings.tintStrength}
              onChange={(e) => updateGlassSettings('tintStrength', Number(e.target.value))}
              className="w-full accent-[var(--color-accent)] cursor-pointer"
            />
            <div className="flex justify-between text-[10px] text-[var(--color-text-muted)]">
              <span>20% (Whisper Tint)</span>
              <span>80% (Natural Balanced)</span>
              <span>100% (Solid Tint)</span>
            </div>
          </div>

          {/* Glass Saturation Boost */}
          <div className="p-3.5 rounded-2xl surface-raised border border-[var(--color-border-subtle)] space-y-1.5">
            <div className="flex items-center justify-between text-xs">
              <div>
                <span className="font-semibold text-[var(--color-text-primary)]">Through-Glass Saturation</span>
                <span className="block text-[10px] text-[var(--color-text-muted)]">Color richness through glass</span>
              </div>
              <span className="font-mono text-[var(--color-accent)] font-bold">{glassSettings.saturation}%</span>
            </div>
            <input
              type="range"
              min="100"
              max="150"
              value={glassSettings.saturation}
              onChange={(e) => updateGlassSettings('saturation', Number(e.target.value))}
              className="w-full accent-[var(--color-accent)] cursor-pointer"
            />
            <div className="flex justify-between text-[10px] text-[var(--color-text-muted)]">
              <span>100% (Neutral)</span>
              <span>110% (Subtle Glow)</span>
              <span>150% (Vivid Prism)</span>
            </div>
          </div>
        </div>
      </div>

      {/* 5. Accent Palette Preset & Custom Accent Color */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
          <div>
            <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
              <Sparkles className="w-4 h-4" />
              Accent Palette Preset (Solid Blue Themes)
            </h3>
            <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
              Pure solid tones with no gradients: Lighter shade in dark mode, darker shade in light mode.
            </p>
          </div>

          {/* Custom Accent Color Toggle */}
          <label className="flex items-center gap-2 text-xs font-medium text-[var(--color-text-secondary)] cursor-pointer self-start sm:self-auto">
            <input
              type="checkbox"
              checked={customAccentEnabled}
              onChange={(e) => handleCustomAccentToggle(e.target.checked)}
              className="rounded border-[var(--color-border-subtle)] text-[var(--color-accent)]"
            />
            <span>Custom Accent Color</span>
          </label>
        </div>

        {/* If Custom Accent is Enabled: Hex & Picker controls */}
        {customAccentEnabled && (
          <div className="p-4 rounded-2xl bg-[var(--color-surface-secondary)] border border-[var(--color-border-subtle)] flex items-center gap-3">
            <input
              type="color"
              value={accentHexInput}
              onChange={(e) => handleCustomAccentHexChange(e.target.value)}
              className="w-10 h-10 rounded-xl cursor-pointer border border-[var(--color-border-subtle)] bg-transparent p-0.5 flex-shrink-0"
            />
            <div className="flex-1 min-w-0">
              <label className="text-xs font-semibold text-[var(--color-text-primary)] block">
                Custom Accent Hex
              </label>
              <input
                type="text"
                value={accentHexInput}
                onChange={(e) => handleCustomAccentHexChange(e.target.value)}
                placeholder="#2563eb"
                className="mt-1 w-full max-w-xs px-3 py-1.5 rounded-xl border border-[var(--color-border-subtle)] bg-[var(--color-surface-elevated)] font-mono text-xs text-[var(--color-text-primary)]"
              />
            </div>
            <div className="text-[11px] font-mono text-[var(--color-text-muted)] hidden sm:block">
              Applied dynamically to all buttons, highlights, and glowing focus states.
            </div>
          </div>
        )}

        {/* Built-in Solid Blue Presets Grid */}
        <div className={`grid grid-cols-1 sm:grid-cols-2 gap-3.5 ${customAccentEnabled ? 'opacity-50 pointer-events-none' : ''}`}>
          {Object.entries(ACCENT_PRESETS).map(([id, preset]) => {
            const isSelected = accent === id && !customAccentEnabled;
            const displayColor = mode === 'dark' ? '#38bdf8' : (preset.primaryColor || '#1e40af');

            return (
              <button
                key={id}
                type="button"
                onClick={() => setAccent(id as AccentPresetId)}
                className={`p-4 rounded-2xl border text-left transition-all relative flex items-start gap-3.5 ${
                  isSelected
                    ? 'border-[var(--color-accent)] bg-[var(--color-surface-elevated)] ring-2 ring-[var(--color-accent)]/20 shadow-sm'
                    : 'border-[var(--color-border-subtle)] bg-[var(--color-surface-elevated)]/50 hover:bg-[var(--color-surface-elevated)] hover:border-[var(--color-accent)]/30'
                }`}
              >
                <div
                  className="w-8 h-8 rounded-full flex-shrink-0 mt-0.5 shadow-xs border border-white/20 flex items-center justify-center text-white"
                  style={{ backgroundColor: displayColor }}
                >
                  {isSelected && <Check className="w-4 h-4" />}
                </div>

                <div className="flex-1 min-w-0">
                  <div className="flex items-center justify-between">
                    <h4 className="text-sm font-bold text-[var(--color-text-primary)]">
                      {preset.name}
                    </h4>
                    <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[var(--color-surface-secondary)] text-[var(--color-text-muted)]">
                      {displayColor}
                    </span>
                  </div>
                  <p className="text-xs text-[var(--color-text-secondary)] mt-0.5 line-clamp-2">
                    {preset.description}
                  </p>
                </div>
              </button>
            );
          })}
        </div>
      </div>

      {/* 6. Effect Intensity (Reduced, Normal, Enhanced) */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
            <Layers className="w-4 h-4" />
            Tactile Effect Intensity
          </h3>
          <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-[var(--color-accent)]/10 text-[var(--color-accent)] font-semibold">
            Active: {effectIntensity.toUpperCase()}
          </span>
        </div>
        <p className="text-xs text-[var(--color-text-secondary)]">
          Controls neumorphic extrusion shadows, physical surface depths, and bevel lighting.
        </p>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-3.5">
          {intensityOptions.map((opt) => {
            const isSelected = effectIntensity === opt.id;
            return (
              <button
                key={opt.id}
                type="button"
                onClick={() => setEffectIntensity(opt.id)}
                className={`p-4 rounded-2xl border text-left transition-all relative flex flex-col justify-between ${
                  isSelected
                    ? 'border-[var(--color-accent)] bg-[var(--color-surface-elevated)] ring-2 ring-[var(--color-accent)]/20 shadow-sm'
                    : 'border-[var(--color-border-subtle)] bg-[var(--color-surface-elevated)]/40 hover:bg-[var(--color-surface-elevated)] hover:border-[var(--color-accent)]/30'
                }`}
              >
                {isSelected && (
                  <span className="absolute top-3 right-3 w-5 h-5 rounded-full bg-[var(--color-accent)] text-white flex items-center justify-center">
                    <Check className="w-3 h-3" />
                  </span>
                )}

                <div className="space-y-1.5">
                  <span className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)]">
                    {opt.title}
                  </span>
                  <h4 className="text-sm font-semibold text-[var(--color-text-primary)]">
                    {opt.description}
                  </h4>
                  <p className="text-xs text-[var(--color-text-secondary)] leading-relaxed pt-1">
                    {opt.detail}
                  </p>
                </div>
              </button>
            );
          })}
        </div>
      </div>

      {/* 7. Animations & Motion Dynamics */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
          <Zap className="w-4 h-4" />
          Animations & Motion Dynamics
        </h3>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
          {animationOptions.map((opt) => {
            const isSelected = animationPreference === opt.id;
            return (
              <button
                key={opt.id}
                type="button"
                onClick={() => setAnimationPreference(opt.id)}
                className={`p-3.5 rounded-2xl border text-left transition-all ${
                  isSelected
                    ? 'border-[var(--color-accent)] bg-[var(--color-surface-elevated)] ring-2 ring-[var(--color-accent)]/20 shadow-sm'
                    : 'border-[var(--color-border-subtle)] bg-[var(--color-surface-elevated)]/50 hover:bg-[var(--color-surface-elevated)]'
                }`}
              >
                <div className="flex items-center justify-between">
                  <h4 className="text-xs font-bold text-[var(--color-text-primary)]">
                    {opt.title}
                  </h4>
                  {isSelected && <Check className="w-3.5 h-3.5 text-[var(--color-accent)]" />}
                </div>
                <p className="text-xs text-[var(--color-text-secondary)] mt-1 leading-relaxed">
                  {opt.description}
                </p>
              </button>
            );
          })}
        </div>
      </div>

      {/* 8. Interface Density */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] space-y-4">
        <h3 className="text-xs font-bold uppercase tracking-wider font-mono text-[var(--color-accent)] flex items-center gap-1.5">
          <LayoutGrid className="w-4 h-4" />
          Interface Density
        </h3>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
          {densityOptions.map((opt) => {
            const isSelected = interfaceDensity === opt.id;
            return (
              <button
                key={opt.id}
                type="button"
                onClick={() => setInterfaceDensity(opt.id)}
                className={`p-4 rounded-2xl border text-left transition-all relative flex flex-col justify-between ${
                  isSelected
                    ? 'border-[var(--color-accent)] bg-[var(--color-surface-elevated)] ring-2 ring-[var(--color-accent)]/20 shadow-sm'
                    : 'border-[var(--color-border-subtle)] bg-[var(--color-surface-elevated)]/50 hover:bg-[var(--color-surface-elevated)] hover:border-[var(--color-accent)]/30'
                }`}
              >
                <div>
                  <div className="flex items-center justify-between">
                    <h4 className="text-sm font-bold text-[var(--color-text-primary)]">
                      {opt.title}
                    </h4>
                    {isSelected && <Check className="w-4 h-4 text-[var(--color-accent)]" />}
                  </div>
                  <p className="text-xs text-[var(--color-text-secondary)] mt-1 leading-relaxed">
                    {opt.description}
                  </p>
                </div>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
};
