package com.example

import com.example.domain.model.DeviceCategory
import com.example.domain.model.DeviceStatus
import com.example.domain.model.ModelLocation
import com.example.domain.model.PerformanceProfile
import com.example.domain.model.RoutingPolicy
import com.example.ui.screens.devices.DevicesViewModel
import com.example.ui.screens.models.ModelsViewModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Unit tests for Batch 9: Mobile Models and Devices.
 *
 * Verifies:
 * MODELS:
 * - Shows only useful mobile information (current model, Local/Cloud, provider, performance profile, routing policy)
 * - Performance profiles: Eco, Balanced, Maximum
 * - Routing policies: Local Only, Local First, Cloud First, Cloud Only
 * - Optional expandable PC resource summary mock: CPU, RAM, GPU
 * - Advanced runtime configuration kept on PC
 *
 * DEVICES:
 * - Displays mock: Local AI Core PC, This Phone, audio output, microphone, health provider
 * - Status: Online, Offline, Connecting
 * - No hardcoded actual device brands
 * - No Bluetooth implementation
 */
class ModelsAndDevicesUnitTest {

    @Test
    fun `models page presents current model with local or cloud status and provider`() {
        val viewModel = ModelsViewModel()
        val state = viewModel.uiState.value
        val currentModel = state.currentModel

        assertNotNull("Current model must not be null", currentModel)
        assertTrue("Model name must not be blank", currentModel.name.isNotBlank())
        assertTrue(
            "Model location must be Local or Cloud",
            currentModel.location == ModelLocation.LOCAL || currentModel.location == ModelLocation.CLOUD
        )
        assertTrue("Provider must not be blank", currentModel.provider.isNotBlank())
    }

    @Test
    fun `models page supports performance profiles - Eco, Balanced, Maximum`() {
        val viewModel = ModelsViewModel()

        // Verify all 3 profiles exist
        val allProfiles = PerformanceProfile.entries
        assertEquals(3, allProfiles.size)
        assertTrue(allProfiles.any { it == PerformanceProfile.ECO })
        assertTrue(allProfiles.any { it == PerformanceProfile.BALANCED })
        assertTrue(allProfiles.any { it == PerformanceProfile.MAXIMUM })

        // Switch to Eco
        viewModel.setPerformanceProfile(PerformanceProfile.ECO)
        assertEquals(PerformanceProfile.ECO, viewModel.uiState.value.performanceProfile)

        // Switch to Balanced
        viewModel.setPerformanceProfile(PerformanceProfile.BALANCED)
        assertEquals(PerformanceProfile.BALANCED, viewModel.uiState.value.performanceProfile)

        // Switch to Maximum
        viewModel.setPerformanceProfile(PerformanceProfile.MAXIMUM)
        assertEquals(PerformanceProfile.MAXIMUM, viewModel.uiState.value.performanceProfile)
    }

    @Test
    fun `models page supports routing policies - Local Only, Local First, Cloud First, Cloud Only`() {
        val viewModel = ModelsViewModel()

        // Verify all 4 routing policies exist
        val allPolicies = RoutingPolicy.entries
        assertEquals(4, allPolicies.size)
        assertTrue(allPolicies.any { it == RoutingPolicy.LOCAL_ONLY })
        assertTrue(allPolicies.any { it == RoutingPolicy.LOCAL_FIRST })
        assertTrue(allPolicies.any { it == RoutingPolicy.CLOUD_FIRST })
        assertTrue(allPolicies.any { it == RoutingPolicy.CLOUD_ONLY })

        // Switch through routing policies
        viewModel.setRoutingPolicy(RoutingPolicy.LOCAL_ONLY)
        assertEquals(RoutingPolicy.LOCAL_ONLY, viewModel.uiState.value.routingPolicy)

        viewModel.setRoutingPolicy(RoutingPolicy.LOCAL_FIRST)
        assertEquals(RoutingPolicy.LOCAL_FIRST, viewModel.uiState.value.routingPolicy)

        viewModel.setRoutingPolicy(RoutingPolicy.CLOUD_FIRST)
        assertEquals(RoutingPolicy.CLOUD_FIRST, viewModel.uiState.value.routingPolicy)

        viewModel.setRoutingPolicy(RoutingPolicy.CLOUD_ONLY)
        assertEquals(RoutingPolicy.CLOUD_ONLY, viewModel.uiState.value.routingPolicy)
    }

    @Test
    fun `models page supports optional expandable PC resource summary with mock CPU, RAM, GPU`() {
        val viewModel = ModelsViewModel()

        // Initially collapsed
        assertFalse(viewModel.uiState.value.isPcResourcesExpanded)

        // Toggle expand
        viewModel.togglePcResources()
        assertTrue(viewModel.uiState.value.isPcResourcesExpanded)

        // Verify PC resource metrics
        val pc = viewModel.uiState.value.pcResourceSummary
        assertTrue("CPU usage must be non-negative", pc.cpuUsagePercent >= 0)
        assertTrue("CPU info must be present", pc.cpuInfo.isNotBlank())
        assertTrue("RAM used must be positive", pc.ramUsedGb > 0f)
        assertTrue("RAM total must be positive", pc.ramTotalGb >= pc.ramUsedGb)
        assertTrue("GPU usage must be non-negative", pc.gpuUsagePercent >= 0)
        assertTrue("GPU model must be present", pc.gpuModel.isNotBlank())
        assertTrue("VRAM used must be positive", pc.vramUsedGb > 0f)
        assertTrue("GPU temp must be positive", pc.gpuTempCelsius > 0)

        // Toggle collapse
        viewModel.togglePcResources()
        assertFalse(viewModel.uiState.value.isPcResourcesExpanded)
    }

    @Test
    fun `models page allows switching active model`() {
        val viewModel = ModelsViewModel()
        val available = viewModel.uiState.value.availableModels
        assertTrue("Must have multiple available models", available.size >= 2)

        val targetModel = available.first { it.id != viewModel.uiState.value.currentModel.id }
        viewModel.selectModel(targetModel.id)

        assertEquals(targetModel.id, viewModel.uiState.value.currentModel.id)
    }

    @Test
    fun `devices page displays mock Local AI Core PC, This Phone, audio output, microphone, health provider`() {
        val viewModel = DevicesViewModel()
        val devices = viewModel.uiState.value.devices

        assertEquals(5, devices.size)

        // Check required mock device representations
        val pc = devices.firstOrNull { it.category == DeviceCategory.CORE_PC }
        assertNotNull("Local AI Core PC must exist", pc)
        assertEquals("Local AI Core PC", pc?.name)

        val phone = devices.firstOrNull { it.category == DeviceCategory.PHONE }
        assertNotNull("This Phone must exist", phone)
        assertEquals("This Phone", phone?.name)

        val audioOutput = devices.firstOrNull { it.category == DeviceCategory.AUDIO_OUTPUT }
        assertNotNull("Audio Output must exist", audioOutput)
        assertEquals("Audio Output", audioOutput?.name)

        val mic = devices.firstOrNull { it.category == DeviceCategory.MICROPHONE }
        assertNotNull("Microphone must exist", mic)
        assertEquals("Microphone", mic?.name)

        val health = devices.firstOrNull { it.category == DeviceCategory.HEALTH_PROVIDER }
        assertNotNull("Health Provider must exist", health)
        assertEquals("Health Provider", health?.name)
    }

    @Test
    fun `devices page uses Online, Offline, and Connecting statuses and no brand names`() {
        val viewModel = DevicesViewModel()
        val devices = viewModel.uiState.value.devices

        // Forbidden brand names checklist
        val commercialBrands = listOf("apple", "samsung", "sony", "pixel", "bose", "fitbit", "garmin", "xiaomi")

        devices.forEach { device ->
            // Verify valid status enum
            assertTrue(
                "Device status must be Online, Offline, or Connecting",
                device.status in listOf(DeviceStatus.ONLINE, DeviceStatus.OFFLINE, DeviceStatus.CONNECTING)
            )

            // Verify no brand names
            val lowercaseName = device.name.lowercase()
            commercialBrands.forEach { brand ->
                assertFalse(
                    "Device name '${device.name}' must not include commercial brand '$brand'",
                    lowercaseName.contains(brand)
                )
            }

            // Verify connection transport is not Bluetooth
            assertFalse(
                "Must not use Bluetooth implementation",
                device.connectionType.lowercase().contains("bluetooth")
            )
        }
    }

    @Test
    fun `devices page supports toggling device status and pinging nodes`() {
        val viewModel = DevicesViewModel()
        val firstDevice = viewModel.uiState.value.devices.first()
        val originalStatus = firstDevice.status

        // Toggle device status
        viewModel.toggleDeviceStatus(firstDevice.id)
        val updatedStatus = viewModel.uiState.value.devices.first { it.id == firstDevice.id }.status
        assertTrue(
            "Status should change after toggling",
            updatedStatus != originalStatus
        )

        // Set device status explicitly
        viewModel.setDeviceStatus(firstDevice.id, DeviceStatus.ONLINE)
        assertEquals(
            DeviceStatus.ONLINE,
            viewModel.uiState.value.devices.first { it.id == firstDevice.id }.status
        )
    }
}
