import React, { createContext, useContext, useEffect, useState } from 'react';
import {
  AccentPreset,
  AccentPresetId,
  ThemeMode,
  ThemePreference,
  EffectIntensity,
  InterfaceDensity,
  AnimationPreference,
  BackgroundSettings,
  BuiltinBackgroundId,
  GlassSettings,
  GlassPreset,
} from '../types';

export const ACCENT_PRESETS: Record<AccentPresetId, AccentPreset> = {
  aurora: {
    id: 'aurora',
    name: 'Ocean Blue',
    description: 'Solid Blue Theme (Light shade in dark mode, darker shade in light mode)',
    gradient: '#1e40af',
    glow: 'rgba(30, 64, 175, 0.25)',
    primaryColor: '#1e40af',
    secondaryColor: '#2563eb',
  },
  electric: {
    id: 'electric',
    name: 'Cobalt Blue',
    description: 'Solid Cobalt Blue',
    gradient: '#1d4ed8',
    glow: 'rgba(29, 78, 216, 0.25)',
    primaryColor: '#1d4ed8',
    secondaryColor: '#3b82f6',
  },
  emerald: {
    id: 'emerald',
    name: 'Deep Navy',
    description: 'Solid Deep Navy Blue',
    gradient: '#1e3a8a',
    glow: 'rgba(30, 58, 138, 0.25)',
    primaryColor: '#1e3a8a',
    secondaryColor: '#1d4ed8',
  },
  amethyst: {
    id: 'amethyst',
    name: 'Royal Blue',
    description: 'Solid Royal Blue',
    gradient: '#2563eb',
    glow: 'rgba(37, 99, 235, 0.25)',
    primaryColor: '#2563eb',
    secondaryColor: '#60a5fa',
  },
};

export const DEFAULT_BACKGROUND_SETTINGS: BackgroundSettings = {
  type: 'builtin',
  builtinId: 'midnight_aurora',
  lightPresetId: 'aurora_mist',
  darkPresetId: 'midnight_aurora',
  customImageUrl: null,
  customFit: 'cover',
  customPosition: 'center',
  gradientPrimary: '#0f172a',
  gradientSecondary: '#1e293b',
  gradientTertiary: '#0284c7',
  hasTertiaryGradient: true,
  gradientDirection: 'to bottom right',
  solidColor: '#0b0f17',
  brightness: 100,
  saturation: 100,
  blur: 0,
  overlayOpacity: 25,
};

export const DEFAULT_GLASS_SETTINGS: GlassSettings = {
  preset: 'normal',
  transparency: 70, // 0.70 surface opacity (clean Soft Glass)
  blur: 16, // 16px backdrop blur
  tintStrength: 80, // 80% surface tint
  saturation: 110, // 110% background color boost through glass
};

interface ThemeContextType {
  mode: ThemeMode;
  themePreference: ThemePreference;
  setThemePreference: (pref: ThemePreference) => void;
  toggleTheme: () => void;
  setMode: (mode: ThemeMode) => void;
  accent: AccentPresetId;
  setAccent: (accent: AccentPresetId) => void;
  currentAccentPreset: AccentPreset;
  customAccentColor: string | null;
  setCustomAccentColor: (color: string | null) => void;
  effectIntensity: EffectIntensity;
  setEffectIntensity: (intensity: EffectIntensity) => void;
  interfaceDensity: InterfaceDensity;
  setInterfaceDensity: (density: InterfaceDensity) => void;
  animationPreference: AnimationPreference;
  setAnimationPreference: (anim: AnimationPreference) => void;
  // Background & Glass State (Theme-Separated Presets)
  backgroundSettings: BackgroundSettings;
  updateBackgroundSettings: <K extends keyof BackgroundSettings>(key: K, value: BackgroundSettings[K]) => void;
  setThemePreset: (theme: 'light' | 'dark', presetId: BuiltinBackgroundId) => void;
  resetBackgroundSettings: () => void;
  glassSettings: GlassSettings;
  updateGlassSettings: <K extends keyof GlassSettings>(key: K, value: GlassSettings[K]) => void;
  setGlassPreset: (preset: GlassPreset) => void;
  resetGlassSettings: () => void;
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

export const ThemeProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [themePreference, setThemePreferenceState] = useState<ThemePreference>(() => {
    const saved = localStorage.getItem('localai-theme-pref') as ThemePreference;
    if (saved === 'light' || saved === 'dark' || saved === 'system') return saved;
    return 'system';
  });

  const [mode, setModeState] = useState<ThemeMode>(() => {
    const savedPref = localStorage.getItem('localai-theme-pref');
    if (savedPref === 'light') return 'light';
    if (savedPref === 'dark') return 'dark';
    const savedMode = localStorage.getItem('localai-theme-mode');
    if (savedMode === 'light' || savedMode === 'dark') return savedMode;
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  });

  const [accent, setAccent] = useState<AccentPresetId>(() => {
    const saved = localStorage.getItem('localai-accent-preset') as AccentPresetId;
    return ACCENT_PRESETS[saved] ? saved : 'aurora';
  });

  const [customAccentColor, setCustomAccentColorState] = useState<string | null>(() => {
    return localStorage.getItem('localai-custom-accent-color');
  });

  const [effectIntensity, setEffectIntensityState] = useState<EffectIntensity>(() => {
    const saved = localStorage.getItem('localai-effect-intensity') as EffectIntensity;
    if (saved === 'reduced' || saved === 'normal' || saved === 'enhanced') return saved;
    return 'normal';
  });

  const [interfaceDensity, setInterfaceDensityState] = useState<InterfaceDensity>(() => {
    const saved = localStorage.getItem('localai-density') as InterfaceDensity;
    if (saved === 'comfortable' || saved === 'compact') return saved;
    return 'comfortable';
  });

  const [animationPreference, setAnimationPreferenceState] = useState<AnimationPreference>(() => {
    const saved = localStorage.getItem('localai-animations') as AnimationPreference;
    if (saved === 'fluid' || saved === 'reduced' || saved === 'none') return saved;
    return 'fluid';
  });

  // Background Settings with persistence
  const [backgroundSettings, setBackgroundSettings] = useState<BackgroundSettings>(() => {
    try {
      const saved = localStorage.getItem('localai-background-settings');
      if (saved) {
        return { ...DEFAULT_BACKGROUND_SETTINGS, ...JSON.parse(saved) };
      }
    } catch {
      // Fallback
    }
    return {
      ...DEFAULT_BACKGROUND_SETTINGS,
      builtinId: mode === 'dark' ? 'midnight_aurora' : 'aurora_mist',
      overlayOpacity: mode === 'dark' ? 25 : 20,
    };
  });

  // Glass Settings with persistence
  const [glassSettings, setGlassSettings] = useState<GlassSettings>(() => {
    try {
      const saved = localStorage.getItem('localai-glass-settings');
      if (saved) {
        return { ...DEFAULT_GLASS_SETTINGS, ...JSON.parse(saved) };
      }
    } catch {
      // Fallback
    }
    return DEFAULT_GLASS_SETTINGS;
  });

  const updateBackgroundSettings = <K extends keyof BackgroundSettings>(key: K, value: BackgroundSettings[K]) => {
    setBackgroundSettings((prev) => {
      const updated = { ...prev, [key]: value };
      // Keep theme-specific preset pointers in sync
      if (key === 'builtinId') {
        const valStr = String(value);
        if (['aurora_mist', 'pearl_bloom', 'cloud_glass', 'lavender_flow'].includes(valStr)) {
          updated.lightPresetId = value as BuiltinBackgroundId;
        } else {
          updated.darkPresetId = value as BuiltinBackgroundId;
        }
      }
      localStorage.setItem('localai-background-settings', JSON.stringify(updated));
      return updated;
    });
  };

  const setThemePreset = (themeCategory: 'light' | 'dark', presetId: BuiltinBackgroundId) => {
    setBackgroundSettings((prev) => {
      const isCurrentTheme = mode === themeCategory;
      const updated: BackgroundSettings = {
        ...prev,
        type: 'builtin',
        lightPresetId: themeCategory === 'light' ? presetId : (prev.lightPresetId || 'aurora_mist'),
        darkPresetId: themeCategory === 'dark' ? presetId : (prev.darkPresetId || 'midnight_aurora'),
        builtinId: isCurrentTheme ? presetId : prev.builtinId,
      };
      localStorage.setItem('localai-background-settings', JSON.stringify(updated));
      return updated;
    });
  };

  // Synchronize builtin preset when mode switches between light and dark
  useEffect(() => {
    if (backgroundSettings.type === 'builtin') {
      const targetPreset = mode === 'dark'
        ? (backgroundSettings.darkPresetId || 'midnight_aurora')
        : (backgroundSettings.lightPresetId || 'aurora_mist');
      if (backgroundSettings.builtinId !== targetPreset) {
        setBackgroundSettings((prev) => {
          const updated = { ...prev, builtinId: targetPreset };
          localStorage.setItem('localai-background-settings', JSON.stringify(updated));
          return updated;
        });
      }
    }
  }, [mode]);

  const resetBackgroundSettings = () => {
    const initial: BackgroundSettings = {
      ...DEFAULT_BACKGROUND_SETTINGS,
      builtinId: mode === 'dark' ? 'midnight_aurora' : 'aurora_mist',
      lightPresetId: 'aurora_mist',
      darkPresetId: 'midnight_aurora',
      overlayOpacity: mode === 'dark' ? 25 : 20,
    };
    setBackgroundSettings(initial);
    localStorage.setItem('localai-background-settings', JSON.stringify(initial));
  };

  const updateGlassSettings = <K extends keyof GlassSettings>(key: K, value: GlassSettings[K]) => {
    setGlassSettings((prev) => {
      const updated = { ...prev, [key]: value, preset: 'custom' as GlassPreset };
      localStorage.setItem('localai-glass-settings', JSON.stringify(updated));
      return updated;
    });
  };

  const setGlassPreset = (preset: GlassPreset) => {
    let presetValues: Partial<GlassSettings> = {};
    if (preset === 'reduced') {
      presetValues = {
        preset: 'reduced',
        transparency: 85,
        blur: 6,
        tintStrength: 90,
        saturation: 100,
      };
    } else if (preset === 'normal') {
      presetValues = {
        preset: 'normal',
        transparency: 70,
        blur: 16,
        tintStrength: 80,
        saturation: 110,
      };
    } else if (preset === 'enhanced') {
      presetValues = {
        preset: 'enhanced',
        transparency: 58,
        blur: 24,
        tintStrength: 70,
        saturation: 120,
      };
    } else {
      presetValues = { preset: 'custom' };
    }

    setGlassSettings((prev) => {
      const updated = { ...prev, ...presetValues };
      localStorage.setItem('localai-glass-settings', JSON.stringify(updated));
      return updated;
    });
  };

  const resetGlassSettings = () => {
    setGlassSettings(DEFAULT_GLASS_SETTINGS);
    localStorage.setItem('localai-glass-settings', JSON.stringify(DEFAULT_GLASS_SETTINGS));
  };

  const setCustomAccentColor = (color: string | null) => {
    setCustomAccentColorState(color);
    if (color) {
      localStorage.setItem('localai-custom-accent-color', color);
    } else {
      localStorage.removeItem('localai-custom-accent-color');
    }
  };

  // Watch system color scheme changes when themePreference is 'system'
  useEffect(() => {
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    const handler = (e: MediaQueryListEvent) => {
      if (themePreference === 'system') {
        setModeState(e.matches ? 'dark' : 'light');
      }
    };
    mediaQuery.addEventListener('change', handler);
    return () => mediaQuery.removeEventListener('change', handler);
  }, [themePreference]);

  const setThemePreference = (pref: ThemePreference) => {
    setThemePreferenceState(pref);
    localStorage.setItem('localai-theme-pref', pref);
    if (pref === 'system') {
      const isDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
      setModeState(isDark ? 'dark' : 'light');
    } else {
      setModeState(pref);
    }
  };

  const setMode = (newMode: ThemeMode) => {
    setThemePreference(newMode);
  };

  const toggleTheme = () => {
    setThemePreference(mode === 'light' ? 'dark' : 'light');
  };

  const setEffectIntensity = (intensity: EffectIntensity) => {
    setEffectIntensityState(intensity);
    localStorage.setItem('localai-effect-intensity', intensity);
    // Align glass blur if user changes effect intensity
    if (intensity === 'reduced') {
      setGlassPreset('reduced');
    } else if (intensity === 'normal') {
      setGlassPreset('normal');
    } else if (intensity === 'enhanced') {
      setGlassPreset('enhanced');
    }
  };

  const setInterfaceDensity = (density: InterfaceDensity) => {
    setInterfaceDensityState(density);
    localStorage.setItem('localai-density', density);
  };

  const setAnimationPreference = (anim: AnimationPreference) => {
    setAnimationPreferenceState(anim);
    localStorage.setItem('localai-animations', anim);
  };

  // Sync DOM attributes for effect intensity, density, animations
  useEffect(() => {
    const root = document.documentElement;
    root.setAttribute('data-effect-intensity', effectIntensity);
    root.setAttribute('data-density', interfaceDensity);
    root.setAttribute('data-animations', animationPreference);
  }, [effectIntensity, interfaceDensity, animationPreference]);

  // Mode synchronization
  useEffect(() => {
    localStorage.setItem('localai-theme-mode', mode);
    const root = document.documentElement;
    root.style.colorScheme = mode;
    if (mode === 'dark') {
      root.classList.add('dark');
    } else {
      root.classList.remove('dark');
    }
  }, [mode]);

  // Accent and custom color synchronization
  useEffect(() => {
    localStorage.setItem('localai-accent-preset', accent);
    const preset = ACCENT_PRESETS[accent];
    const root = document.documentElement;

    if (customAccentColor) {
      // User has custom accent color active
      root.style.setProperty('--accent-gradient', customAccentColor);
      root.style.setProperty('--color-accent', customAccentColor);
      root.style.setProperty('--color-accent-secondary', customAccentColor);
      root.style.setProperty('--accent-glow', `${customAccentColor}40`);
    } else if (mode === 'dark') {
      root.style.setProperty('--accent-gradient', '#38bdf8');
      root.style.setProperty('--color-accent', '#38bdf8');
      root.style.setProperty('--color-accent-secondary', '#60a5fa');
      root.style.setProperty('--accent-glow', 'rgba(56, 189, 248, 0.25)');
    } else {
      const lightColor = preset.primaryColor || '#1e40af';
      root.style.setProperty('--accent-gradient', lightColor);
      root.style.setProperty('--accent-glow', preset.glow || 'rgba(30, 64, 175, 0.22)');
      root.style.setProperty('--color-accent', lightColor);
      root.style.setProperty('--color-accent-secondary', preset.secondaryColor || '#2563eb');
    }
  }, [accent, mode, customAccentColor]);

  // Glass & Background CSS Variables synchronization
  useEffect(() => {
    const root = document.documentElement;
    const opacity = glassSettings.transparency / 100;
    const blurPx = glassSettings.blur;
    const sat = glassSettings.saturation;

    // Glass variables
    root.style.setProperty('--glass-blur', `${blurPx}px`);
    root.style.setProperty('--glass-opacity', `${opacity}`);
    root.style.setProperty('--glass-tint', `${glassSettings.tintStrength / 100}`);
    root.style.setProperty('--glass-saturation', `${sat}%`);

    // Surface Glass color computation
    if (mode === 'dark') {
      root.style.setProperty('--color-surface-glass', `rgba(18, 24, 36, ${opacity})`);
      root.style.setProperty('--color-surface-glass-border', `rgba(255, 255, 255, ${Math.max(0.06, opacity * 0.14)})`);
    } else {
      root.style.setProperty('--color-surface-glass', `rgba(255, 255, 255, ${opacity})`);
      root.style.setProperty('--color-surface-glass-border', `rgba(255, 255, 255, ${Math.min(1, opacity + 0.15)})`);
    }

    // Background filter and overlay variables
    root.style.setProperty('--background-brightness', `${backgroundSettings.brightness}%`);
    root.style.setProperty('--background-saturation', `${backgroundSettings.saturation}%`);
    root.style.setProperty('--background-blur', `${backgroundSettings.blur}px`);
    root.style.setProperty('--background-overlay-opacity', `${backgroundSettings.overlayOpacity / 100}`);
  }, [glassSettings, backgroundSettings, mode]);

  return (
    <ThemeContext.Provider
      value={{
        mode,
        themePreference,
        setThemePreference,
        toggleTheme,
        setMode,
        accent,
        setAccent,
        currentAccentPreset: ACCENT_PRESETS[accent],
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
      }}
    >
      {children}
    </ThemeContext.Provider>
  );
};

export const useTheme = (): ThemeContextType => {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
};


