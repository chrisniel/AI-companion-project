import React from 'react';
import { useTheme } from '../../context/ThemeContext';
import { computeWallpaperStyle } from '../../context/backgroundPresets';

export const GlobalBackground: React.FC = () => {
  const { mode, backgroundSettings } = useTheme();
  const isDark = mode === 'dark';

  const wallpaperStyle = computeWallpaperStyle(backgroundSettings, isDark);

  return (
    <div
      className="fixed inset-0 pointer-events-none z-0 overflow-hidden select-none"
      id="app-global-wallpaper-layer"
      aria-hidden="true"
    >
      {/* 1. Base Wallpaper Surface (Preset / Custom Image / Gradient / Solid) */}
      <div
        className="absolute inset-0 transition-all duration-300 ease-out"
        style={{
          ...wallpaperStyle,
          filter: `brightness(${backgroundSettings.brightness}%) saturate(${backgroundSettings.saturation}%) blur(${backgroundSettings.blur}px)`,
          // Scale slightly when blur is enabled to prevent canvas edge clipping/vignetting
          transform: backgroundSettings.blur > 0 ? 'scale(1.04)' : 'none',
        }}
      />

      {/* 2. Environmental Scrim / Overlay Layer for Contrast & Readability */}
      <div
        className="absolute inset-0 transition-opacity duration-300 ease-out"
        style={{
          backgroundColor: isDark ? '#0b0f17' : '#eaf0f8',
          opacity: backgroundSettings.overlayOpacity / 100,
        }}
      />
    </div>
  );
};
