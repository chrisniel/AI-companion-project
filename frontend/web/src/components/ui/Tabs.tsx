import React from 'react';
import { motion } from 'motion/react';
import { TabItem } from '../../types';

export interface TabsProps {
  items: TabItem[];
  activeId: string;
  onChange: (id: string) => void;
  size?: 'sm' | 'md' | 'lg';
  fullWidth?: boolean;
  className?: string;
}

export const Tabs: React.FC<TabsProps> = ({
  items,
  activeId,
  onChange,
  size = 'md',
  fullWidth = false,
  className = '',
}) => {
  const sizeClasses = {
    sm: 'p-1 text-xs gap-1',
    md: 'p-1.5 text-sm gap-1.5',
    lg: 'p-2 text-base gap-2',
  }[size];

  const itemPadding = {
    sm: 'px-2.5 py-1',
    md: 'px-3.5 py-1.5',
    lg: 'px-4.5 py-2',
  }[size];

  return (
    <div
      role="tablist"
      className={`inline-flex items-center rounded-2xl surface-recessed border border-[var(--color-border-subtle)] select-none ${sizeClasses} ${
        fullWidth ? 'w-full flex' : ''
      } ${className}`}
    >
      {items.map((tab) => {
        const isActive = tab.id === activeId;
        return (
          <button
            key={tab.id}
            role="tab"
            aria-selected={isActive}
            disabled={tab.disabled}
            onClick={() => !tab.disabled && onChange(tab.id)}
            className={`relative inline-flex items-center justify-center font-medium rounded-xl transition-colors duration-150 focus-ring ${itemPadding} ${
              fullWidth ? 'flex-1' : ''
            } ${
              tab.disabled
                ? 'opacity-40 cursor-not-allowed'
                : 'cursor-pointer'
            } ${
              isActive
                ? 'text-[var(--color-text-primary)] font-semibold'
                : 'text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)]'
            }`}
          >
            {/* Animated Active Raised Surface */}
            {isActive && (
              <motion.div
                layoutId="active-tab-indicator"
                className="absolute inset-0 rounded-xl surface-raised border border-[var(--color-border-subtle)] shadow-sm -z-0"
                transition={{ type: 'spring', bounce: 0.18, duration: 0.3 }}
              />
            )}

            <span className="relative z-10 flex items-center gap-2">
              {tab.icon && <span className="flex-shrink-0">{tab.icon}</span>}
              <span>{tab.label}</span>
              {tab.badge !== undefined && (
                <span
                  className={`text-[10px] px-1.5 py-0.2 rounded-full font-bold ${
                    isActive
                      ? 'bg-accent-gradient text-white'
                      : 'bg-[var(--color-surface-secondary)] text-[var(--color-text-muted)]'
                  }`}
                >
                  {tab.badge}
                </span>
              )}
            </span>
          </button>
        );
      })}
    </div>
  );
};
