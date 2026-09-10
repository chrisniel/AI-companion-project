import React from 'react';
import {
  Home,
  Bot,
  CheckSquare,
  Calendar,
  Activity,
  Brain,
  Cpu,
  Sparkles,
  HardDrive,
  Terminal,
  Settings,
  Layers,
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { Badge } from '../ui/Badge';
import { StatusIndicator } from '../ui/StatusIndicator';

export interface NavItem {
  id: string;
  label: string;
  icon: React.ReactNode;
  badge?: string;
  category?: 'MAIN' | 'AI' | 'SYSTEM';
}

export const NAV_ITEMS: NavItem[] = [
  // MAIN
  {
    id: 'home',
    label: 'Home',
    icon: <Home className="w-5 h-5" />,
    category: 'MAIN',
  },
  {
    id: 'assistant',
    label: 'Assistant',
    icon: <Bot className="w-5 h-5" />,
    badge: 'Neural',
    category: 'MAIN',
  },
  {
    id: 'tasks',
    label: 'Tasks',
    icon: <CheckSquare className="w-5 h-5" />,
    badge: '3',
    category: 'MAIN',
  },
  {
    id: 'schedule',
    label: 'Schedule',
    icon: <Calendar className="w-5 h-5" />,
    category: 'MAIN',
  },
  {
    id: 'health',
    label: 'Health',
    icon: <Activity className="w-5 h-5" />,
    category: 'MAIN',
  },
  {
    id: 'memory',
    label: 'Memory',
    icon: <Brain className="w-5 h-5" />,
    category: 'MAIN',
  },

  // AI
  {
    id: 'models',
    label: 'Models',
    icon: <Cpu className="w-5 h-5" />,
    badge: 'Loaded',
    category: 'AI',
  },
  {
    id: 'characters',
    label: 'Characters',
    icon: <Sparkles className="w-5 h-5" />,
    category: 'AI',
  },

  // SYSTEM
  {
    id: 'devices',
    label: 'Devices',
    icon: <HardDrive className="w-5 h-5" />,
    category: 'SYSTEM',
  },
  {
    id: 'logs',
    label: 'Logs',
    icon: <Terminal className="w-5 h-5" />,
    badge: 'Live',
    category: 'SYSTEM',
  },
  {
    id: 'settings',
    label: 'Settings',
    icon: <Settings className="w-5 h-5" />,
    category: 'SYSTEM',
  },
  {
    id: 'states',
    label: 'States',
    icon: <Layers className="w-5 h-5" />,
    badge: '27',
    category: 'SYSTEM',
  },
];


export interface SidebarProps {
  activeSection: string;
  onSelectSection: (id: string) => void;
  collapsed: boolean;
  onToggleCollapse?: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({
  activeSection,
  onSelectSection,
  collapsed,
}) => {
  return (
    <aside
      className={`relative flex flex-col justify-between h-full glass-bar border-r border-[var(--color-surface-glass-border)] transition-[width] duration-300 ease-in-out z-30 select-none ${
        collapsed ? 'w-14' : 'w-64 sm:w-72'
      }`}
    >
      {/* Navigation Items */}
      <div
        className={`flex-1 overflow-y-auto overflow-x-hidden space-y-1.5 ${
          collapsed ? 'py-3 px-1.5 flex flex-col items-center' : 'p-2.5'
        }`}
      >
        {NAV_ITEMS.map((item, idx) => {
          const isActive = item.id === activeSection;
          const isFirstOfCategory =
            idx === 0 || NAV_ITEMS[idx - 1].category !== item.category;

          return (
            <React.Fragment key={item.id}>
              {/* Category Header */}
              {isFirstOfCategory && item.category && (
                <div
                  className={`overflow-hidden transition-all duration-200 ${
                    collapsed ? 'h-0 opacity-0 my-0 px-0' : 'h-6 opacity-100 mt-2.5 mb-1 px-3'
                  }`}
                >
                  <span className="text-[10px] font-semibold tracking-wider uppercase text-[var(--color-text-muted)] whitespace-nowrap select-none">
                    {item.category}
                  </span>
                </div>
              )}

              {/* Navigation Menu Button */}
              <button
                id={`nav-item-${item.id}`}
                type="button"
                onClick={() => onSelectSection(item.id)}
                title={collapsed ? item.label : undefined}
                className={`h-10 flex items-center rounded-xl text-sm font-medium relative group cursor-pointer nav-menu-item select-none ${
                  collapsed
                    ? 'w-10 justify-center p-0 mx-auto'
                    : 'w-full px-3 justify-start gap-3'
                } ${
                  isActive ? 'nav-menu-item-active' : 'nav-menu-item-inactive'
                }`}
              >
                {/* Fixed-Size Stable Icon Container: Centered perfectly */}
                <div className="w-5 h-5 flex items-center justify-center flex-shrink-0">
                  <span
                    className={`transition-colors duration-150 flex items-center justify-center ${
                      isActive
                        ? 'text-[var(--color-accent)]'
                        : 'text-[var(--color-text-muted)] group-hover:text-[var(--color-text-primary)]'
                    }`}
                  >
                    {item.icon}
                  </span>
                </div>

                {/* Text Label & Badge: Only rendered when expanded so it cannot affect icon centering */}
                {!collapsed && (
                  <div className="flex items-center justify-between min-w-0 flex-1 overflow-hidden">
                    <span className="truncate text-left whitespace-nowrap text-sm">
                      {item.label}
                    </span>

                    {item.badge && (
                      <div className="flex-shrink-0 ml-2">
                        <Badge
                          variant={isActive ? 'accent' : 'default'}
                          size="sm"
                        >
                          {item.badge}
                        </Badge>
                      </div>
                    )}
                  </div>
                )}
              </button>
            </React.Fragment>
          );
        })}
      </div>

      {/* Bottom Core Engine Status */}
      <div
        className={`border-t border-[var(--color-surface-glass-border)] ${
          collapsed ? 'p-2 flex justify-center items-center' : 'p-2.5'
        }`}
      >
        <AnimatePresence mode="wait">
          {!collapsed ? (
            <motion.div
              key="expanded-status"
              initial={{ opacity: 0, y: 4 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 4 }}
              transition={{ duration: 0.2 }}
              className="p-2.5 rounded-xl surface-recessed border border-[var(--color-border-subtle)] flex flex-col gap-1.5 overflow-hidden"
            >
              <div className="flex items-center justify-between">
                <span className="text-[10px] uppercase font-bold tracking-wider text-[var(--color-text-muted)]">
                  Local Backend
                </span>
                <StatusIndicator status="online" size="sm" showLabel={false} />
              </div>
              <p className="text-xs font-medium text-[var(--color-text-primary)] truncate">
                Python FastAPI API Ready
              </p>
              <span className="text-[10px] text-[var(--color-text-secondary)] font-mono">
                Port: 8000 (Loopback)
              </span>
            </motion.div>
          ) : (
            <motion.div
              key="collapsed-status"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.2 }}
              className="flex justify-center py-2 cursor-default"
              title="Local Backend: Online (Port 8000)"
            >
              <StatusIndicator status="online" size="sm" showLabel={false} />
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </aside>
  );
};
