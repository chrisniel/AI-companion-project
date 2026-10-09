# AI Companion — Windows Desktop Client (`ai_companion_desktop`)

The primary PC V1 client for AI Companion, built with Flutter Desktop for Windows x64. It pairs with the local Python FastAPI runtime, providing local LLM interaction, Neumorphic + Glassmorphic UI aesthetics, Windows DPAPI-secured credential storage, and seamless system tray background persistence.

---

## 1. Architecture & Workspace Layout

The application resides within the monorepo Flutter workspace (`frontend/flutter/`):

```text
frontend/flutter/
├── apps/
│   └── desktop/                  # Windows desktop executable runner & UI shell
│       ├── lib/
│       │   ├── controllers/      # Settings and presentation state controllers
│       │   ├── features/chat/    # Interactive conversation state & streaming
│       │   ├── harness/          # Visual evidence & CI verification harness
│       │   ├── lifecycle/        # Window close-to-tray & restore lifecycle
│       │   ├── platform/         # Windows DPAPI credential store (dart:ffi)
│       │   ├── screens/          # ChatScreen, SettingsScreen, etc.
│       │   └── shell/            # Neumorphic navigation rail and header shell
│       └── test/                 # Component, lifecycle, and DPAPI unit tests
└── packages/
    ├── companion_core/           # Base utilities, UUID generation, shared types
    ├── companion_api/            # Typed OpenAPI DTOs, SSE parser, REST client
    └── companion_design/         # Neumorphic tokens, SoftGlass, Liquid Glass, themes
```

---

## 2. Prerequisites

- **Flutter SDK:** Flutter 3.29+ with Dart 3.7+
- **Windows Toolchain:**
  - Visual Studio 2022 with "Desktop development with C++" workload installed.
  - Windows 10/11 SDK.
- **Python Runtime (optional for backend pairing):** Python 3.11+ running `backend/` on `http://127.0.0.1:8000`.

---

## 3. Running the Application

### Option A: Repository Root Script (Recommended)
From the repository root, execute the launcher script in PowerShell:

```powershell
# Default debug launch (connects to http://127.0.0.1:8000)
.\scripts\run-desktop.ps1

# Specify custom backend host URL
.\scripts\run-desktop.ps1 -HostUrl "http://127.0.0.1:8000"

# Build in release mode
.\scripts\run-desktop.ps1 -Mode release
```

### Option B: Direct Flutter CLI
Navigate to the desktop directory and run:

```powershell
cd frontend/flutter/apps/desktop
flutter run -d windows
```

To configure custom backend parameters at compile time:
```powershell
flutter run -d windows --dart-define=COMPANION_HOST_URL=http://127.0.0.1:8000
```

---

## 4. Building the Executable

To generate the standalone native Windows binary:

```powershell
# Debug build
flutter build windows --debug

# Release build
flutter build windows --release
```

The resulting binaries are output to:
`build/windows/x64/runner/[Debug|Release]/ai_companion_desktop.exe`

---

## 5. Security & Credential Storage

The desktop client implements zero-plaintext credential persistence:
- **Windows DPAPI Integration (`dart:ffi`):** All pairing tokens are encrypted via Windows Data Protection API (`CryptProtectData` in `Crypt32.dll`) before being stored on disk.
- **Decryption:** The user's active login session key (`CryptUnprotectData`) is required to read tokens.
- **Storage Location:** `%LOCALAPPDATA%\AICompanion\credentials.dat`. Real tokens are never committed or logged.

---

## 6. Testing & Quality Verification

### Run Flutter Unit & Widget Tests
```powershell
# Test all workspace packages and apps
cd frontend/flutter
flutter test

# Or test the desktop app specifically
cd frontend/flutter/apps/desktop
flutter test
```

### Run Static Analysis
```powershell
cd frontend/flutter
dart analyze .
```

### Run OpenAPI Contract Parity Checker
```powershell
python scripts/check_dart_openapi_parity.py --check
```

### Run Native Windows Lifecycle Verification
```powershell
.\scripts\verify_native_windows_lifecycle.ps1
```

---

## 7. Troubleshooting

- **`MainWindowHandle = 0` or Blank Window:**
  Ensure the latest Visual C++ Redistributable is installed. Verify display drivers support DirectX 11 / OpenGL.
- **Tray Icon Missing:**
  The application automatically falls back to standard taskbar minimizing if system tray initialization fails. Verify the tray icon asset exists under `assets/icons/app_icon.ico`.
- **Backend Connection Refused:**
  Ensure the Python FastAPI backend is running (`uvicorn app.main:app --port 8000`). Verify host URL in Settings > Runtime Connection.
