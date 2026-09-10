package com.example

import com.example.data.fake.FakeMemoryRepository
import com.example.domain.model.MemoryCategory
import com.example.domain.model.MemoryItem
import com.example.navigation.BottomNavItem
import com.example.navigation.MoreDestinations
import com.example.navigation.Routes
import com.example.ui.screens.memory.MemoryViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * Unit test suite for Batch 10: Mobile Memory and More Screen.
 */
class MemoryAndMoreUnitTest {

    private lateinit var repository: FakeMemoryRepository
    private lateinit var viewModel: MemoryViewModel

    @Before
    fun setUp() {
        repository = FakeMemoryRepository()
        viewModel = MemoryViewModel(repository)
    }

    // --- MEMORY: CATEGORIES ---

    @Test
    fun `memory supports all 6 required categories`() {
        val expectedCategories = setOf(
            MemoryCategory.PROFILE,
            MemoryCategory.PREFERENCE,
            MemoryCategory.FACT,
            MemoryCategory.PROJECT,
            MemoryCategory.EVENT,
            MemoryCategory.TEMPORARY
        )
        assertEquals(expectedCategories, MemoryCategory.entries.toSet())
    }

    @Test
    fun `repository has pre-populated readable memories in each category`() {
        val activeMemories = repository.searchMemories(query = "", category = null, showArchived = false)
        assertTrue(activeMemories.isNotEmpty())

        val presentCategories = activeMemories.map { it.category }.toSet()
        assertTrue(presentCategories.contains(MemoryCategory.PROFILE))
        assertTrue(presentCategories.contains(MemoryCategory.PREFERENCE))
        assertTrue(presentCategories.contains(MemoryCategory.FACT))
        assertTrue(presentCategories.contains(MemoryCategory.PROJECT))
        assertTrue(presentCategories.contains(MemoryCategory.EVENT))
        assertTrue(presentCategories.contains(MemoryCategory.TEMPORARY))
    }

    // --- MEMORY: SEARCH & FILTER ---

    @Test
    fun `memory search filters records by title, content, or tags`() {
        // Search by query
        viewModel.updateSearchQuery("Kotlin")
        val results = viewModel.uiState.value.memories
        assertTrue(results.isNotEmpty())
        assertTrue(results.all {
            it.title.contains("Kotlin", ignoreCase = true) ||
            it.content.contains("Kotlin", ignoreCase = true) ||
            it.tags.any { tag -> tag.contains("Kotlin", ignoreCase = true) }
        })

        // Clear search query
        viewModel.updateSearchQuery("")
        val resetResults = viewModel.uiState.value.memories
        assertTrue(resetResults.size > results.size)
    }

    @Test
    fun `memory filters by category chip`() {
        viewModel.selectCategory(MemoryCategory.PREFERENCE)
        val prefMemories = viewModel.uiState.value.memories
        assertTrue(prefMemories.isNotEmpty())
        assertTrue(prefMemories.all { it.category == MemoryCategory.PREFERENCE })

        // Clear category filter
        viewModel.selectCategory(null)
        val allMemories = viewModel.uiState.value.memories
        assertTrue(allMemories.size > prefMemories.size)
    }

    // --- MEMORY: VIEW, EDIT, ARCHIVE, DELETE ---

    @Test
    fun `memory view detail state opens and closes`() {
        val sample = viewModel.uiState.value.memories.first()
        viewModel.viewMemory(sample)
        assertEquals(sample.id, viewModel.uiState.value.viewingMemory?.id)

        viewModel.viewMemory(null)
        assertNull(viewModel.uiState.value.viewingMemory)
    }

    @Test
    fun `memory edit and save updates record`() {
        val original = viewModel.uiState.value.memories.first()
        viewModel.openEditMemory(original)
        assertTrue(viewModel.uiState.value.isEditorOpen)
        assertFalse(viewModel.uiState.value.isCreatingNew)

        val updatedTitle = "Updated Title for Testing"
        val updatedContent = "Updated content for testing readable memory."
        viewModel.saveMemory(
            title = updatedTitle,
            content = updatedContent,
            category = original.category,
            tags = listOf("Test", "Updated")
        )

        assertFalse(viewModel.uiState.value.isEditorOpen)
        val saved = viewModel.uiState.value.memories.find { it.id == original.id }
        assertNotNull(saved)
        assertEquals(updatedTitle, saved?.title)
        assertEquals(updatedContent, saved?.content)
    }

    @Test
    fun `memory archive toggle moves item between active and archive`() {
        val itemToArchive = viewModel.uiState.value.memories.first()
        viewModel.toggleArchive(itemToArchive.id)

        // Item should no longer appear in active memories
        assertFalse(viewModel.uiState.value.memories.any { it.id == itemToArchive.id })

        // Toggle to archived view
        viewModel.toggleShowArchived()
        assertTrue(viewModel.uiState.value.showArchivedOnly)

        // Item should now appear in archived memories
        assertTrue(viewModel.uiState.value.memories.any { it.id == itemToArchive.id })
    }

    @Test
    fun `memory delete removes item from repository`() {
        val itemToDelete = viewModel.uiState.value.memories.first()
        val initialCount = viewModel.uiState.value.memories.size

        viewModel.deleteMemory(itemToDelete.id)

        assertEquals(initialCount - 1, viewModel.uiState.value.memories.size)
        assertFalse(viewModel.uiState.value.memories.any { it.id == itemToDelete.id })
    }

    @Test
    fun `create new memory adds item to list`() {
        viewModel.openNewMemoryEditor()
        assertTrue(viewModel.uiState.value.isEditorOpen)
        assertTrue(viewModel.uiState.value.isCreatingNew)

        val newTitle = "New Unit Test Fact"
        val newContent = "Edge compute executes with zero external egress."
        viewModel.saveMemory(
            title = newTitle,
            content = newContent,
            category = MemoryCategory.FACT,
            tags = listOf("Security", "ZeroEgress")
        )

        val found = viewModel.uiState.value.memories.find { it.title == newTitle }
        assertNotNull(found)
        assertEquals(MemoryCategory.FACT, found?.category)
    }

    // --- MORE SCREEN: NAVIGATION LIST & LOGICAL GROUPING ---

    @Test
    fun `more screen navigation contains all 9 required destinations`() {
        val routes = MoreDestinations.items.map { it.route }.toSet()
        val requiredRoutes = setOf(
            Routes.SCHEDULE,
            Routes.ALARMS,
            Routes.CHARACTERS,
            Routes.MODELS,
            Routes.DEVICES,
            Routes.MEMORY,
            Routes.SETTINGS,
            Routes.CONNECTION,
            Routes.ABOUT
        )
        assertTrue(routes.containsAll(requiredRoutes))
    }

    @Test
    fun `more screen groups items logically into distinct sections`() {
        val sections = MoreDestinations.sections
        assertTrue(sections.size >= 4)

        // Verify logical groupings
        val timeItems = MoreDestinations.timeSection.items.map { it.route }
        assertTrue(timeItems.contains(Routes.SCHEDULE))
        assertTrue(timeItems.contains(Routes.ALARMS))

        val aiItems = MoreDestinations.aiSection.items.map { it.route }
        assertTrue(aiItems.contains(Routes.CHARACTERS))
        assertTrue(aiItems.contains(Routes.MEMORY))

        val hardwareItems = MoreDestinations.hardwareSection.items.map { it.route }
        assertTrue(hardwareItems.contains(Routes.MODELS))
        assertTrue(hardwareItems.contains(Routes.DEVICES))
        assertTrue(hardwareItems.contains(Routes.CONNECTION))

        val appItems = MoreDestinations.appSection.items.map { it.route }
        assertTrue(appItems.contains(Routes.SETTINGS))
        assertTrue(appItems.contains(Routes.ABOUT))
    }

    @Test
    fun `bottom navigation maintains exactly 5 primary items without overloading`() {
        val bottomNavItems = BottomNavItem.items
        assertEquals(5, bottomNavItems.size)
        assertEquals(listOf(Routes.HOME, Routes.ASSISTANT, Routes.TASKS, Routes.HEALTH, Routes.MORE), bottomNavItems.map { it.route })
    }
}
