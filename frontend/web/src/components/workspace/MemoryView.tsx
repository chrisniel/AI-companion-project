import React, { useState, useMemo, useCallback, useEffect } from 'react';
import {
  Brain,
  Plus,
  Layers,
  CheckCircle2,
  User,
  HeartHandshake,
  BookOpen,
  ArrowUpDown,
  Loader2,
  AlertCircle,
  WifiOff,
} from 'lucide-react';
import { Badge } from '../ui/Badge';
import { SearchInput } from '../ui/SearchInput';
import { NeumorphicButton } from '../ui/NeumorphicButton';
import { MemoryEntry, MemoryCategory } from '../../types';
import { MemoryItemCard } from './memory/MemoryItemCard';
import { MemoryEditorModal } from './memory/MemoryEditorModal';
import { MemoryDeleteConfirmModal } from './memory/MemoryDeleteConfirmModal';
import { useTheme } from '../../context/ThemeContext';
import { useBackend } from '../../context/BackendContext';
import {
  listMemories,
  createMemory,
  updateMemory,
  deleteMemory,
  MemoryOut,
} from '../../services/api/memoryApi';

function mapMemoryOutToEntry(out: MemoryOut): MemoryEntry {
  let cat: MemoryCategory = 'Fact';
  const lowerCat = out.category?.toLowerCase() || '';
  if (lowerCat === 'preference') cat = 'Preference';
  else if (lowerCat === 'profile' || lowerCat === 'context') cat = 'Profile';
  else cat = 'Fact';

  return {
    id: out.id,
    content: out.content,
    category: cat,
    source: out.source_type ? `${out.source_type.charAt(0).toUpperCase()}${out.source_type.slice(1)}` : 'Manual',
    confidence: 1.0,
    importance: typeof out.importance === 'number' ? out.importance : 1.0,
    lastUpdated: new Date(out.created_at).toLocaleDateString([], {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    }),
  };
}

type SortOption = 'recent' | 'importance' | 'category';

export const MemoryView: React.FC = () => {
  const { mode } = useTheme();
  const { isOnline } = useBackend();
  const [memories, setMemories] = useState<MemoryEntry[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<'All' | 'Fact' | 'Preference' | 'Profile'>('All');
  const [sortBy, setSortBy] = useState<SortOption>('recent');

  // Modal states
  const [isEditorOpen, setIsEditorOpen] = useState(false);
  const [memoryToEdit, setMemoryToEdit] = useState<MemoryEntry | null>(null);
  const [memoryToDelete, setMemoryToDelete] = useState<MemoryEntry | null>(null);

  // Toast feedback
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3000);
  };

  const loadLiveMemories = useCallback(async () => {
    setIsLoading(true);
    setLoadError(null);
    try {
      const res = await listMemories();
      const mapped = (res.items || []).map(mapMemoryOutToEntry);
      setMemories(mapped);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to connect to memory service';
      setLoadError(msg);
      setMemories([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    loadLiveMemories();
  }, [loadLiveMemories]);

  // Category counts calculation
  const categoryCounts = useMemo(() => {
    const counts: Record<string, number> = {
      All: memories.length,
      Fact: 0,
      Preference: 0,
      Profile: 0,
    };
    memories.forEach((m) => {
      if (counts[m.category] !== undefined) {
        counts[m.category]++;
      }
    });
    return counts;
  }, [memories]);

  // Categories list with icons
  const categoriesList: { id: 'All' | 'Fact' | 'Preference' | 'Profile'; label: string; icon: React.ReactNode }[] = [
    { id: 'All', label: 'All Records', icon: <Layers className="w-3.5 h-3.5" /> },
    { id: 'Fact', label: 'Fact', icon: <BookOpen className="w-3.5 h-3.5" /> },
    { id: 'Preference', label: 'Preference', icon: <HeartHandshake className="w-3.5 h-3.5" /> },
    { id: 'Profile', label: 'Profile / Context', icon: <User className="w-3.5 h-3.5" /> },
  ];

  // Filtering and sorting
  const filteredMemories = useMemo(() => {
    return memories
      .filter((mem) => {
        // Category filter
        if (selectedCategory !== 'All' && mem.category !== selectedCategory) return false;

        // Search filter
        if (searchQuery.trim()) {
          const q = searchQuery.toLowerCase();
          const matchContent = mem.content.toLowerCase().includes(q);
          const matchSource = mem.source.toLowerCase().includes(q);
          const matchCat = mem.category.toLowerCase().includes(q);
          return matchContent || matchSource || matchCat;
        }

        return true;
      })
      .sort((a, b) => {
        if (sortBy === 'importance') {
          return (b.importance ?? 1.0) - (a.importance ?? 1.0);
        }
        if (sortBy === 'category') {
          return a.category.localeCompare(b.category);
        }
        // Default: most recent first (ID/created comparison)
        return b.id.localeCompare(a.id);
      });
  }, [memories, selectedCategory, searchQuery, sortBy]);

  // Handlers for live memory controls
  const handleEdit = (memory: MemoryEntry) => {
    setMemoryToEdit(memory);
    setIsEditorOpen(true);
  };

  const handleCreateNew = () => {
    setMemoryToEdit(null);
    setIsEditorOpen(true);
  };

  const handleSaveMemory = async (data: Partial<MemoryEntry>) => {
    try {
      let apiCat: 'fact' | 'preference' | 'context' = 'fact';
      if (data.category === 'Preference') apiCat = 'preference';
      else if (data.category === 'Profile') apiCat = 'context';
      const importance = typeof data.importance === 'number' ? data.importance : 1.0;

      if (data.id) {
        await updateMemory(data.id, {
          content: data.content,
          category: apiCat,
          importance,
        });
        showToast('Memory record updated in SQLite store.');
      } else {
        await createMemory(data.content || '', apiCat, importance);
        showToast('New memory record saved to SQLite store.');
      }
      setIsEditorOpen(false);
      setMemoryToEdit(null);
      await loadLiveMemories();
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to save memory record.';
      showToast(`Error: ${msg}`);
    }
  };

  const handleDeletePrompt = (id: string) => {
    const mem = memories.find((m) => m.id === id);
    if (mem) {
      setMemoryToDelete(mem);
    }
  };

  const handleConfirmDelete = async () => {
    if (memoryToDelete) {
      try {
        await deleteMemory(memoryToDelete.id);
        showToast('Memory deleted from SQLite store.');
        setMemoryToDelete(null);
        await loadLiveMemories();
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : 'Failed to delete memory.';
        showToast(`Error: ${msg}`);
      }
    }
  };

  return (
    <div id="memory-view" className="space-y-6 pb-12">
      {/* Top Header Card */}
      <div className="p-5 sm:p-6 rounded-3xl surface-raised border border-[var(--color-border-subtle)] flex flex-col md:flex-row md:items-center justify-between gap-4 shadow-sm">
        <div className="flex items-center gap-3.5">
          <div className="w-11 h-11 rounded-2xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm flex-shrink-0">
            <Brain className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2 flex-wrap">
              <h1 className="text-xl font-bold text-[var(--color-text-primary)]">
                Long-Term Memory & SQLite FTS5 Index
              </h1>
              <Badge variant="accent" size="sm">
                SQLite FTS5
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">
              Searchable memory records across facts, preferences, and profile context stored in local SQLite database.
            </p>
          </div>
        </div>

        {/* Action button */}
        <div className="flex items-center gap-2">
          <NeumorphicButton
            variant="primary"
            size="md"
            onClick={handleCreateNew}
            icon={<Plus className="w-4 h-4" />}
          >
            Add Memory
          </NeumorphicButton>
        </div>
      </div>

      {/* Stats Summary Strip */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)]">
          <span className="text-[10px] font-mono uppercase tracking-wider text-[var(--color-text-muted)] block">
            Total Records
          </span>
          <span className="text-lg font-bold text-[var(--color-text-primary)] mt-0.5 block">
            {memories.length}
          </span>
        </div>

        <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)]">
          <span className="text-[10px] font-mono uppercase tracking-wider text-[var(--color-text-muted)] block">
            Search Engine
          </span>
          <span className="text-lg font-bold text-[var(--color-accent)] mt-0.5 block">
            SQLite FTS5
          </span>
        </div>

        <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)]">
          <span className="text-[10px] font-mono uppercase tracking-wider text-[var(--color-text-muted)] block">
            Storage Engine
          </span>
          <span className="text-lg font-bold text-[var(--color-text-primary)] mt-0.5 block truncate">
            aiosqlite (Local DB)
          </span>
        </div>

        <div className="p-3.5 rounded-2xl surface-base border border-[var(--color-border-subtle)]">
          <span className="text-[10px] font-mono uppercase tracking-wider text-[var(--color-text-muted)] block">
            Active Schema
          </span>
          <span className="text-lg font-bold text-emerald-400 mt-0.5 block truncate">
            Fact • Pref • Context
          </span>
        </div>
      </div>

      {/* Search and Filter Controls */}
      <div className="p-4 sm:p-5 rounded-3xl surface-base border border-[var(--color-border-subtle)] space-y-4">
        {/* Row 1: Search Bar + Sort Option */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
          <div className="flex-1 max-w-lg">
            <SearchInput
              value={searchQuery}
              onChangeValue={setSearchQuery}
              placeholder="Search across memory content, source, category..."
              sizeVariant="md"
            />
          </div>

          <div className="flex items-center gap-2">
            {/* Sort Selector */}
            <div className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-2xl surface-recessed border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-muted)]">
              <ArrowUpDown className="w-3.5 h-3.5" />
              <select
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value as SortOption)}
                style={{ colorScheme: mode }}
                className="bg-transparent text-[var(--color-text-primary)] font-medium focus:outline-none cursor-pointer"
              >
                <option value="recent" className={mode === 'dark' ? 'bg-[#121824] text-slate-100' : 'bg-white text-slate-900'}>
                  Recently Updated
                </option>
                <option value="importance" className={mode === 'dark' ? 'bg-[#121824] text-slate-100' : 'bg-white text-slate-900'}>
                  Highest Importance
                </option>
                <option value="category" className={mode === 'dark' ? 'bg-[#121824] text-slate-100' : 'bg-white text-slate-900'}>
                  Category
                </option>
              </select>
            </div>
          </div>
        </div>

        {/* Row 2: Searchable Memory Categories Pills */}
        <div className="pt-2 border-t border-[var(--color-border-subtle)]">
          <div className="flex items-center gap-1.5 overflow-x-auto pb-1 no-scrollbar">
            {categoriesList.map((cat) => {
              const isSelected = selectedCategory === cat.id;
              const count = categoryCounts[cat.id] || 0;
              return (
                <button
                  key={cat.id}
                  onClick={() => setSelectedCategory(cat.id)}
                  className={`px-3 py-1.5 rounded-xl text-xs font-semibold flex items-center gap-2 whitespace-nowrap transition-all duration-150 cursor-pointer ${
                    isSelected
                      ? 'surface-raised text-[var(--color-text-primary)] border border-[var(--color-accent)]/60 shadow-xs'
                      : 'surface-base text-[var(--color-text-secondary)] border border-[var(--color-border-subtle)] hover:text-[var(--color-text-primary)]'
                  }`}
                >
                  <span className={isSelected ? 'text-[var(--color-accent)]' : 'text-[var(--color-text-muted)]'}>
                    {cat.icon}
                  </span>
                  <span>{cat.label}</span>
                  <span
                    className={`text-[10px] px-1.5 py-0.2 rounded-full font-mono ${
                      isSelected
                        ? 'bg-[var(--color-accent)]/20 text-[var(--color-accent)]'
                        : 'surface-recessed text-[var(--color-text-muted)]'
                    }`}
                  >
                    {count}
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      </div>

      {/* Feedback Toast */}
      {toastMessage && (
        <div className="px-4 py-2.5 rounded-2xl surface-recessed border border-emerald-500/30 text-xs text-emerald-400 flex items-center gap-2 animate-fadeIn">
          <CheckCircle2 className="w-4 h-4" />
          <span>{toastMessage}</span>
        </div>
      )}

      {/* Memory Entries List (Highly readable interface without heavy neumorphism) */}
      <div className="space-y-3.5">
        {!isOnline && (
          <div className="p-3.5 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-between gap-3 text-xs text-amber-300">
            <div className="flex items-center gap-2">
              <WifiOff className="w-4 h-4 text-amber-400 flex-shrink-0" />
              <span>
                <strong>Runtime Offline: </strong> Memory query and SQLite FTS5 updates are paused until Local AI Runtime reconnects.
              </span>
            </div>
            <Badge variant="warning" size="sm" className="font-mono text-[10px]">
              Offline
            </Badge>
          </div>
        )}

        {loadError && (
          <div className="p-4 rounded-2xl bg-rose-500/10 border border-rose-500/30 flex items-center justify-between gap-3 text-xs text-rose-300">
            <div className="flex items-center gap-2">
              <AlertCircle className="w-4 h-4 text-rose-400 flex-shrink-0" />
              <span>{loadError}</span>
            </div>
            <NeumorphicButton size="xs" variant="secondary" onClick={loadLiveMemories}>
              Retry
            </NeumorphicButton>
          </div>
        )}

        {isLoading ? (
          <div className="p-12 rounded-3xl surface-base border border-[var(--color-border-subtle)] text-center space-y-3">
            <Loader2 className="w-8 h-8 animate-spin text-[var(--color-accent)] mx-auto opacity-75" />
            <h3 className="text-sm font-bold text-[var(--color-text-primary)]">
              Querying Local AI Runtime...
            </h3>
            <p className="text-xs text-[var(--color-text-secondary)]">
              Fetching memory records from SQLite FTS5 store.
            </p>
          </div>
        ) : filteredMemories.length > 0 ? (
          filteredMemories.map((mem) => (
            <MemoryItemCard
              key={mem.id}
              memory={mem}
              onEdit={handleEdit}
              onDelete={handleDeletePrompt}
            />
          ))
        ) : (
          <div className="p-10 rounded-3xl surface-base border border-[var(--color-border-subtle)] text-center space-y-3">
            <Brain className="w-8 h-8 text-[var(--color-text-muted)] mx-auto opacity-50" />
            <h3 className="text-sm font-bold text-[var(--color-text-primary)]">
              {memories.length === 0 ? 'No memory records yet' : 'No matching memories found'}
            </h3>
            <p className="text-xs text-[var(--color-text-secondary)] max-w-sm mx-auto">
              {memories.length === 0
                ? "No memories have been stored in the SQLite FTS5 database yet. Click 'Add Memory' above to record a user fact or preference."
                : `No memory records matched category "${selectedCategory}" with query "${searchQuery}".`}
            </p>
            {memories.length > 0 && (
              <NeumorphicButton
                size="sm"
                variant="secondary"
                onClick={() => {
                  setSearchQuery('');
                  setSelectedCategory('All');
                }}
              >
                Reset Filters
              </NeumorphicButton>
            )}
          </div>
        )}
      </div>

      {/* Modals for Edit / Create and Delete Confirmation */}
      <MemoryEditorModal
        isOpen={isEditorOpen}
        onClose={() => {
          setIsEditorOpen(false);
          setMemoryToEdit(null);
        }}
        onSave={handleSaveMemory}
        memoryToEdit={memoryToEdit}
      />

      <MemoryDeleteConfirmModal
        isOpen={!!memoryToDelete}
        onClose={() => setMemoryToDelete(null)}
        onConfirm={handleConfirmDelete}
        memory={memoryToDelete}
      />
    </div>
  );
};
