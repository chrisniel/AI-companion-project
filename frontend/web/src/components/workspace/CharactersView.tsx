import React, { useState, useRef } from 'react';
import {
  Sparkles,
  Plus,
  Bot,
  Filter,
  Layers,
  Search,
  Check,
  Cpu,
  Volume2,
  Info,
} from 'lucide-react';
import { CharacterConfig, PersonalityStyle } from '../../types';
import { mockCharacters } from '../../mock/characterData';
import { Badge } from '../ui/Badge';
import { NeumorphicButton } from '../ui/NeumorphicButton';
import { CharacterCard } from './characters/CharacterCard';
import { CharacterPreview } from './characters/CharacterPreview';
import { CharacterEditor } from './characters/CharacterEditor';
import { AddCharacterModal } from './characters/AddCharacterModal';

export interface CharactersViewProps {
  activeCharacterId?: string;
  onSelectCharacter?: (id: string) => void;
}

export const CharactersView: React.FC<CharactersViewProps> = ({
  activeCharacterId = 'p-1',
  onSelectCharacter,
}) => {
  // State for character repository
  const [characters, setCharacters] = useState<CharacterConfig[]>(mockCharacters);
  const [previewCharacterId, setPreviewCharacterId] = useState<string>(activeCharacterId);
  const [editingCharacterId, setEditingCharacterId] = useState<string | null>(activeCharacterId);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedStyleFilter, setSelectedStyleFilter] = useState<string>('all');
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);

  // References for smooth scrolling
  const editorRef = useRef<HTMLDivElement>(null);
  const previewRef = useRef<HTMLDivElement>(null);

  // Resolved active and preview character objects
  const activeCharacter = characters.find((c) => c.id === activeCharacterId) || characters[0];
  const previewCharacter = characters.find((c) => c.id === previewCharacterId) || activeCharacter;
  const editingCharacter = characters.find((c) => c.id === editingCharacterId) || activeCharacter;

  // Filtered characters for library
  const filteredCharacters = characters.filter((char) => {
    const matchesSearch =
      char.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      char.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      char.voice.toLowerCase().includes(searchQuery.toLowerCase()) ||
      char.personality.toLowerCase().includes(searchQuery.toLowerCase());

    const matchesStyle =
      selectedStyleFilter === 'all' || char.personalityStyle === selectedStyleFilter;

    return matchesSearch && matchesStyle;
  });

  // Handlers
  const handleSelectActive = (id: string) => {
    onSelectCharacter?.(id);
    setPreviewCharacterId(id);
  };

  const handleSelectForEdit = (char: CharacterConfig) => {
    setEditingCharacterId(char.id);
    setTimeout(() => {
      editorRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }, 50);
  };

  const handleSelectForPreview = (char: CharacterConfig) => {
    setPreviewCharacterId(char.id);
    setTimeout(() => {
      previewRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }, 50);
  };

  const handleSaveEditedCharacter = (updated: CharacterConfig) => {
    setCharacters((prev) =>
      prev.map((c) => (c.id === updated.id ? { ...c, ...updated } : c))
    );
  };

  const handleAddNewCharacter = (newChar: CharacterConfig) => {
    setCharacters((prev) => [newChar, ...prev]);
    setPreviewCharacterId(newChar.id);
    setEditingCharacterId(newChar.id);
  };

  return (
    <div id="characters-and-persona-view" className="space-y-6 pb-12">
      {/* View Header */}
      <div className="p-5 rounded-3xl surface-raised border border-[var(--color-border-subtle)] flex flex-col md:flex-row md:items-center justify-between gap-4 shadow-sm">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-2xl bg-accent-gradient flex items-center justify-center text-white glow-accent-sm flex-shrink-0">
            <Sparkles className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h1 className="text-lg font-bold text-[var(--color-text-primary)]">
                Characters & Persona System
              </h1>
              <Badge variant="accent" size="sm">
                Modular Personas
              </Badge>
            </div>
            <p className="text-xs text-[var(--color-text-secondary)]">
              Characters are modular configuration profiles. Decoupled semantic avatar states and neural voice routing.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2.5 flex-wrap">
          <div className="px-3 py-1 rounded-full surface-recessed border border-[var(--color-border-subtle)] text-xs font-mono text-[var(--color-text-secondary)] flex items-center gap-1.5">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
            <span>Active: <strong className="text-[var(--color-text-primary)] font-bold">{activeCharacter.name}</strong></span>
          </div>

          <NeumorphicButton
            size="sm"
            variant="primary"
            onClick={() => setIsAddModalOpen(true)}
            icon={<Plus className="w-3.5 h-3.5" />}
          >
            Add Character
          </NeumorphicButton>
        </div>
      </div>

      {/* Important Architecture Decoupling Callout */}
      <div className="px-4 py-3 rounded-2xl surface-base border border-[var(--color-border-subtle)] flex items-center justify-between gap-3 text-xs text-[var(--color-text-muted)]">
        <div className="flex items-center gap-2.5">
          <Info className="w-4 h-4 text-[var(--color-accent)] flex-shrink-0" />
          <span>
            <strong className="text-[var(--color-text-primary)] font-semibold">Decoupled Configuration: </strong>
            The core application is not hardcoded to a single character. Backend states emit abstract semantic signals, while the presentation layer handles procedural rendering.
          </span>
        </div>
        <span className="hidden sm:inline-block text-[10px] font-mono text-[var(--color-text-muted)]">
          {characters.length} Profiles Configured
        </span>
      </div>

      {/* Interactive Avatar State Preview Stage */}
      <div ref={previewRef}>
        <CharacterPreview character={previewCharacter} />
      </div>

      {/* Character Library Section */}
      <div className="space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 px-1">
          <div>
            <h2 className="text-base font-bold text-[var(--color-text-primary)] flex items-center gap-2">
              <span>Character Library</span>
              <span className="text-xs font-normal font-mono text-[var(--color-text-muted)]">
                ({filteredCharacters.length} Available)
              </span>
            </h2>
            <p className="text-xs text-[var(--color-text-muted)]">
              Select any character card to make it active or inspect its semantic visual state.
            </p>
          </div>

          {/* Search & Style Filters */}
          <div className="flex items-center gap-2 flex-wrap">
            {/* Search input */}
            <div className="relative">
              <Search className="w-3.5 h-3.5 absolute left-2.5 top-1/2 -translate-y-1/2 text-[var(--color-text-muted)]" />
              <input
                type="text"
                placeholder="Search characters or voices..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-8 pr-3 py-1.5 rounded-xl surface-base border border-[var(--color-border-subtle)] text-xs text-[var(--color-text-primary)] focus:outline-none focus:border-[var(--color-accent)] w-48 sm:w-56"
              />
            </div>

            {/* Personality Style Filter Chips */}
            <div className="flex items-center gap-1 surface-base p-1 rounded-xl border border-[var(--color-border-subtle)]">
              {(['all', 'analytical', 'balanced', 'warm_friendly', 'concise'] as const).map((style) => (
                <button
                  key={style}
                  type="button"
                  onClick={() => setSelectedStyleFilter(style)}
                  className={`px-2.5 py-1 rounded-lg text-[11px] font-medium transition-all capitalize ${
                    selectedStyleFilter === style
                      ? 'surface-raised text-[var(--color-text-primary)] shadow-xs font-bold'
                      : 'text-[var(--color-text-muted)] hover:text-[var(--color-text-secondary)]'
                  }`}
                >
                  {style === 'warm_friendly' ? 'Warm' : style}
                </button>
              ))}
            </div>
          </div>
        </div>

        {/* Cards Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filteredCharacters.map((character) => (
            <CharacterCard
              key={character.id}
              character={character}
              isActive={character.id === activeCharacterId}
              isSelectedForPreview={character.id === previewCharacterId}
              onSelectActive={handleSelectActive}
              onSelectForEdit={handleSelectForEdit}
              onSelectForPreview={handleSelectForPreview}
            />
          ))}
        </div>
      </div>

      {/* Character Editor Section */}
      <div ref={editorRef} className="space-y-3 pt-4 border-t border-[var(--color-border-subtle)]">
        <div className="flex items-center justify-between px-1">
          <div>
            <h2 className="text-base font-bold text-[var(--color-text-primary)] flex items-center gap-2">
              <span>Editing: {editingCharacter.name}</span>
              <Badge variant="neutral" size="sm">
                {editingCharacter.title}
              </Badge>
            </h2>
            <p className="text-xs text-[var(--color-text-muted)]">
              Adjust neural voice weights, behavioral dynamics, and avatar display surfaces.
            </p>
          </div>

          <div className="flex items-center gap-2">
            <span className="text-[11px] text-[var(--color-text-muted)] font-mono">
              Target ID: <code className="text-[var(--color-accent)]">{editingCharacter.id}</code>
            </span>
          </div>
        </div>

        <CharacterEditor
          character={editingCharacter}
          onSave={handleSaveEditedCharacter}
        />
      </div>

      {/* Modal for Creating New Characters */}
      <AddCharacterModal
        isOpen={isAddModalOpen}
        onClose={() => setIsAddModalOpen(false)}
        onAddCharacter={handleAddNewCharacter}
      />
    </div>
  );
};
