import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:companion_api/companion_api.dart';

// Win32 DATA_BLOB struct for DPAPI:
// typedef struct _CRYPTOAPI_BLOB {
//   DWORD cbData;
//   BYTE  *pbData;
// } DATA_BLOB;
final class _DataBlob extends Struct {
  @Uint32()
  external int cbData;

  external Pointer<Uint8> pbData;
}

typedef _CryptProtectDataNative = Int32 Function(
  Pointer<_DataBlob> pDataIn,
  Pointer<Void> szDataDescr,
  Pointer<_DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  Uint32 dwFlags,
  Pointer<_DataBlob> pDataOut,
);
typedef _CryptProtectDataDart = int Function(
  Pointer<_DataBlob> pDataIn,
  Pointer<Void> szDataDescr,
  Pointer<_DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  int dwFlags,
  Pointer<_DataBlob> pDataOut,
);

typedef _CryptUnprotectDataNative = Int32 Function(
  Pointer<_DataBlob> pDataIn,
  Pointer<Void> ppszDataDescr,
  Pointer<_DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  Uint32 dwFlags,
  Pointer<_DataBlob> pDataOut,
);
typedef _CryptUnprotectDataDart = int Function(
  Pointer<_DataBlob> pDataIn,
  Pointer<Void> ppszDataDescr,
  Pointer<_DataBlob> pOptionalEntropy,
  Pointer<Void> pvReserved,
  Pointer<Void> pPromptStruct,
  int dwFlags,
  Pointer<_DataBlob> pDataOut,
);

typedef _LocalAllocNative = Pointer<Uint8> Function(Uint32 uFlags, IntPtr uBytes);
typedef _LocalAllocDart = Pointer<Uint8> Function(int uFlags, int uBytes);

typedef _LocalFreeNative = Pointer<Void> Function(Pointer<Void> hMem);
typedef _LocalFreeDart = Pointer<Void> Function(Pointer<Void> hMem);

/// Windows credential store leveraging DPAPI (`CryptProtectData` / `CryptUnprotectData`).
///
/// Plaintext tokens are encrypted at rest using the active Windows user logon key,
/// preventing plaintext credential leakage in files, logs, or backups.
class WindowsDpapiCredentialStore implements CredentialStore {
  final String? customFilePath;

  WindowsDpapiCredentialStore({this.customFilePath});

  String get _filePath {
    if (customFilePath != null) return customFilePath!;
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.trim().isEmpty) {
      throw StateError('LOCALAPPDATA environment variable is unset.');
    }
    return '$localAppData\\AI Companion\\credentials.bin';
  }

  Uint8List _encryptDpapi(Uint8List plaintextBytes) {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final localAlloc = kernel32.lookupFunction<_LocalAllocNative, _LocalAllocDart>('LocalAlloc');
    final localFree = kernel32.lookupFunction<_LocalFreeNative, _LocalFreeDart>('LocalFree');

    final crypt32 = DynamicLibrary.open('Crypt32.dll');
    final cryptProtectData = crypt32.lookupFunction<_CryptProtectDataNative, _CryptProtectDataDart>('CryptProtectData');

    final pInMem = localAlloc(0x0040 /* LPTR */, plaintextBytes.length);
    for (int i = 0; i < plaintextBytes.length; i++) {
      pInMem[i] = plaintextBytes[i];
    }

    final pDataIn = localAlloc(0x0040, sizeOf<_DataBlob>()).cast<_DataBlob>();
    pDataIn.ref.cbData = plaintextBytes.length;
    pDataIn.ref.pbData = pInMem;

    final pDataOut = localAlloc(0x0040, sizeOf<_DataBlob>()).cast<_DataBlob>();

    try {
      // 0x1 = CRYPTPROTECT_UI_FORBIDDEN
      final res = cryptProtectData(
        pDataIn,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        1,
        pDataOut,
      );

      if (res == 0) {
        throw const FileSystemException('DPAPI CryptProtectData failed');
      }

      final outLen = pDataOut.ref.cbData;
      final outBytes = Uint8List(outLen);
      for (int i = 0; i < outLen; i++) {
        outBytes[i] = pDataOut.ref.pbData[i];
      }
      return outBytes;
    } finally {
      localFree(pInMem.cast());
      localFree(pDataIn.cast());
      if (pDataOut.ref.pbData != nullptr) {
        localFree(pDataOut.ref.pbData.cast());
      }
      localFree(pDataOut.cast());
    }
  }

  Uint8List _decryptDpapi(Uint8List cipherBytes) {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final localAlloc = kernel32.lookupFunction<_LocalAllocNative, _LocalAllocDart>('LocalAlloc');
    final localFree = kernel32.lookupFunction<_LocalFreeNative, _LocalFreeDart>('LocalFree');

    final crypt32 = DynamicLibrary.open('Crypt32.dll');
    final cryptUnprotectData = crypt32.lookupFunction<_CryptUnprotectDataNative, _CryptUnprotectDataDart>('CryptUnprotectData');

    final pInMem = localAlloc(0x0040 /* LPTR */, cipherBytes.length);
    for (int i = 0; i < cipherBytes.length; i++) {
      pInMem[i] = cipherBytes[i];
    }

    final pDataIn = localAlloc(0x0040, sizeOf<_DataBlob>()).cast<_DataBlob>();
    pDataIn.ref.cbData = cipherBytes.length;
    pDataIn.ref.pbData = pInMem;

    final pDataOut = localAlloc(0x0040, sizeOf<_DataBlob>()).cast<_DataBlob>();

    try {
      // 0x1 = CRYPTPROTECT_UI_FORBIDDEN
      final res = cryptUnprotectData(
        pDataIn,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        1,
        pDataOut,
      );

      if (res == 0) {
        throw const FileSystemException('DPAPI CryptUnprotectData failed');
      }

      final outLen = pDataOut.ref.cbData;
      final outBytes = Uint8List(outLen);
      for (int i = 0; i < outLen; i++) {
        outBytes[i] = pDataOut.ref.pbData[i];
      }
      return outBytes;
    } finally {
      localFree(pInMem.cast());
      localFree(pDataIn.cast());
      if (pDataOut.ref.pbData != nullptr) {
        localFree(pDataOut.ref.pbData.cast());
      }
      localFree(pDataOut.cast());
    }
  }

  @override
  Future<String?> readToken() async {
    if (!Platform.isWindows) {
      return null;
    }
    try {
      final file = File(_filePath);
      if (!await file.exists()) {
        return null;
      }

      final encryptedBytes = await file.readAsBytes();
      if (encryptedBytes.isEmpty) {
        return null;
      }

      final decryptedBytes = _decryptDpapi(encryptedBytes);
      return utf8.decode(decryptedBytes);
    } catch (_) {
      // Fail closed if unreadable or corrupted
      return null;
    }
  }

  @override
  Future<void> writeToken(String token) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('WindowsDpapiCredentialStore requires Windows OS.');
    }
    final file = File(_filePath);
    await file.parent.create(recursive: true);

    final rawBytes = Uint8List.fromList(utf8.encode(token));
    final encryptedBytes = _encryptDpapi(rawBytes);
    await file.writeAsBytes(encryptedBytes, flush: true);
  }

  @override
  Future<void> deleteToken() async {
    try {
      final file = File(_filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
