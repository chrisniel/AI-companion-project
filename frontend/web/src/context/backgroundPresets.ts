import type React from 'react';
import {
  BuiltinBackgroundId,
  BuiltinPresetInfo,
  BackgroundSettings,
} from '../types';

export const BUILTIN_BACKGROUND_PRESETS: Record<BuiltinBackgroundId, BuiltinPresetInfo> = {
  // LIGHT PRESETS
  aurora_mist: {
    id: 'aurora_mist',
    name: 'Aurora Mist',
    category: 'light',
    description: 'Pearl white, pale lavender, cool cyan, and subtle violet mist',
    colors: ['#f4f7fb', '#ece8f7', '#e0f2fe', '#ede9fe'],
    css: 'radial-gradient(at 15% 15%, rgba(224, 242, 254, 0.85) 0px, transparent 50%), radial-gradient(at 85% 20%, rgba(237, 233, 254, 0.8) 0px, transparent 50%), radial-gradient(at 50% 80%, rgba(236, 232, 247, 0.9) 0px, transparent 55%), radial-gradient(at 90% 85%, rgba(224, 242, 254, 0.7) 0px, transparent 50%), linear-gradient(135deg, #f8fafc 0%, #eaf0f8 100%)',
  },
  pearl_bloom: {
    id: 'pearl_bloom',
    name: 'Pearl Bloom',
    category: 'light',
    description: 'Luminous pearl with soft blush rose and whisper silver notes',
    colors: ['#fafbfc', '#fce7f3', '#f1f5f9', '#f3e8ff'],
    css: 'radial-gradient(at 20% 25%, rgba(252, 231, 243, 0.75) 0px, transparent 48%), radial-gradient(at 75% 15%, rgba(243, 232, 255, 0.7) 0px, transparent 50%), radial-gradient(at 40% 85%, rgba(241, 245, 249, 0.85) 0px, transparent 50%), linear-gradient(145deg, #ffffff 0%, #edf2f9 100%)',
  },
  cloud_glass: {
    id: 'cloud_glass',
    name: 'Cloud Glass',
    category: 'light',
    description: 'Clean airy sky blue, pale cyan, and frosted white atmosphere',
    colors: ['#f0f9ff', '#e0f2fe', '#cffafe', '#f8fafc'],
    css: 'radial-gradient(at 10% 20%, rgba(207, 250, 254, 0.8) 0px, transparent 50%), radial-gradient(at 80% 30%, rgba(224, 242, 254, 0.85) 0px, transparent 50%), radial-gradient(at 60% 85%, rgba(240, 249, 255, 0.9) 0px, transparent 50%), linear-gradient(135deg, #f1f5f9 0%, #e2e8f0 100%)',
  },
  lavender_flow: {
    id: 'lavender_flow',
    name: 'Lavender Flow',
    category: 'light',
    description: 'Soft lavender mist with cool violet and delicate pearl layers',
    colors: ['#f5f3ff', '#ede9fe', '#ddd6fe', '#f8fafc'],
    css: 'radial-gradient(at 25% 20%, rgba(221, 214, 254, 0.75) 0px, transparent 50%), radial-gradient(at 85% 35%, rgba(237, 233, 254, 0.8) 0px, transparent 50%), radial-gradient(at 35% 80%, rgba(245, 243, 255, 0.85) 0px, transparent 50%), linear-gradient(135deg, #f8fafc 0%, #ece8f7 100%)',
  },

  // DARK PRESETS
  midnight_aurora: {
    id: 'midnight_aurora',
    name: 'Midnight Aurora',
    category: 'dark',
    description: 'Charcoal and dark navy with restrained cyan and indigo highlights',
    colors: ['#0b0f17', '#0f172a', '#0e7490', '#1e1b4b'],
    css: 'radial-gradient(at 15% 15%, rgba(14, 116, 144, 0.28) 0px, transparent 50%), radial-gradient(at 85% 20%, rgba(30, 27, 75, 0.5) 0px, transparent 55%), radial-gradient(at 50% 80%, rgba(15, 23, 42, 0.8) 0px, transparent 50%), radial-gradient(at 80% 85%, rgba(6, 78, 59, 0.2) 0px, transparent 45%), linear-gradient(135deg, #070a0f 0%, #0d131f 100%)',
  },
  graphite_waves: {
    id: 'graphite_waves',
    name: 'Graphite Waves',
    category: 'dark',
    description: 'Deep graphite, textured charcoal, and subtle steel blue accents',
    colors: ['#090d14', '#0f172a', '#1e293b', '#334155'],
    css: 'radial-gradient(at 20% 25%, rgba(30, 41, 59, 0.45) 0px, transparent 50%), radial-gradient(at 75% 20%, rgba(15, 23, 42, 0.6) 0px, transparent 50%), radial-gradient(at 40% 80%, rgba(51, 65, 85, 0.3) 0px, transparent 50%), linear-gradient(145deg, #05070a 0%, #0f1520 100%)',
  },
  deep_violet: {
    id: 'deep_violet',
    name: 'Deep Violet',
    category: 'dark',
    description: 'Obsidian navy infused with dark amethyst and subtle plum glow',
    colors: ['#0a0814', '#170f2c', '#2e1065', '#4c1d95'],
    css: 'radial-gradient(at 20% 20%, rgba(76, 29, 149, 0.32) 0px, transparent 50%), radial-gradient(at 80% 30%, rgba(46, 16, 101, 0.4) 0px, transparent 55%), radial-gradient(at 45% 85%, rgba(23, 15, 44, 0.7) 0px, transparent 50%), linear-gradient(135deg, #06040b 0%, #0d0b17 100%)',
  },
  blue_ember: {
    id: 'blue_ember',
    name: 'Blue Ember',
    category: 'dark',
    description: 'Midnight slate and muted cobalt with restrained neon cyan depth',
    colors: ['#070d18', '#0f1d36', '#1e3a8a', '#0284c7'],
    css: 'radial-gradient(at 15% 25%, rgba(2, 132, 199, 0.28) 0px, transparent 50%), radial-gradient(at 80% 20%, rgba(30, 58, 138, 0.45) 0px, transparent 50%), radial-gradient(at 50% 85%, rgba(15, 29, 54, 0.7) 0px, transparent 50%), linear-gradient(135deg, #040810 0%, #091222 100%)',
  },
};

// Pre-filtered lists for theme separation
export const LIGHT_BACKGROUND_PRESETS = Object.values(BUILTIN_BACKGROUND_PRESETS).filter(
  (p) => p.category === 'light'
);
export const DARK_BACKGROUND_PRESETS = Object.values(BUILTIN_BACKGROUND_PRESETS).filter(
  (p) => p.category === 'dark'
);

// Curated sample wallpapers for instant custom testing without uploading
export const SAMPLE_CUSTOM_IMAGES = [
  {
    id: 'sample-1',
    name: 'Architectural Frosted Glass',
    description: 'Curved glass facade with delicate translucent refraction lines',
    url: 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600" viewBox="0 0 800 600"><defs><linearGradient id="g1" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" stop-color="%231e293b"/><stop offset="50%" stop-color="%230f172a"/><stop offset="100%" stop-color="%23020617"/></linearGradient><linearGradient id="g2" x1="0%" y1="100%" x2="100%" y2="0%"><stop offset="0%" stop-color="%230284c7" stop-opacity="0.3"/><stop offset="100%" stop-color="%236366f1" stop-opacity="0.15"/></linearGradient></defs><rect width="800" height="600" fill="url(%23g1)"/><path d="M0,300 C200,200 400,400 800,250 L800,600 L0,600 Z" fill="url(%23g2)"/><circle cx="650" cy="150" r="180" fill="%2338bdf8" opacity="0.1" filter="blur(40px)"/><circle cx="150" cy="450" r="220" fill="%234f46e5" opacity="0.12" filter="blur(50px)"/></svg>',
  },
  {
    id: 'sample-2',
    name: 'Fluid Cyan Waves',
    description: 'Organic flowing wave contours with restrained sky highlights',
    url: 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600" viewBox="0 0 800 600"><defs><linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" stop-color="%230f172a"/><stop offset="100%" stop-color="%23030712"/></linearGradient><linearGradient id="cyanW" x1="0%" y1="0%" x2="100%" y2="0%"><stop offset="0%" stop-color="%2306b6d4" stop-opacity="0.25"/><stop offset="50%" stop-color="%233b82f6" stop-opacity="0.2"/><stop offset="100%" stop-color="%2306b6d4" stop-opacity="0.1"/></linearGradient></defs><rect width="800" height="600" fill="url(%23bg)"/><path d="M-50,200 Q200,100 450,280 T850,220 L850,650 L-50,650 Z" fill="url(%23cyanW)"/><path d="M-50,380 Q300,260 500,420 T850,360 L850,650 L-50,650 Z" fill="%230284c7" opacity="0.12"/></svg>',
  },
  {
    id: 'sample-3',
    name: 'Cosmic Mist',
    description: 'Subdued interstellar gradient dust with dark obsidian backdrop',
    url: 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600" viewBox="0 0 800 600"><defs><radialGradient id="neb1" cx="30%" cy="35%" r="60%"><stop offset="0%" stop-color="%234338ca" stop-opacity="0.3"/><stop offset="60%" stop-color="%231e1b4b" stop-opacity="0.1"/><stop offset="100%" stop-color="transparent"/></radialGradient><radialGradient id="neb2" cx="75%" cy="65%" r="50%"><stop offset="0%" stop-color="%230369a1" stop-opacity="0.25"/><stop offset="70%" stop-color="transparent"/></radialGradient></defs><rect width="800" height="600" fill="%23080b12"/><rect width="800" height="600" fill="url(%23neb1)"/><rect width="800" height="600" fill="url(%23neb2)"/></svg>',
  },
];

// Solid color swatches
export const SOLID_COLOR_PRESETS = [
  { name: 'Midnight Charcoal', color: '#0b0f17' },
  { name: 'Deep Slate', color: '#0f172a' },
  { name: 'Steel Navy', color: '#131e33' },
  { name: 'Obsidian Violet', color: '#120d24' },
  { name: 'Crisp Cloud (Light)', color: '#eaf0f8' },
  { name: 'Pale Frost (Light)', color: '#f1f5f9' },
  { name: 'Whisper Sky (Light)', color: '#e0f2fe' },
  { name: 'Soft Pearl (Light)', color: '#f8fafc' },
];

/**
 * Computes the React CSS style for the global wallpaper element based on settings.
 */
export function computeWallpaperStyle(settings: BackgroundSettings, isDark: boolean): React.CSSProperties {
  switch (settings.type) {
    case 'builtin': {
      // Pick the preset corresponding to the current theme mode to avoid mismatched contrast
      const targetPresetId = isDark
        ? (settings.darkPresetId || (BUILTIN_BACKGROUND_PRESETS[settings.builtinId]?.category === 'dark' ? settings.builtinId : 'midnight_aurora'))
        : (settings.lightPresetId || (BUILTIN_BACKGROUND_PRESETS[settings.builtinId]?.category === 'light' ? settings.builtinId : 'aurora_mist'));

      const preset = BUILTIN_BACKGROUND_PRESETS[targetPresetId] ||
        (isDark ? BUILTIN_BACKGROUND_PRESETS.midnight_aurora : BUILTIN_BACKGROUND_PRESETS.aurora_mist);

      return {
        backgroundImage: preset.css,
        backgroundSize: 'cover',
        backgroundPosition: 'center',
        backgroundRepeat: 'no-repeat',
      };
    }

    case 'custom': {
      if (!settings.customImageUrl) {
        // Fallback to default preset if no image chosen yet
        const defaultPreset = isDark
          ? BUILTIN_BACKGROUND_PRESETS.midnight_aurora
          : BUILTIN_BACKGROUND_PRESETS.aurora_mist;
        return {
          backgroundImage: defaultPreset.css,
          backgroundSize: 'cover',
          backgroundPosition: 'center',
          backgroundRepeat: 'no-repeat',
        };
      }

      const sizeMap: Record<string, string> = {
        cover: 'cover',
        contain: 'contain',
        fill: '100% 100%',
      };

      return {
        backgroundImage: `url("${settings.customImageUrl}")`,
        backgroundSize: sizeMap[settings.customFit] || 'cover',
        backgroundPosition: settings.customPosition || 'center',
        backgroundRepeat: settings.customFit === 'contain' ? 'repeat' : 'no-repeat',
      };
    }

    case 'gradient': {
      const dir = settings.gradientDirection;
      const stops = settings.hasTertiaryGradient && settings.gradientTertiary
        ? `${settings.gradientPrimary}, ${settings.gradientSecondary}, ${settings.gradientTertiary}`
        : `${settings.gradientPrimary}, ${settings.gradientSecondary}`;

      const gradientStr = dir === 'radial'
        ? `radial-gradient(circle at 50% 50%, ${stops})`
        : `linear-gradient(${dir}, ${stops})`;

      return {
        backgroundImage: gradientStr,
        backgroundSize: 'cover',
        backgroundPosition: 'center',
        backgroundRepeat: 'no-repeat',
      };
    }

    case 'solid': {
      return {
        backgroundColor: settings.solidColor || (isDark ? '#0b0f17' : '#eaf0f8'),
        backgroundImage: 'none',
      };
    }

    default:
      return {
        backgroundImage: BUILTIN_BACKGROUND_PRESETS.aurora_mist.css,
        backgroundSize: 'cover',
        backgroundPosition: 'center',
        backgroundRepeat: 'no-repeat',
      };
  }
}
