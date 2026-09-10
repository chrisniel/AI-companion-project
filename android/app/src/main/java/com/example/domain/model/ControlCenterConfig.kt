package com.example.domain.model

data class ControlCenterConfig(
    val assistantName: String = "Aura",
    val assistantSubtitle: String = "Cognitive Core Assistant",
    val userName: String = "Chris",
    val activeModel: String = "Llama-3.1-8B-Instruct",
    val runtimeProvider: String = "llama.cpp (CUDA/Metal)",
    val connection: ConnectionInfo = ConnectionInfo(
        state = CoreConnectionState.Online,
        label = "Core Active",
        latencyMs = 22,
        port = 8000
    )
)
