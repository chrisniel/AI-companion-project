import 'dart:io';
import 'package:companion_api/companion_api.dart';

typedef SecretReaderProcess = Future<ProcessResult> Function(
    String executable, List<String> arguments);

/// Reads backend-provisioned authority only after fixed-path Windows ACL checks.
/// This store deliberately cannot provision, modify or remove host credentials.
class HostAdminSecretStore implements CredentialStore {
  HostAdminSecretStore({SecretReaderProcess? run})
      : _run = run ?? ((exe, args) => Process.run(exe, args));
  final SecretReaderProcess _run;
  static const _script = r'''
$ErrorActionPreference = 'Stop'
try {
  if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { throw 'No local host root' }
  $root = [IO.Path]::GetFullPath($env:LOCALAPPDATA)
  if (-not [IO.Path]::IsPathRooted($root) -or $root.StartsWith('\\')) { throw 'Invalid local host root' }
  $directory = Join-Path $root 'AICompanion\secrets'
  $secretPath = Join-Path $directory 'desktop_admin.secret'
  $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  $allowed = @($currentSid, 'S-1-5-18')
  $node = Get-Item -LiteralPath $secretPath -Force
  while ($null -ne $node) {
    if (($node.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Reparse path' }
    if ($node -is [IO.FileInfo]) { $node = $node.Directory } else { $node = $node.Parent }
  }
  foreach ($target in @($directory, $secretPath)) {
    $acl = Get-Acl -LiteralPath $target
    if (-not $acl.AreAccessRulesProtected) { throw 'Inherited ACL' }
    $owner = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    if ($owner -notin $allowed) { throw 'Unexpected owner' }
    foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
      if ($rule.IdentityReference.Value -notin $allowed) { throw 'Unexpected principal' }
    }
  }
  $secret = [IO.File]::ReadAllText($secretPath).Trim()
  if ([string]::IsNullOrWhiteSpace($secret) -or $secret -match '\s') { throw 'Invalid secret' }
  [Console]::Out.Write($secret)
} catch { exit 1 }
''';
  @override
  Future<String?> readToken() async {
    final result = await _run('powershell.exe',
        ['-NoProfile', '-NonInteractive', '-Command', _script]);
    if (result.exitCode != 0) {
      throw StateError(
          'Trusted local Host Admin authority could not be validated.');
    }
    final secret = result.stdout.toString().trim();
    if (secret.isEmpty || RegExp(r'\s').hasMatch(secret)) {
      throw StateError('Invalid local Host Admin authority.');
    }
    return secret;
  }

  @override
  Future<void> writeToken(String token) async => throw UnsupportedError(
      'Only the host runtime provisions administration credentials.');
  @override
  Future<void> deleteToken() async => throw UnsupportedError(
      'Only the host runtime manages administration credentials.');
}
