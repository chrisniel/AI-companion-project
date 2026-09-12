package com.example

import com.example.domain.model.MobileTask
import com.example.domain.model.TaskCategory
import com.example.domain.model.TaskPriority
import com.example.domain.model.TaskViewTab
import com.example.ui.screens.tasks.TasksViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for Mobile Tasks (Batch 5).
 * Tests primary views, task row fields, multilingual examples, quick actions, and create/edit flow.
 */
class TasksUnitTest {

    @Test
    fun `initial tasks contain multilingual prompt examples`() {
        val viewModel = TasksViewModel()
        val tasks = viewModel.uiState.value.tasks

        // Multilingual examples from prompt:
        // "Check backend bukas"
        // "Android UIを確認"
        val filipinoTask = tasks.find { it.title == "Check backend bukas" }
        assertNotNull("Must contain 'Check backend bukas' task", filipinoTask)
        assertEquals(TaskCategory.DEV, filipinoTask?.category)
        assertEquals(TaskPriority.HIGH, filipinoTask?.priority)
        assertEquals("Today", filipinoTask?.dueDate)
        assertNotNull(filipinoTask?.dueTime)

        val japaneseTask = tasks.find { it.title == "Android UIを確認" }
        assertNotNull("Must contain 'Android UIを確認' task", japaneseTask)
        assertEquals(TaskPriority.URGENT, japaneseTask?.priority)
        assertEquals("Today", japaneseTask?.dueDate)
    }

    @Test
    fun `tab switching switches between Today, Upcoming, and Completed views`() {
        val viewModel = TasksViewModel()
        assertEquals(TaskViewTab.TODAY, viewModel.uiState.value.selectedTab)

        viewModel.selectTab(TaskViewTab.UPCOMING)
        assertEquals(TaskViewTab.UPCOMING, viewModel.uiState.value.selectedTab)

        viewModel.selectTab(TaskViewTab.COMPLETED)
        assertEquals(TaskViewTab.COMPLETED, viewModel.uiState.value.selectedTab)
    }

    @Test
    fun `quick action toggle complete changes completion state and sets completedAt`() {
        val viewModel = TasksViewModel()
        val targetTask = viewModel.uiState.value.tasks.first { !it.isCompleted }
        val targetId = targetTask.id

        viewModel.toggleTaskComplete(targetId)

        val updatedTask = viewModel.uiState.value.tasks.first { it.id == targetId }
        assertTrue(updatedTask.isCompleted)
        assertNotNull(updatedTask.completedAt)

        // Toggle again
        viewModel.toggleTaskComplete(targetId)
        val toggledBack = viewModel.uiState.value.tasks.first { it.id == targetId }
        assertFalse(toggledBack.isCompleted)
        assertNull(toggledBack.completedAt)
    }

    @Test
    fun `quick action delete removes task from list`() {
        val viewModel = TasksViewModel()
        val initialCount = viewModel.uiState.value.tasks.size
        val targetId = viewModel.uiState.value.tasks.first().id

        viewModel.deleteTask(targetId)

        val newTasks = viewModel.uiState.value.tasks
        assertEquals(initialCount - 1, newTasks.size)
        assertNull(newTasks.find { it.id == targetId })
    }

    @Test
    fun `quick action snooze reschedules task to tomorrow morning`() {
        val viewModel = TasksViewModel()
        val targetId = viewModel.uiState.value.tasks.first { !it.isCompleted }.id

        viewModel.snoozeTask(targetId)

        val snoozedTask = viewModel.uiState.value.tasks.first { it.id == targetId }
        assertTrue(snoozedTask.isSnoozed)
        assertEquals("Tomorrow", snoozedTask.dueDate)
        assertEquals("09:00", snoozedTask.dueTime)
    }

    @Test
    fun `create new task prepends task with all required fields`() {
        val viewModel = TasksViewModel()
        val initialCount = viewModel.uiState.value.tasks.size

        viewModel.openCreateSheet()
        assertTrue(viewModel.uiState.value.isCreateOrEditSheetOpen)
        assertNull(viewModel.uiState.value.editingTaskId)

        val newTitle = "Deploy edge model update"
        val newDesc = "Test INT8 quantized weights on NPU"
        viewModel.saveTask(
            title = newTitle,
            description = newDesc,
            category = TaskCategory.DEV,
            priority = TaskPriority.HIGH,
            dueDate = "Today",
            dueTime = "17:00",
            reminder = "30 mins before"
        )

        assertFalse(viewModel.uiState.value.isCreateOrEditSheetOpen)
        assertEquals(initialCount + 1, viewModel.uiState.value.tasks.size)

        val created = viewModel.uiState.value.tasks.first()
        assertEquals(newTitle, created.title)
        assertEquals(newDesc, created.description)
        assertEquals(TaskCategory.DEV, created.category)
        assertEquals(TaskPriority.HIGH, created.priority)
        assertEquals("Today", created.dueDate)
        assertEquals("17:00", created.dueTime)
        assertEquals("30 mins before", created.reminder)
    }

    @Test
    fun `edit task updates existing task properties`() {
        val viewModel = TasksViewModel()
        val targetId = viewModel.uiState.value.tasks.first().id

        viewModel.openEditSheet(targetId)
        assertTrue(viewModel.uiState.value.isCreateOrEditSheetOpen)
        assertEquals(targetId, viewModel.uiState.value.editingTaskId)

        val updatedTitle = "Updated task title with multilingual 日本語 notes"
        viewModel.saveTask(
            title = updatedTitle,
            description = "Updated description",
            category = TaskCategory.WORK,
            priority = TaskPriority.URGENT,
            dueDate = "Tomorrow",
            dueTime = "11:00",
            reminder = "At due time"
        )

        assertFalse(viewModel.uiState.value.isCreateOrEditSheetOpen)
        val edited = viewModel.uiState.value.tasks.first { it.id == targetId }
        assertEquals(updatedTitle, edited.title)
        assertEquals(TaskCategory.WORK, edited.category)
        assertEquals(TaskPriority.URGENT, edited.priority)
        assertEquals("Tomorrow", edited.dueDate)
    }
}
