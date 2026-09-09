[CmdletBinding()]
param([switch]$ContentReview, [switch]$SequenceReview, [switch]$DisableGpu, [string]$SkinDirectory, [string]$StopRequestPath)

if ($SequenceReview) { $ContentReview = $true }

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$LabRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$RuntimeRoot = Join-Path $LabRoot 'runtime'
$RunRoot = Join-Path $LabRoot ('runs\' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
[void]([System.IO.Directory]::CreateDirectory($RunRoot))
$ResultPath = Join-Path $RunRoot $(if ($SequenceReview) { 'D6_RESULT.md' } elseif ($ContentReview) { 'D5_RESULT.md' } else { 'D4_RESULT.md' })
$FullHostScreenshotPath = Join-Path $RunRoot 'd4-full-host.png'
$DebugScreenshotPath = Join-Path $RunRoot 'd4-debug-boundaries.png'
$ProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $LabRoot '..\..\小程序\codex-slide-evolution'))
$AssetPath = Join-Path $ProjectRoot 'assets\anchors\frame_01.png'
$ExpectedVersion = '26.901.6511.0'
$ExpectedCommit = '80eb01143daae693a7d6f25fe329d723a41183da'
$ExpectedAssetHash = '9849E41B833B28FE6D88EB7D1D0B38ADD71161016F7470188FAC97B632EADD14'

$result = [ordered]@{
  Classification = 'D4_GLASS_FAILED'
  ProbeTime = (Get-Date).ToString('o')
  CodexVersion = 'UNAVAILABLE'
  GraphicsMode = $(if ($DisableGpu) { 'DISABLE_GPU_REQUESTED' } else { 'DEFAULT' })
  OfficialCodexValidation = 'NOT_CHECKED'
  ProjectCommit = 'NOT_CHECKED'
  ProjectCommitValidation = 'NOT_CHECKED'
  ProjectStatusValidation = 'NOT_CHECKED'
  L1AssetPath = $AssetPath
  L1ExpectedHash = $ExpectedAssetHash
  L1ActualHash = 'NOT_CHECKED'
  L1AssetHash = 'NOT_CHECKED'
  Port = 'NOT_SELECTED'
  LaunchedPid = 'NOT_RECORDED'
  Listener = 'NOT_CHECKED'
  ListenerOwnerPid = 'UNAVAILABLE'
  ListenerOwnerMatchesLaunchedPid = 'NOT_CHECKED'
  OwnerValidation = 'NOT_CHECKED'
  BrowserIdValidation = 'NOT_CHECKED'
  RendererValidation = 'NOT_CHECKED'
  RuntimeEvaluate = 'NOT_CHECKED'
  ShellSanity = 'NOT_CHECKED'
  BlobObjectUrl = 'NOT_CHECKED'
  VisualRoot = 'NOT_CHECKED'
  ImageLoaded = 'NOT_CHECKED'
  ImageNaturalSize = 'NOT_READ'
  ViewportRect = 'NOT_READ'
  RootRect = 'NOT_READ'
  ImageRect = 'NOT_READ'
  Geometry = 'NOT_CHECKED'
  RootPointerEvents = 'NOT_READ'
  ImagePointerEvents = 'NOT_READ'
  HorizontalOverflow = 'NOT_CHECKED'
  MainSelectorMatched = 'NOT_CHECKED'
  MainBackgroundBefore = 'NOT_READ'
  MainBackgroundColorBefore = 'NOT_READ'
  MainBackgroundImageBefore = 'NOT_READ'
  MainOpacityBefore = 'NOT_READ'
  MainBoxShadowBefore = 'NOT_READ'
  MainBackdropFilterBefore = 'NOT_READ'
  MainBackgroundBeforeWhite = 'NOT_CHECKED'
  MainBackgroundAfter = 'NOT_READ'
  MainBackgroundColorAfter = 'NOT_READ'
  MainBackgroundImageAfter = 'NOT_READ'
  MainOpacityAfter = 'NOT_READ'
  MainBoxShadowAfter = 'NOT_READ'
  MainBackdropFilterAfter = 'NOT_READ'
  MainBackgroundTransparent = 'NOT_CHECKED'
  NonBackgroundPropertiesUnchanged = 'NOT_CHECKED'
  BackgroundImageOverride = 'NOT_CHECKED'
  CentralL1Visibility = 'NOT_CHECKED'
  RemainingLargeOpaqueSurface = 'NOT_READ'
  SidebarVisible = 'NOT_CHECKED'
  ComposerVisible = 'NOT_CHECKED'
  NativeBusinessLogic = 'UNTOUCHED'
  MainSurfaceRect = 'NOT_FOUND'
  SidebarRect = 'NOT_FOUND'
  ComposerRootRect = 'NOT_FOUND'
  ScreenshotSafety = 'NOT_CHECKED'
  FullHostScreenshot = 'NOT_CHECKED'
  FullHostScreenshotPath = $FullHostScreenshotPath
  DebugBoundaryScreenshot = 'NOT_CHECKED'
  DebugBoundaryScreenshotPath = $DebugScreenshotPath
  DebugOverlayImmediateRemoval = 'NOT_CHECKED'
  DebugOverlayRemoval = 'NOT_CHECKED'
  MainInlineStyleRestored = 'NOT_CHECKED'
  MainComputedStyleRestored = 'NOT_CHECKED'
  OverrideStyleRemoved = 'NOT_CHECKED'
  RootRemoval = 'NOT_CHECKED'
  ObjectUrlRevoke = 'NOT_CHECKED'
  DebugCleanup = 'NOT_NEEDED'
  PortClosed = 'NOT_CHECKED'
  ProfileRemoved = 'NOT_CHECKED'
  OrdinaryCodexRestored = 'NOT_NEEDED'
  RunnerSHA256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
  GlassSHA256 = (Get-FileHash -LiteralPath (Join-Path $LabRoot 'glass.js') -Algorithm SHA256).Hash
  NativeContent = 'NOT_CHECKED'
  Sequence = 'NOT_CHECKED'
  SequenceBundleSHA256 = 'NOT_CHECKED'
  SequenceCleanup = 'NOT_CHECKED'
  GlassLab = 'NOT_CHECKED'
  PendingMaterialChecks = 'NOT_CHECKED'
  GlassCleanup = 'NOT_CHECKED'
  CleanupReconnect = 'NOT_NEEDED'
  VisualAcceptance = 'PENDING_USER_REVIEW'
  FailureReason = 'NOT_RUN'
}

$codex = $null
$port = $null
$profilePath = $null
$socket = $null
$launchAttempted = $false
$sessionIdentity = $null

function Escape-MarkdownValue {
  param([AllowNull()][object]$Value)
  if ($null -eq $Value) { return 'null' }
  return (("$Value" -replace '\|', '\|') -replace "`r?`n", ' ')
}

function Write-LabResult {
  $lines = @(
    $(if ($SequenceReview) { '# Codex D6 Six Levels and EX Video Lab Result' } elseif ($ContentReview) { '# Codex D5 Single Native Content Lab Result' } else { '# Codex D4 L1 Glass Content Island Lab Result' }), '', "**$($result.Classification)**", '',
    '| Field | Value |', '|---|---|'
  )
  foreach ($entry in $result.GetEnumerator()) {
    if ($entry.Key -ne 'Classification') { $lines += "| $($entry.Key) | $(Escape-MarkdownValue $entry.Value) |" }
  }
  $lines += @('', '> Structural attributes, computed styles, and geometry only. No conversation text, cookies, storage, auth, tokens, network payloads, or API keys are read or recorded.')
  [System.IO.File]::WriteAllText($ResultPath, ($lines -join [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))
}

function Throw-LabFailure { param([string]$Message); throw [System.InvalidOperationException]::new($Message) }

function Get-SkinNode {
  $bundled = Join-Path $LabRoot 'vendor\node\node.exe'
  if (Test-Path -LiteralPath $bundled -PathType Leaf) { return $bundled }
  $installed = Get-Command node.exe -ErrorAction SilentlyContinue
  if ($installed) { return $installed.Source }
  Throw-LabFailure 'Node runtime is missing. Extract the complete skin package, including vendor/node.'
}

function Assert-FinalNativeContent {
  param($Evidence, [switch]$AllowNoVisibleTarget)
  if (-not $Evidence.previousTargetsRestored) { Throw-LabFailure 'Content tracking restoration failed.' }
  if ($AllowNoVisibleTarget -and $Evidence.status -eq 'NOT_FOUND') { return }
  if ($Evidence.status -ne 'APPLIED') { Throw-LabFailure 'No supported final reply visible at end of review.' }
  if (-not $Evidence.geometryUnchanged) { Throw-LabFailure 'Content tracking geometry check failed.' }
}

function Test-PathEqual {
  param([string]$Left, [string]$Right)
  if (-not $Left -or -not $Right) { return $false }
  return [System.StringComparer]::OrdinalIgnoreCase.Equals(
    [System.IO.Path]::GetFullPath($Left).TrimEnd('\'),
    [System.IO.Path]::GetFullPath($Right).TrimEnd('\')
  )
}

function Get-ValidatedCodexInstall {
  $packages = @(Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction Stop | Sort-Object Version -Descending)
  if ($packages.Count -lt 1) { Throw-LabFailure 'The official OpenAI.Codex Store package was not found.' }
  $package = $packages[0]
  if ("$($package.SignatureKind)" -ne 'Store' -or "$($package.Status)" -ne 'Ok') { Throw-LabFailure 'The registered OpenAI.Codex package is not healthy.' }
  if ("$($package.Version)" -ne $ExpectedVersion) { Throw-LabFailure "Installed Codex version $($package.Version) does not match expected $ExpectedVersion." }
  $packageRoot = [System.IO.Path]::GetFullPath("$($package.InstallLocation)")
  if ((Split-Path -Leaf $packageRoot) -cne "$($package.PackageFullName)") { Throw-LabFailure 'Package path and identity do not match.' }
  $manifest = Get-AppxPackageManifest -Package $package -ErrorAction Stop
  $apps = @($manifest.Package.Applications.Application | Where-Object { "$($_.Executable)".Replace('/', '\') -ieq 'app\ChatGPT.exe' })
  if ($apps.Count -ne 1) { Throw-LabFailure 'The Store manifest did not expose exactly one expected ChatGPT.exe app.' }
  $executable = Join-Path $packageRoot 'app\ChatGPT.exe'
  if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { Throw-LabFailure 'The expected Store executable is missing.' }
  $signature = Get-AuthenticodeSignature -LiteralPath $executable
  $signerSubject = if ($signature.SignerCertificate) { "$($signature.SignerCertificate.Subject)" } else { '' }
  if ("$($signature.Status)" -ne 'Valid' -or $signerSubject -notmatch 'OpenAI OpCo, LLC') { Throw-LabFailure 'The Codex executable signature was not valid for OpenAI.' }
  return [pscustomobject]@{
    Version = "$($package.Version)"
    PackageFullName = "$($package.PackageFullName)"
    PackageRoot = $packageRoot
    Executable = $executable
    AppUserModelId = "$($package.PackageFamilyName)!$($apps[0].Id)"
  }
}

function Get-CodexProcesses {
  param([Parameter(Mandatory)][object]$Install)
  return @(Get-CimInstance Win32_Process -Filter "Name='ChatGPT.exe'" -ErrorAction SilentlyContinue | Where-Object {
    $_.ExecutablePath -and (Test-PathEqual -Left "$($_.ExecutablePath)" -Right $Install.Executable)
  })
}

function Get-FreeLoopbackPort {
  for ($attempt = 0; $attempt -lt 10; $attempt++) {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    try { $listener.Start(); $candidate = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port } finally { $listener.Stop() }
    if ($candidate -ge 49152) { return $candidate }
  }
  Throw-LabFailure 'Could not select an ephemeral high loopback port.'
}

function ConvertTo-ArgumentLine {
  param([string[]]$Arguments)
  $encoded = foreach ($argument in $Arguments) {
    if ($argument.Contains('"')) { Throw-LabFailure 'A launch argument contained an unsupported quote.' }
    if ($argument -match '\s') { '"' + ($argument -replace '(\\+)$', '$1$1') + '"' } else { $argument }
  }
  return ($encoded -join ' ')
}

function Initialize-PackageLauncher {
  if ('CodexD4Glass.PackageLauncher' -as [type]) { return }
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace CodexD4Glass {
  [Flags] internal enum ActivateOptions : uint { None = 0 }
  [ComImport, Guid("2e941141-7f97-4756-ba1d-9decde894a3d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
  internal interface IApplicationActivationManager {
    [PreserveSig] int ActivateApplication([MarshalAs(UnmanagedType.LPWStr)] string appUserModelId, [MarshalAs(UnmanagedType.LPWStr)] string arguments, ActivateOptions options, out uint processId);
  }
  [ComImport, Guid("45ba127d-10a8-46ea-8ab7-56ea9078943c")]
  internal class ApplicationActivationManager {}
  public static class PackageLauncher {
    public static uint Launch(string appUserModelId, string arguments) {
      var manager = (IApplicationActivationManager)new ApplicationActivationManager();
      try { uint processId; int result = manager.ActivateApplication(appUserModelId, arguments ?? string.Empty, ActivateOptions.None, out processId); Marshal.ThrowExceptionForHR(result); return processId; }
      finally { if (Marshal.IsComObject(manager)) Marshal.FinalReleaseComObject(manager); }
    }
  }
}
'@
}

function Start-PackageCodex {
  param([Parameter(Mandatory)][object]$Install, [string[]]$Arguments = @())
  Initialize-PackageLauncher
  $launchedPid = [CodexD4Glass.PackageLauncher]::Launch($Install.AppUserModelId, (ConvertTo-ArgumentLine $Arguments))
  if ($launchedPid -le 0) { Throw-LabFailure 'Windows package activation did not return a process ID.' }
  return [int]$launchedPid
}

function Wait-ForLoopbackListener {
  param([int]$Port, [int]$TimeoutSeconds = 25)
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  do {
    $connections = @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
    if ($connections.Count -gt 0) { return $connections }
    Start-Sleep -Milliseconds 250
  } while ((Get-Date) -lt $deadline)
  return @()
}

function Wait-ForPortClosed {
  param([int]$Port, [int]$TimeoutMilliseconds = 5000)
  $deadline = (Get-Date).AddMilliseconds($TimeoutMilliseconds)
  do {
    if (@(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue).Count -eq 0) { return $true }
    Start-Sleep -Milliseconds 100
  } while ((Get-Date) -lt $deadline)
  return $false
}

function Assert-LoopbackListenerOwner {
  param([Parameter(Mandatory)][object[]]$Connections, [Parameter(Mandatory)][object]$Install)
  if ($Connections.Count -lt 1) { Throw-LabFailure 'No CDP listener appeared before timeout.' }
  if (@($Connections | Where-Object { "$($_.LocalAddress)" -ne '127.0.0.1' }).Count -gt 0) { Throw-LabFailure 'The selected port was not bound exclusively to 127.0.0.1.' }
  $owners = @($Connections | Select-Object -ExpandProperty OwningProcess -Unique)
  if ($owners.Count -ne 1 -or [int]$owners[0] -le 0) { Throw-LabFailure 'The listener owner PID was not unique and valid.' }
  $owner = Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$owners[0])" -ErrorAction Stop
  if (-not $owner.ExecutablePath -or -not (Test-PathEqual -Left "$($owner.ExecutablePath)" -Right $Install.Executable)) { Throw-LabFailure 'The listener owner was not the validated Store Codex executable.' }
  return [int]$owners[0]
}

function Assert-LocalWebSocketUrl {
  param([Parameter(Mandatory)][string]$Url, [int]$Port, [string]$PathPrefix)
  $uri = [Uri]$Url
  if ($uri.Scheme -ne 'ws' -or $uri.Host -ne '127.0.0.1' -or $uri.Port -ne $Port -or -not $uri.AbsolutePath.StartsWith($PathPrefix, [StringComparison]::Ordinal)) { Throw-LabFailure 'CDP advertised an untrusted WebSocket endpoint.' }
  return $uri
}

function Invoke-CdpCommand {
  param(
    [Parameter(Mandatory)][System.Net.WebSockets.ClientWebSocket]$Socket,
    [Parameter(Mandatory)][int]$Id,
    [Parameter(Mandatory)][string]$Method,
    [Parameter(Mandatory)][hashtable]$Params,
    [int]$MaxBytes = 1048576,
    [int]$TimeoutSeconds = 20
  )
  $payload = [ordered]@{ id = $Id; method = $Method; params = $Params } | ConvertTo-Json -Depth 12 -Compress
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
  $sendCts = [System.Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds($TimeoutSeconds))
  try { [void]($Socket.SendAsync([ArraySegment[byte]]::new($bytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $sendCts.Token).GetAwaiter().GetResult()) } finally { $sendCts.Dispose() }
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $memory = [System.IO.MemoryStream]::new()
    try {
      do {
        $buffer = [byte[]]::new(65536)
        $remaining = [Math]::Max(1, ($deadline - (Get-Date)).TotalMilliseconds)
        $receiveCts = [System.Threading.CancellationTokenSource]::new([TimeSpan]::FromMilliseconds($remaining))
        try { $received = $Socket.ReceiveAsync([ArraySegment[byte]]::new($buffer), $receiveCts.Token).GetAwaiter().GetResult() } finally { $receiveCts.Dispose() }
        if ($received.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) { Throw-LabFailure 'The renderer WebSocket closed.' }
        if ($received.Count -gt 0) { [void]($memory.Write($buffer, 0, $received.Count)) }
        if ($memory.Length -gt $MaxBytes) { Throw-LabFailure 'A CDP response exceeded the lab safety limit.' }
      } while (-not $received.EndOfMessage)
      $parsed = ([System.Text.Encoding]::UTF8.GetString($memory.ToArray()) | ConvertFrom-Json)
      if ($parsed -isnot [pscustomobject]) { Throw-LabFailure "CDP response $Id was malformed." }
      if ($parsed.PSObject.Properties['id'] -and $parsed.id -eq $Id) { return $parsed }
    } finally { $memory.Dispose() }
  }
  Throw-LabFailure "Timed out waiting for CDP response $Id."
}

function Invoke-CdpValue {
  param([Parameter(Mandatory)][System.Net.WebSockets.ClientWebSocket]$Socket, [int]$Id, [string]$Stage, [string]$Expression)
  try {
  $items = @(Invoke-CdpCommand -Socket $Socket -Id $Id -Method 'Runtime.evaluate' -Params @{ expression = $Expression; returnByValue = $true; awaitPromise = $true })
  } catch { Throw-LabFailure ("CDP transport failed at stage=$Stage id=$Id socket=$($Socket.State): " + $_.Exception.Message) }
  if ($items.Count -ne 1 -or $items[0] -isnot [pscustomobject]) { Throw-LabFailure "Invalid CDP response count or type at $Stage." }
  $response = $items[0]
  if ($response.PSObject.Properties['error']) { Throw-LabFailure "CDP error at $Stage." }
  if (-not $response.PSObject.Properties['result'] -or $response.result.PSObject.Properties['exceptionDetails']) { Throw-LabFailure "Runtime.evaluate failed at $Stage." }
  $remote = $response.result.result
  if (-not $remote -or -not $remote.PSObject.Properties['value']) { Throw-LabFailure "Runtime.evaluate returned no value at $Stage." }
  return $remote.value
}

function Mount-Sequence {
  param($Socket, [string]$Source)
  Write-Host 'D6: transferring original media. Keep the lab Codex window open; controls appear after loading.'
  [void](Invoke-CdpValue -Socket $Socket -Id 40 -Stage 'd6-transfer-start' -Expression "(() => { if (window.__codexSequenceTransfer || window.__codexSequence) throw Error('Already mounted'); window.__codexSequenceTransfer = { parts: [], state: 'UPLOADING' }; return true; })()")
  for ($offset = 0; $offset -lt $Source.Length; $offset += 262144) {
    $part = $Source.Substring($offset, [Math]::Min(262144, $Source.Length - $offset)) | ConvertTo-Json -Compress
    [void](Invoke-CdpValue -Socket $Socket -Id 40 -Stage "d6-transfer-offset-$offset" -Expression "window.__codexSequenceTransfer.parts.push($part)")
  }
  [void](Invoke-CdpValue -Socket $Socket -Id 40 -Stage 'd6-load-start' -Expression @'
(() => {
  const transfer = window.__codexSequenceTransfer;
  const source = transfer.parts.join('');
  delete transfer.parts;
  transfer.state = 'LOADING';
  try {
    Promise.resolve((0, eval)(source)).then(() => { transfer.state = 'READY'; }, () => { transfer.state = 'FAILED'; });
  } catch (_) { transfer.state = 'FAILED'; }
  return transfer.state;
})()
'@)
  Write-Host 'D6: transfer complete; waiting for media to load. To finish normally, use End Skin after the controls appear.'
  $loadDeadline = (Get-Date).AddSeconds(60)
  do {
    $state = Invoke-CdpValue -Socket $Socket -Id 40 -Stage 'd6-load-poll' -Expression "window.__codexSequenceTransfer?.state || 'CONTEXT_LOST'"
    if ($state -eq 'READY') { return }
    if ($state -ne 'LOADING') { Throw-LabFailure "D6 loading ended with state=$state." }
    Start-Sleep -Milliseconds 250
  } while ((Get-Date) -lt $loadDeadline)
  Throw-LabFailure 'D6 media loading did not finish within 60 seconds; transport polling remained responsive.'
}

function Get-SequenceRecoveryTarget {
  # Only a replacement renderer inside our original, still-running browser is eligible.
  $connections = @(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction Stop)
  $owner = Assert-LoopbackListenerOwner -Connections $connections -Install $codex
  $process = Get-CimInstance Win32_Process -Filter "ProcessId=$owner" -ErrorAction Stop
  if ($owner -ne $sessionIdentity.ProcessId -or $process.CreationDate -ne $sessionIdentity.CreationDate) { throw 'Recovery owner identity changed.' }
  $version = Invoke-RestMethod -Uri "$baseUri/json/version" -TimeoutSec 3 -MaximumRedirection 0
  if ($version.webSocketDebuggerUrl -cne $browserUri.AbsoluteUri) { throw 'Recovery browser identity changed.' }
  $targets = @(Invoke-RestMethod -Uri "$baseUri/json/list" -TimeoutSec 3 -MaximumRedirection 0 | ForEach-Object { $_ })
  $pages = @($targets | Where-Object { $_.type -eq 'page' -and $_.url -match '^app://' })
  if ($pages.Count -ne 1) { throw 'Recovery requires one app renderer.' }
  return (Assert-LocalWebSocketUrl -Url $pages[0].webSocketDebuggerUrl -Port $port -PathPrefix '/devtools/page/')
}

function Restore-SequenceVisual {
  $state = Invoke-CdpValue -Socket $socket -Id 42 -Stage 'recovery-state' -Expression "({ shell: document.querySelectorAll('main[data-app-shell-main-surface]').length === 1 && !!document.querySelector('[data-codex-composer-root]') && !!document.querySelector('[data-app-action-sidebar-scroll]'), mounted: !!window.__codexSequence && !!window.__codexD4Glass && !!document.getElementById('codex-skin-root') })"
  if (-not $state.shell) { throw 'Recovery shell not ready.' }
  if ($state.mounted) { return } # Transport-only failure: preserve current media and selection.
  [void](Invoke-CdpValue -Socket $socket -Id 42 -Stage 'recovery-reset' -Expression 'window.__codexSequence?.cleanup(); window.__codexD4Glass?.cleanup(); delete window.__codexSequenceTransfer; delete window.__codexSequence; delete window.__codexD4Glass; true')
  [void](Invoke-CdpValue -Socket $socket -Id 42 -Stage 'recovery-glass' -Expression $glassSource)
  [void](Invoke-CdpValue -Socket $socket -Id 42 -Stage 'recovery-background' -Expression $visualExpression)
  [void](Invoke-CdpValue -Socket $socket -Id 42 -Stage 'recovery-material' -Expression 'window.__codexD4Glass.apply(); window.__codexD4Glass.startNativeContentTracking(); true')
  Mount-Sequence -Socket $socket -Source ([IO.File]::ReadAllText($sequenceBundle))
  if ($sequenceEvidence -and $sequenceEvidence.level -ge 1 -and $sequenceEvidence.level -le 6) {
    [void](Invoke-CdpValue -Socket $socket -Id 42 -Stage 'recovery-level' -Expression "window.__codexSequence.select($([int]$sequenceEvidence.level))")
    if ($sequenceEvidence.phase -in @('ambient','entering')) {
      [void](Invoke-CdpValue -Socket $socket -Id 42 -Stage 'recovery-ex' -Expression "window.__codexSequence.select('ex')")
    }
  }
}

function Repair-SequenceConnection {
  Write-Host 'D6: connection interrupted; waiting for the same Codex browser and restoring the skin.'
  $recoveryDeadline = (Get-Date).AddSeconds(60)
  do {
    if ($StopRequestPath -and (Test-Path -LiteralPath $StopRequestPath)) { throw 'Recovery cancelled by End Skin.' }
    try {
      $recoveryUri = Get-SequenceRecoveryTarget
      if ($script:socket) { $script:socket.Dispose() }
      $script:socket = [System.Net.WebSockets.ClientWebSocket]::new()
      $cts = [System.Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds(5))
      try { [void]($script:socket.ConnectAsync($recoveryUri, $cts.Token).GetAwaiter().GetResult()) } finally { $cts.Dispose() }
      $script:targetUri = $recoveryUri
      Restore-SequenceVisual
      $restored = Invoke-CdpValue -Socket $socket -Id 41 -Stage 'recovery-status' -Expression 'window.__codexSequence.status()'
      if (-not $restored.ready) { throw 'Recovered media not ready.' }
      Add-Content -LiteralPath (Join-Path $RunRoot 'recovery.log') -Value ((Get-Date).ToString('o') + ' RECOVERED')
      return $restored
    } catch {
      $recoveryError = $_.Exception.Message
      Start-Sleep -Seconds 2
    }
  } while ((Get-Date) -lt $recoveryDeadline)
  throw "Skin recovery failed: $recoveryError"
}

function Save-CdpScreenshot {
  param([Parameter(Mandatory)][System.Net.WebSockets.ClientWebSocket]$Socket, [int]$Id, [string]$Path)
  $response = Invoke-CdpCommand -Socket $Socket -Id $Id -Method 'Page.captureScreenshot' -MaxBytes 16777216 -Params @{ format = 'png'; fromSurface = $true; captureBeyondViewport = $false }
  if (-not $response.result.data) { Throw-LabFailure 'Page.captureScreenshot returned no image data.' }
  [System.IO.File]::WriteAllBytes($Path, [Convert]::FromBase64String("$($response.result.data)"))
  return ((Test-Path -LiteralPath $Path -PathType Leaf) -and (Get-Item -LiteralPath $Path).Length -ge 1000)
}

function Stop-ValidatedCodexProcesses {
  param([Parameter(Mandatory)][object]$Install)
  if (-not $sessionIdentity) { Throw-LabFailure 'No validated launch identity; refusing process cleanup.' }
  $known = @{}
  $known[[int]$sessionIdentity.ProcessId] = $sessionIdentity
  $deadline = (Get-Date).AddSeconds(12)
  do {
    $all = @(Get-CodexProcesses -Install $Install)
    # Only expand descendants while their recorded parent identity is still alive.
    do {
      $added = $false
      foreach ($process in $all) {
        $parentId = [int]$process.ParentProcessId
        if ($known.ContainsKey([int]$process.ProcessId) -or -not $known.ContainsKey($parentId)) { continue }
        $parent = @($all | Where-Object { [int]$_.ProcessId -eq $parentId -and $_.CreationDate -eq $known[$parentId].CreationDate })
        if ($parent.Count -eq 1 -and $process.CreationDate -ge $parent[0].CreationDate) {
          $known[[int]$process.ProcessId] = $process
          $added = $true
        }
      }
    } while ($added)
    $alive = @($all | Where-Object { $known.ContainsKey([int]$_.ProcessId) -and $_.CreationDate -eq $known[[int]$_.ProcessId].CreationDate })
    if ($alive.Count -eq 0) { return $true }
    foreach ($process in @($alive | Sort-Object CreationDate -Descending)) {
      $fresh = Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$process.ProcessId)" -ErrorAction SilentlyContinue
      if (-not $fresh) { continue }
      if ($fresh.CreationDate -ne $process.CreationDate -or -not (Test-PathEqual -Left "$($fresh.ExecutablePath)" -Right $Install.Executable)) {
        Throw-LabFailure 'Process identity changed before cleanup; refusing to stop it.'
      }
      Stop-Process -Id ([int]$fresh.ProcessId) -Force -ErrorAction Stop
    }
    Start-Sleep -Milliseconds 150
  } while ((Get-Date) -lt $deadline)
  return $false
}

function Remove-LabProfile {
  param([string]$Path)
  if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return $true }
  $runtimePrefix = [System.IO.Path]::GetFullPath($RuntimeRoot).TrimEnd('\') + '\'
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  if (-not $fullPath.StartsWith($runtimePrefix, [System.StringComparison]::OrdinalIgnoreCase)) { Throw-LabFailure 'Refusing to remove a profile outside the D2 runtime directory.' }
  [System.IO.Directory]::Delete($fullPath, $true)
  return (-not (Test-Path -LiteralPath $fullPath))
}

try {
  if ($SkinDirectory -and -not $SequenceReview) { Throw-LabFailure 'Custom skins require SequenceReview.' }
  if ($SequenceReview) {
    $result.CoreBaselineValidation = 'NOT_CHECKED'
    $sequenceBundle = Join-Path $RunRoot 'sequence.bundle.js'
    $skinNode = Get-SkinNode
    & $skinNode (Join-Path $LabRoot 'build-sequence.js') $sequenceBundle $SkinDirectory
    if ($LASTEXITCODE -ne 0) { Throw-LabFailure 'Skin validation or sequence bundle build failed.' }
    $result.CoreBaselineValidation = 'PASS'
    $result.ProjectCommitValidation = 'NOT_APPLICABLE_BUNDLED_CORE'
    $result.ProjectStatusValidation = 'NOT_APPLICABLE_BUNDLED_CORE'
    $result.SequenceBundleSHA256 = (Get-FileHash -LiteralPath $sequenceBundle -Algorithm SHA256).Hash
    $AssetPath = $sequenceBundle + '.bootstrap.png'
    $bundleManifest = Get-Content -LiteralPath ($sequenceBundle + '.manifest.json') -Raw | ConvertFrom-Json
    $ExpectedAssetHash = $bundleManifest[0].sha256
    $result.L1AssetPath = $AssetPath
    $result.L1ExpectedHash = $ExpectedAssetHash
  } else {
  if (-not (Test-Path -LiteralPath $AssetPath -PathType Leaf)) { Throw-LabFailure 'The locked L1 asset is missing.' }
  $commit = (& git -C $ProjectRoot rev-parse HEAD 2>$null).Trim()
  $result.ProjectCommit = $commit
  $result.ProjectCommitValidation = if ($commit -ceq $ExpectedCommit) { 'PASS' } else { 'FAIL' }
  $status = @(& git -C $ProjectRoot status --porcelain=v1 2>$null)
  $result.ProjectStatusValidation = if ($LASTEXITCODE -eq 0 -and $status.Count -eq 0) { 'PASS' } else { 'FAIL' }
  if ($result.ProjectCommitValidation -ne 'PASS' -or $result.ProjectStatusValidation -ne 'PASS') { Throw-LabFailure 'The Visual Core baseline is not the locked clean commit.' }
  }
  $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $AssetPath).Hash
  $result.L1ActualHash = $actualHash
  $result.L1AssetHash = if ($actualHash -ceq $ExpectedAssetHash) { 'PASS' } else { 'FAIL' }
  if ($result.L1AssetHash -ne 'PASS') { Throw-LabFailure 'The L1 asset hash does not match the locked anchor.' }
  $assetBase64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($AssetPath))

  $codex = Get-ValidatedCodexInstall
  $result.CodexVersion = $codex.Version
  $result.OfficialCodexValidation = 'PASS'
  if (@(Get-CodexProcesses -Install $codex).Count -gt 0) { Throw-LabFailure 'Codex is still running. Save your work and fully exit Codex before starting the D4 lab.' }

  $port = Get-FreeLoopbackPort
  $result.Port = $port
  [void]([System.IO.Directory]::CreateDirectory($RuntimeRoot))
  $profilePath = Join-Path $RuntimeRoot ('profile-' + [Guid]::NewGuid().ToString('N'))
  [void]([System.IO.Directory]::CreateDirectory($profilePath))
  $launchAttempted = $true
  $debugArguments = @('--remote-debugging-address=127.0.0.1', "--remote-debugging-port=$port", "--user-data-dir=$profilePath")
  if ($DisableGpu) { $debugArguments += '--disable-gpu' }
  $launchedPid = Start-PackageCodex -Install $codex -Arguments $debugArguments
  $result.LaunchedPid = $launchedPid
  $candidateIdentity = Get-CimInstance Win32_Process -Filter "ProcessId=$launchedPid" -ErrorAction Stop
  if (-not $candidateIdentity -or -not (Test-PathEqual -Left "$($candidateIdentity.ExecutablePath)" -Right $codex.Executable) -or
      -not "$($candidateIdentity.CommandLine)".Contains("--remote-debugging-port=$port") -or
      -not "$($candidateIdentity.CommandLine)".Contains("--user-data-dir=$profilePath")) {
    Throw-LabFailure 'Launched process identity/profile/debug-port did not match; no broad process cleanup allowed.'
  }
  $sessionIdentity = $candidateIdentity

  $connections = @(Wait-ForLoopbackListener -Port $port)
  if ($connections.Count -eq 0) { Throw-LabFailure 'No CDP listener appeared before timeout.' }
  $result.Listener = 'PASS'
  $ownerPid = Assert-LoopbackListenerOwner -Connections $connections -Install $codex
  $result.ListenerOwnerPid = $ownerPid
  $result.ListenerOwnerMatchesLaunchedPid = ([int]$ownerPid -eq [int]$launchedPid)
  $result.OwnerValidation = if ($result.ListenerOwnerMatchesLaunchedPid) { 'PASS' } else { 'FAIL' }
  if ($result.OwnerValidation -ne 'PASS') { Throw-LabFailure 'The CDP listener was not owned by the launched session PID.' }

  $baseUri = "http://127.0.0.1:$port"
  $version = $null
  $deadline = (Get-Date).AddSeconds(10)
  do { try { $version = Invoke-RestMethod -Uri "$baseUri/json/version" -TimeoutSec 2 -MaximumRedirection 0 } catch { $version = $null }; if (-not $version) { Start-Sleep -Milliseconds 250 } } while (-not $version -and (Get-Date) -lt $deadline)
  if (-not $version -or -not $version.webSocketDebuggerUrl) { Throw-LabFailure 'The CDP version endpoint was unavailable.' }
  $browserUri = Assert-LocalWebSocketUrl -Url "$($version.webSocketDebuggerUrl)" -Port $port -PathPrefix '/devtools/browser/'
  $browserId = $browserUri.AbsolutePath.Substring('/devtools/browser/'.Length)
  $parsedBrowserId = [Guid]::Empty
  if (-not [Guid]::TryParse($browserId, [ref]$parsedBrowserId)) { Throw-LabFailure 'The CDP Browser ID was invalid.' }
  $result.BrowserIdValidation = 'PASS'

  $targets = @(Invoke-RestMethod -Uri "$baseUri/json/list" -TimeoutSec 3 -MaximumRedirection 0 | ForEach-Object { $_ })
  $appTargets = @($targets | Where-Object { "$($_.type)" -eq 'page' -and "$($_.url)" -match '^app://' })
  if ($appTargets.Count -ne 1) { Throw-LabFailure 'No trustworthy app:// renderer target was found.' }
  $targetUri = Assert-LocalWebSocketUrl -Url "$($appTargets[0].webSocketDebuggerUrl)" -Port $port -PathPrefix '/devtools/page/'
  $result.RendererValidation = 'PASS'

  $socket = [System.Net.WebSockets.ClientWebSocket]::new()
  $connectCts = [System.Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds(5))
  try { [void]($socket.ConnectAsync($targetUri, $connectCts.Token).GetAwaiter().GetResult()) } finally { $connectCts.Dispose() }

  $structureReady = $false
    $glassSource = [System.IO.File]::ReadAllText((Join-Path $LabRoot 'glass.js'), [System.Text.Encoding]::UTF8)
  [void](Invoke-CdpValue -Socket $socket -Id 10 -Stage 'd4-load' -Expression $glassSource)
  $privacyExpression = if ($ContentReview) { 'false' } else { 'window.__codexD4Glass.safeScreenshot()' }
  $structureDeadline = (Get-Date).AddSeconds(30)
  do {
    $structure = Invoke-CdpValue -Socket $socket -Id 1 -Stage 'safe-host-structure' -Expression @'
(() => {
  const composer = document.querySelector('[data-codex-composer]');
  const composerStructurallyBlank = window.__codexD4Glass.safeScreenshot();
  return {
    privateContentPresent: Boolean(document.querySelector('[data-turn-key]')) || !composerStructurallyBlank,
    mainPresent: Boolean(document.querySelector('main[data-app-shell-main-surface]')),
    sidebarPresent: Boolean(document.querySelector('[data-app-action-sidebar-scroll]')),
    composerRootPresent: Boolean(document.querySelector('[data-codex-composer-root]')),
    composerPresent: Boolean(composer)
  };
})()
'@
    $result.RuntimeEvaluate = 'PASS'
    if ($structure.mainPresent -and $structure.sidebarPresent -and $structure.composerRootPresent) { $structureReady = $true; break }
    Start-Sleep -Milliseconds 250
  } while ((Get-Date) -lt $structureDeadline)

  if (-not $structureReady) { Throw-LabFailure 'The real Codex main surface, sidebar, and composer root did not appear before timeout.' }
  if ($SequenceReview) {
    $nativeContent = Invoke-CdpValue -Socket $socket -Id 31 -Stage 'd6-optional-native-content' -Expression 'window.__codexD4Glass.applyNativeContent()'
    $result.NativeContent = $nativeContent.status
    if ($nativeContent.status -eq 'APPLIED' -and -not $nativeContent.geometryUnchanged) { Throw-LabFailure 'D6: native content geometry changed.' }
  } elseif ($ContentReview) {
    Write-Host 'D5: Open an existing completed local task in the lab window within 90 seconds. Do not send a message. Screenshots are disabled.'
    $contentDeadline = (Get-Date).AddSeconds(90)
    do {
      $nativeContent = Invoke-CdpValue -Socket $socket -Id 31 -Stage 'd5-native-content' -Expression 'window.__codexD4Glass.applyNativeContent()'
      if ($nativeContent.status -eq 'APPLIED') { break }
      Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $contentDeadline)
    $result.NativeContent = $nativeContent.status
    [System.IO.File]::WriteAllText((Join-Path $RunRoot 'D5_STRUCTURE.json'), ($nativeContent | ConvertTo-Json -Depth 15), [System.Text.UTF8Encoding]::new($false))
    if ($nativeContent.status -ne 'APPLIED') { Throw-LabFailure 'D5: no supported visible final assistant block appeared before timeout.' }
    if (-not $nativeContent.geometryUnchanged) { Throw-LabFailure 'D5: native content geometry changed.' }
  }


  $visualExpression = @"
(async () => {
  document.getElementById('codex-skin-debug-overlay')?.remove();
  const previousRoot = document.getElementById('codex-skin-root');
  const previousUrl = previousRoot?.dataset.codexSkinObjectUrl;
  previousRoot?.remove();
  if (previousUrl) URL.revokeObjectURL(previousUrl);
  const binary = atob('$assetBase64');
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) bytes[index] = binary.charCodeAt(index);
  const blob = new Blob([bytes], { type: 'image/png' });
  const objectUrl = URL.createObjectURL(blob);
  const root = document.createElement('div');
  root.id = 'codex-skin-root';
  root.setAttribute('aria-hidden', 'true');
  root.dataset.codexSkinObjectUrl = objectUrl;
  root.style.cssText = 'position:fixed;inset:0;pointer-events:none;user-select:none;overflow:hidden;';
  const image = document.createElement('img');
  image.id = 'codex-skin-l1';
  image.alt = '';
  image.style.cssText = 'display:block;width:100%;height:100%;object-fit:cover;pointer-events:none;';
  root.appendChild(image);
  document.body.prepend(root);
  await new Promise((resolve, reject) => {
    image.addEventListener('load', resolve, { once: true });
    image.addEventListener('error', reject, { once: true });
    image.src = objectUrl;
  });
  const rootRect = root.getBoundingClientRect();
  const imageRect = image.getBoundingClientRect();
  const rootStyle = getComputedStyle(root);
  const imageStyle = getComputedStyle(image);
  const shells = document.querySelectorAll('main[data-app-shell-main-surface]');
  const shell = shells[0];
  if (shells.length !== 1) throw new Error('Expected exactly one main[data-app-shell-main-surface].');
  const shellRect = shell?.getBoundingClientRect();
  const before = getComputedStyle(shell);
  const beforeValues = {
    background: before.background,
    backgroundColor: before.backgroundColor,
    backgroundImage: before.backgroundImage,
    opacity: before.opacity,
    boxShadow: before.boxShadow,
    backdropFilter: before.backdropFilter || before.webkitBackdropFilter || 'none'
  };
  if (beforeValues.backgroundImage !== 'none') throw new Error('Main background-image is not none; D4 has no evidence authorizing an image override.');
  document.getElementById('codex-d4-surface-override')?.remove();
  const override = document.createElement('style');
  override.id = 'codex-d4-surface-override';
  override.setAttribute('aria-hidden', 'true');
  override.dataset.mainHadInlineStyle = shell.hasAttribute('style') ? 'true' : 'false';
  override.dataset.mainInlineStyle = shell.getAttribute('style') || '';
  override.dataset.beforeBackground = beforeValues.background;
  override.dataset.beforeBackgroundColor = beforeValues.backgroundColor;
  override.dataset.beforeBackgroundImage = beforeValues.backgroundImage;
  override.dataset.beforeOpacity = beforeValues.opacity;
  override.dataset.beforeBoxShadow = beforeValues.boxShadow;
  override.dataset.beforeBackdropFilter = beforeValues.backdropFilter;
  document.head.appendChild(override);
  override.sheet.insertRule('main[data-app-shell-main-surface]{background:transparent !important;background-color:transparent !important;}', 0);
  await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  const after = getComputedStyle(shell);
  const afterValues = {
    background: after.background,
    backgroundColor: after.backgroundColor,
    backgroundImage: after.backgroundImage,
    opacity: after.opacity,
    boxShadow: after.boxShadow,
    backdropFilter: after.backdropFilter || after.webkitBackdropFilter || 'none'
  };
  const beforeWhite = beforeValues.backgroundColor === 'rgb(255, 255, 255)' || beforeValues.backgroundColor === 'rgba(255, 255, 255, 1)';
  const transparent = afterValues.backgroundColor === 'transparent' || /rgba\([^)]*,\s*0(?:\.0+)?\s*\)/.test(afterValues.backgroundColor) || /\/\s*0(?:\.0+)?\s*\)/.test(afterValues.backgroundColor);
  return {
    blobUrl: objectUrl.startsWith('blob:'),
    rootPresent: document.getElementById('codex-skin-root') === root,
    imageLoaded: image.complete && image.naturalWidth > 0 && image.naturalHeight > 0,
    naturalWidth: image.naturalWidth,
    naturalHeight: image.naturalHeight,
    viewportWidth: innerWidth,
    viewportHeight: innerHeight,
    rootLeft: rootRect.left,
    rootTop: rootRect.top,
    rootWidth: rootRect.width,
    rootHeight: rootRect.height,
    imageLeft: imageRect.left,
    imageTop: imageRect.top,
    imageWidth: imageRect.width,
    imageHeight: imageRect.height,
    rootPointerEvents: rootStyle.pointerEvents,
    imagePointerEvents: imageStyle.pointerEvents,
    horizontalOverflow: document.documentElement.scrollWidth > document.documentElement.clientWidth,
    shellCount: shells.length,
    shellPresent: Boolean(shell),
    shellLeft: shellRect.left,
    shellTop: shellRect.top,
    shellWidth: shellRect.width,
    shellHeight: shellRect.height,
    before: beforeValues,
    after: afterValues,
    mainBeforeWhite: beforeWhite,
    mainTransparent: transparent,
    nonBackgroundPropertiesUnchanged: afterValues.backgroundImage === beforeValues.backgroundImage && afterValues.opacity === beforeValues.opacity && afterValues.boxShadow === beforeValues.boxShadow && afterValues.backdropFilter === beforeValues.backdropFilter
  };
})()
"@
    $observed = Invoke-CdpValue -Socket $socket -Id 2 -Stage 'l1-visual-injection' -Expression $visualExpression
    $result.ShellSanity = if ($observed.shellPresent -and [int]$observed.shellCount -eq 1) { 'PASS' } else { 'FAIL' }
    $result.MainSelectorMatched = $result.ShellSanity
    $result.BlobObjectUrl = if ($observed.blobUrl) { 'PASS' } else { 'FAIL' }
    $result.VisualRoot = if ($observed.rootPresent) { 'PASS' } else { 'FAIL' }
    $result.ImageLoaded = if ($observed.imageLoaded) { 'PASS' } else { 'FAIL' }
    $result.ImageNaturalSize = "$($observed.naturalWidth)x$($observed.naturalHeight)"
    $result.ViewportRect = "0,0,$($observed.viewportWidth),$($observed.viewportHeight)"
    $result.RootRect = "$($observed.rootLeft),$($observed.rootTop),$($observed.rootWidth),$($observed.rootHeight)"
    $result.ImageRect = "$($observed.imageLeft),$($observed.imageTop),$($observed.imageWidth),$($observed.imageHeight)"
    $result.RootPointerEvents = "$($observed.rootPointerEvents)"
    $result.ImagePointerEvents = "$($observed.imagePointerEvents)"
    $geometryPass = [math]::Abs([double]$observed.rootLeft) -le 1 -and [math]::Abs([double]$observed.rootTop) -le 1 -and [math]::Abs([double]$observed.rootWidth - [double]$observed.viewportWidth) -le 1 -and [math]::Abs([double]$observed.rootHeight - [double]$observed.viewportHeight) -le 1 -and [math]::Abs([double]$observed.imageLeft) -le 1 -and [math]::Abs([double]$observed.imageTop) -le 1 -and [math]::Abs([double]$observed.imageWidth - [double]$observed.viewportWidth) -le 1 -and [math]::Abs([double]$observed.imageHeight - [double]$observed.viewportHeight) -le 1
    $result.Geometry = if ($geometryPass) { 'PASS' } else { 'FAIL' }
    $result.HorizontalOverflow = if (-not $observed.horizontalOverflow) { 'PASS' } else { 'FAIL' }
    $result.MainSurfaceRect = "$($observed.shellLeft),$($observed.shellTop),$($observed.shellWidth),$($observed.shellHeight)"
    $result.MainBackgroundBefore = "$($observed.before.background)"
    $result.MainBackgroundColorBefore = "$($observed.before.backgroundColor)"
    $result.MainBackgroundImageBefore = "$($observed.before.backgroundImage)"
    $result.BackgroundImageOverride = 'NOT_NEEDED'
    $result.MainOpacityBefore = "$($observed.before.opacity)"
    $result.MainBoxShadowBefore = "$($observed.before.boxShadow)"
    $result.MainBackdropFilterBefore = "$($observed.before.backdropFilter)"
    $result.MainBackgroundBeforeWhite = if ($observed.mainBeforeWhite) { 'PASS' } else { 'FAIL' }
    $result.MainBackgroundAfter = "$($observed.after.background)"
    $result.MainBackgroundColorAfter = "$($observed.after.backgroundColor)"
    $result.MainBackgroundImageAfter = "$($observed.after.backgroundImage)"
    $result.MainOpacityAfter = "$($observed.after.opacity)"
    $result.MainBoxShadowAfter = "$($observed.after.boxShadow)"
    $result.MainBackdropFilterAfter = "$($observed.after.backdropFilter)"
    $result.MainBackgroundTransparent = if ($observed.mainTransparent) { 'PASS' } else { 'FAIL' }
    $result.NonBackgroundPropertiesUnchanged = if ($observed.nonBackgroundPropertiesUnchanged) { 'PASS' } else { 'FAIL' }

  $surfaceEvidence = Invoke-CdpValue -Socket $socket -Id 3 -Stage 'd4-surface-validation' -Expression @'
(() => {
  const main = document.querySelector('main[data-app-shell-main-surface]');
  const sidebar = document.querySelector('[data-app-action-sidebar-scroll]');
  const composerRoot = document.querySelector('[data-codex-composer-root]');
  const viewportArea = Math.max(1, innerWidth * innerHeight);
  const round = value => Math.round(value * 100) / 100;
  const rectText = element => {
    if (!element) return 'NOT_FOUND';
    const rect = element.getBoundingClientRect();
    return [round(rect.left), round(rect.top), round(rect.width), round(rect.height)].join(',');
  };
  const visible = element => {
    if (!element) return false;
    const rect = element.getBoundingClientRect();
    const style = getComputedStyle(element);
    return rect.width > 0 && rect.height > 0 && style.display !== 'none' && style.visibility === 'visible';
  };
  const alphaOf = color => {
    if (!color || color === 'transparent') return 0;
    const slashAlpha = color.match(/\/\s*([\d.]+)%?\s*\)/);
    if (slashAlpha) return color.includes('%') ? Number(slashAlpha[1]) / 100 : Number(slashAlpha[1]);
    const values = color.match(/[\d.]+/g)?.map(Number) || [];
    return values.length >= 4 ? values[3] : values.length >= 3 ? 1 : 0;
  };
  const coverageOf = element => {
    const rect = element.getBoundingClientRect();
    const width = Math.max(0, Math.min(innerWidth, rect.right) - Math.max(0, rect.left));
    const height = Math.max(0, Math.min(innerHeight, rect.bottom) - Math.max(0, rect.top));
    return round(width * height * 100 / viewportArea);
  };
  const anchorOf = element => {
    const parts = [];
    for (let n = element; n && n !== main; n = n.parentElement) {
      parts.unshift(n.localName + ':nth-child(' + ([...n.parentElement.children].indexOf(n) + 1) + ')');
    }
    return 'main[data-app-shell-main-surface] > ' + parts.join(' > ');
  };
  const blockers = [...main.querySelectorAll('*')].map(element => {
    const style = getComputedStyle(element);
    return { element, background: style.backgroundColor, opacity: Number.parseFloat(style.opacity || '1'), coverage: coverageOf(element), visible: visible(element) };
  }).filter(item => item.visible && item.coverage >= 25 && alphaOf(item.background) >= 0.99 && item.opacity >= 0.99)
    .sort((left, right) => right.coverage - left.coverage);
  const blocker = blockers[0];
  return {
    mainRect: rectText(main),
    sidebarRect: rectText(sidebar),
    composerRootRect: rectText(composerRoot),
    sidebarVisible: visible(sidebar),
    composerVisible: visible(composerRoot),
    remainingLargeOpaqueSurface: blocker ? anchorOf(blocker.element) + ' background=' + blocker.background + ' coverage=' + blocker.coverage + '%' : 'NONE',
    centralL1Visible: !blocker,
    horizontalOverflow: document.documentElement.scrollWidth > document.documentElement.clientWidth
  };
})()
'@
  $result.MainSurfaceRect = "$($surfaceEvidence.mainRect)"
  $result.SidebarRect = "$($surfaceEvidence.sidebarRect)"
  $result.ComposerRootRect = "$($surfaceEvidence.composerRootRect)"
  $result.SidebarVisible = if ($surfaceEvidence.sidebarVisible) { 'PASS' } else { 'FAIL' }
  $result.ComposerVisible = if ($surfaceEvidence.composerVisible) { 'PASS' } else { 'FAIL' }
  $result.RemainingLargeOpaqueSurface = "$($surfaceEvidence.remainingLargeOpaqueSurface)"
  $result.CentralL1Visibility = if ($surfaceEvidence.centralL1Visible -and $result.MainBackgroundTransparent -eq 'PASS') { 'PASS' } else { 'PARTIAL' }
  $result.HorizontalOverflow = if (-not $surfaceEvidence.horizontalOverflow) { 'PASS' } else { 'FAIL' }
  $result.ScreenshotSafety = if (-not (Invoke-CdpValue -Socket $socket -Id 4 -Stage 'd4-screenshot-privacy' -Expression $privacyExpression)) { 'SKIPPED_PRIVACY' } else { 'PASS' }

  $visualRequired = @($result.ShellSanity, $result.MainSelectorMatched, $result.MainBackgroundTransparent, $result.NonBackgroundPropertiesUnchanged, $result.BlobObjectUrl, $result.VisualRoot, $result.ImageLoaded, $result.Geometry, $result.HorizontalOverflow, $result.SidebarVisible, $result.ComposerVisible)
  if (@($visualRequired | Where-Object { $_ -ne 'PASS' }).Count -gt 0 -or $result.RootPointerEvents -ne 'none' -or $result.ImagePointerEvents -ne 'none') { Throw-LabFailure 'D4 main override, L1 geometry, native surface visibility, pointer-events, or overflow validation failed.' }

  $glassEvidence = Invoke-CdpValue -Socket $socket -Id 11 -Stage 'd4-glass-material' -Expression 'window.__codexD4Glass.apply()'
  [System.IO.File]::WriteAllText((Join-Path $RunRoot 'D4_STRUCTURE.json'), ($glassEvidence | ConvertTo-Json -Depth 15), [System.Text.UTF8Encoding]::new($false))
  $applicableChecks = @($glassEvidence.pendingChecks | Where-Object { -not $ContentReview -or $_ -notin @('headline', 'composerContext', 'contentSample', 'homeIcon') })
  $result.PendingMaterialChecks = if ($applicableChecks.Count -eq 0) { 'NONE' } else { $applicableChecks -join ', ' }
  $result.GlassLab = if ($ContentReview) { if ($result.NativeContent -eq 'APPLIED' -and -not $glassEvidence.horizontalOverflow) { 'NATIVE_CONTENT_APPLIED' } else { 'PARTIAL' } } elseif ($glassEvidence.headline.status -eq 'MATCHED' -and $glassEvidence.composer.status -eq 'APPLIED' -and
    $glassEvidence.island.mode -eq 'LOCAL_SAMPLE_NOT_NATIVE_MESSAGE' -and -not $glassEvidence.horizontalOverflow) { 'MATERIAL_APPLIED' } else { 'PARTIAL' }
  $result.ScreenshotSafety = if (-not (Invoke-CdpValue -Socket $socket -Id 12 -Stage 'd4-final-privacy' -Expression $privacyExpression)) { 'SKIPPED_PRIVACY' } else { 'PASS' }

  if ($result.ScreenshotSafety -ne 'PASS') {
    $result.FullHostScreenshot = 'SKIPPED_PRIVACY'
    $result.DebugBoundaryScreenshot = 'SKIPPED_PRIVACY'
  } else {
    $result.FullHostScreenshot = if (Save-CdpScreenshot -Socket $socket -Id 5 -Path $FullHostScreenshotPath) { 'PASS' } else { 'FAIL' }
    if ($result.FullHostScreenshot -ne 'PASS') { Throw-LabFailure 'The D4 full-host screenshot was not saved.' }

    $debugSafety = Invoke-CdpValue -Socket $socket -Id 6 -Stage 'd4-debug-screenshot-privacy' -Expression $privacyExpression
    if (-not $debugSafety) {
      $result.ScreenshotSafety = 'SKIPPED_PRIVACY'
      $result.DebugBoundaryScreenshot = 'SKIPPED_PRIVACY'
    } else {
      $overlay = Invoke-CdpValue -Socket $socket -Id 7 -Stage 'd4-debug-boundary-overlay' -Expression @'
(() => {
  document.getElementById('codex-skin-debug-overlay')?.remove();
  const overlay = document.createElement('div');
  overlay.id = 'codex-skin-debug-overlay';
  overlay.setAttribute('aria-hidden', 'true');
  overlay.style.cssText = 'position:fixed;inset:0;pointer-events:none;z-index:2147483647;overflow:hidden;';
  const targets = [
    document.getElementById('codex-skin-root'),
    document.querySelector('main[data-app-shell-main-surface]'),
    document.querySelector('[data-codex-composer-root]'),
    document.querySelector('[data-app-action-sidebar-scroll]'),
    ...window.__codexD4Glass.boundaries()
  ].filter(Boolean);
  const colors = ['#ff2d55', '#00e5ff', '#30d158', '#ffd60a'];
  targets.forEach((target, index) => {
    const rect = target.getBoundingClientRect();
    const box = document.createElement('div');
    box.setAttribute('aria-hidden', 'true');
    box.style.cssText = 'position:fixed;pointer-events:none;box-sizing:border-box;background:transparent;outline:2px solid ' + colors[index % colors.length] + ';outline-offset:-2px;left:' + rect.left + 'px;top:' + rect.top + 'px;width:' + rect.width + 'px;height:' + rect.height + 'px;';
    overlay.appendChild(box);
  });
  document.body.appendChild(overlay);
  const style = getComputedStyle(overlay);
  return { present: document.getElementById('codex-skin-debug-overlay') === overlay, pointerEvents: style.pointerEvents, position: style.position, boxCount: overlay.children.length };
})()
'@
      if (-not $overlay.present -or $overlay.pointerEvents -ne 'none' -or $overlay.position -ne 'fixed' -or [int]$overlay.boxCount -lt 4) { Throw-LabFailure 'The label-less D4 debug boundary rectangles did not validate.' }
      try {
        $result.DebugBoundaryScreenshot = if (Save-CdpScreenshot -Socket $socket -Id 8 -Path $DebugScreenshotPath) { 'PASS' } else { 'FAIL' }
      } finally {
        $overlayAbsent = Invoke-CdpValue -Socket $socket -Id 9 -Stage 'd4-debug-boundary-removal' -Expression "document.getElementById('codex-skin-debug-overlay')?.remove(); document.getElementById('codex-skin-debug-overlay') === null"
        $result.DebugOverlayImmediateRemoval = if ($overlayAbsent) { 'PASS' } else { 'FAIL' }
      }
      if ($result.DebugBoundaryScreenshot -ne 'PASS' -or $result.DebugOverlayImmediateRemoval -ne 'PASS') { Throw-LabFailure 'The D4 debug boundary screenshot or immediate overlay removal failed.' }
    }
  }
  if ($ContentReview) {
    [void](Invoke-CdpValue -Socket $socket -Id 33 -Stage 'd5-start-content-tracking' -Expression 'window.__codexD4Glass.startNativeContentTracking()')
    if ($SequenceReview) {
      Mount-Sequence -Socket $socket -Source ([System.IO.File]::ReadAllText($sequenceBundle))
      Write-Host 'D6: session stays open. Use L1-L6, slider, EX and Return. Click the End Skin button to clean up and restore ordinary Codex. Screenshots remain disabled.'
      $sequenceEvidence = $null
      do {
        Start-Sleep -Seconds 2
        try {
          $sequenceEvidence = Invoke-CdpValue -Socket $socket -Id 41 -Stage 'd6-sequence-evidence' -Expression 'window.__codexSequence.status()'
        } catch {
          $sequenceEvidence = Repair-SequenceConnection
        }
      } until (($sequenceEvidence.stopRequested -or ($StopRequestPath -and (Test-Path -LiteralPath $StopRequestPath))) -and -not $sequenceEvidence.busy)
      [System.IO.File]::WriteAllText((Join-Path $RunRoot 'D6_STRUCTURE.json'), ($sequenceEvidence | ConvertTo-Json -Depth 15), [System.Text.UTF8Encoding]::new($false))
      $result.Sequence = if ($sequenceEvidence.ready -and @($sequenceEvidence.visited).Count -eq 6 -and $sequenceEvidence.exSeen -and $sequenceEvidence.videoPlayed -and -not $sequenceEvidence.busy -and $sequenceEvidence.phase -eq 'mainline') { 'ALL_LEVELS_VIDEO_AND_RETURN_REVIEWED' } else { 'PARTIAL' }
    } else {
      Write-Host 'D5: scroll the existing completed task for 20 seconds. Leave a final assistant reply visible. No screenshot will be saved.'
      Start-Sleep -Seconds 20
    }
    $nativeContent = Invoke-CdpValue -Socket $socket -Id 32 -Stage 'd5-final-target-check' -Expression 'window.__codexD4Glass.refreshNativeContent()'
    $result.NativeContent = $nativeContent.status
    [System.IO.File]::WriteAllText((Join-Path $RunRoot 'D5_STRUCTURE.json'), ($nativeContent | ConvertTo-Json -Depth 15), [System.Text.UTF8Encoding]::new($false))
    Assert-FinalNativeContent -Evidence $nativeContent -AllowNoVisibleTarget:$SequenceReview
    if ($SequenceReview -and $nativeContent.status -eq 'NOT_FOUND') {
      $result.PendingMaterialChecks = if ($result.PendingMaterialChecks -eq 'NONE') { 'nativeContentVisibleAtEnd' } else { $result.PendingMaterialChecks + ', nativeContentVisibleAtEnd' }
    }
  }
  $result.FailureReason = 'NONE'
} catch {
  $result.FailureReason = $_.Exception.Message
} finally {
  if ($socket) {
    try {
      if ($socket.State -ne [System.Net.WebSockets.WebSocketState]::Open) {
        $result.CleanupReconnect = 'FAIL'
        # Reconnect only to the same validated renderer, for cleanup only. Never replay injection.
        $connections = @(Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction Stop)
        $cleanupOwner = Assert-LoopbackListenerOwner -Connections $connections -Install $codex
        $cleanupProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$cleanupOwner" -ErrorAction Stop
        if ($cleanupOwner -ne $sessionIdentity.ProcessId -or $cleanupProcess.CreationDate -ne $sessionIdentity.CreationDate) { Throw-LabFailure 'Cleanup reconnect owner identity changed.' }
        $cleanupTargets = @(Invoke-RestMethod -Uri "$baseUri/json/list" -TimeoutSec 3 -MaximumRedirection 0 | ForEach-Object { $_ })
        # Debug endpoint identities only; never persist page titles or application URL paths.
        $targetEvidence = @($cleanupTargets | ForEach-Object {
          [pscustomobject]@{ type = "$($_.type)"; appPage = "$($_.url)" -match '^app://';
            sameEndpoint = [bool]($_.PSObject.Properties['webSocketDebuggerUrl'] -and "$($_.webSocketDebuggerUrl)" -eq $targetUri.AbsoluteUri) }
        })
        [System.IO.File]::WriteAllText((Join-Path $RunRoot 'CLEANUP_TARGETS.json'), (ConvertTo-Json -InputObject @($targetEvidence) -Compress), [System.Text.UTF8Encoding]::new($false))
        $sameTarget = @($cleanupTargets | Where-Object { $_.PSObject.Properties['webSocketDebuggerUrl'] -and "$($_.webSocketDebuggerUrl)" -eq $targetUri.AbsoluteUri -and "$($_.type)" -eq 'page' -and "$($_.url)" -match '^app://' })
        if ($sameTarget.Count -ne 1) { Throw-LabFailure 'Cleanup reconnect renderer identity changed.' }
        $socket.Dispose()
        $socket = [System.Net.WebSockets.ClientWebSocket]::new()
        $cleanupCts = [System.Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds(5))
        try { [void]($socket.ConnectAsync($targetUri, $cleanupCts.Token).GetAwaiter().GetResult()) } finally { $cleanupCts.Dispose() }
        $result.CleanupReconnect = 'PASS'
      }
      $cleanup = Invoke-CdpValue -Socket $socket -Id 99 -Stage 'visual-cleanup' -Expression @'
(async () => {
  const sequence = window.__codexSequence?.cleanup() || { removed: true, frames: 0, objectUrls: 0 };
  delete window.__codexSequenceTransfer;
  const glass = window.__codexD4Glass?.cleanup() || { restored: true, sampleRemoved: true };
  document.getElementById('codex-skin-debug-overlay')?.remove();
  const override = document.getElementById('codex-d4-surface-override');
  const main = document.querySelector('main[data-app-shell-main-surface]');
  const hadInlineStyle = override?.dataset.mainHadInlineStyle === 'true';
  const inlineStyleBefore = override?.dataset.mainInlineStyle || '';
  const computedBefore = override ? {
    background: override.dataset.beforeBackground,
    backgroundColor: override.dataset.beforeBackgroundColor,
    backgroundImage: override.dataset.beforeBackgroundImage,
    opacity: override.dataset.beforeOpacity,
    boxShadow: override.dataset.beforeBoxShadow,
    backdropFilter: override.dataset.beforeBackdropFilter
  } : null;
  override?.remove();
  // getComputedStyle below resolves styles synchronously; cleanup must not depend on a visible frame.
  const inlineStyleRestored = !override || Boolean(main && (hadInlineStyle ? main.getAttribute('style') === inlineStyleBefore : !main.hasAttribute('style')));
  const restored = main ? getComputedStyle(main) : null;
  const computedStyleRestored = !override || Boolean(restored && restored.background === computedBefore.background && restored.backgroundColor === computedBefore.backgroundColor && restored.backgroundImage === computedBefore.backgroundImage && restored.opacity === computedBefore.opacity && restored.boxShadow === computedBefore.boxShadow && (restored.backdropFilter || restored.webkitBackdropFilter || 'none') === computedBefore.backdropFilter);
  const root = document.getElementById('codex-skin-root');
  const objectUrl = root?.dataset.codexSkinObjectUrl || null;
  root?.remove();
  let revoked = objectUrl === null;
  if (objectUrl) {
    URL.revokeObjectURL(objectUrl);
    try { await fetch(objectUrl); } catch { revoked = true; }
  }
  return {
    glassRestored: glass.restored && glass.sampleRemoved,
    sequenceRemoved: sequence.removed && sequence.frames === 0 && sequence.objectUrls === 0,
    overlayRemoved: document.getElementById('codex-skin-debug-overlay') === null,
    overrideStyleRemoved: document.getElementById('codex-d4-surface-override') === null,
    mainInlineStyleRestored: inlineStyleRestored,
    mainComputedStyleRestored: computedStyleRestored,
    rootRemoved: document.getElementById('codex-skin-root') === null,
    objectUrlRevoked: revoked
  };
})()
'@
      $result.GlassCleanup = if ($cleanup.glassRestored) { 'PASS' } else { 'FAIL' }
      $result.DebugOverlayRemoval = if ($cleanup.overlayRemoved) { 'PASS' } else { 'FAIL' }
      $result.SequenceCleanup = if ($cleanup.sequenceRemoved) { 'PASS' } else { 'FAIL' }
      $result.OverrideStyleRemoved = if ($cleanup.overrideStyleRemoved) { 'PASS' } else { 'FAIL' }
      $result.MainInlineStyleRestored = if ($cleanup.mainInlineStyleRestored) { 'PASS' } else { 'FAIL' }
      $result.MainComputedStyleRestored = if ($cleanup.mainComputedStyleRestored) { 'PASS' } else { 'FAIL' }
      $result.RootRemoval = if ($cleanup.rootRemoved) { 'PASS' } else { 'FAIL' }
      $result.ObjectUrlRevoke = if ($cleanup.objectUrlRevoked) { 'PASS' } else { 'FAIL' }
    } catch {
      $result.GlassCleanup = 'FAIL'
      $result.DebugOverlayRemoval = 'FAIL'
      $result.OverrideStyleRemoved = 'FAIL'
      $result.MainInlineStyleRestored = 'FAIL'
      $result.MainComputedStyleRestored = 'FAIL'
      $result.RootRemoval = 'FAIL'
      $result.ObjectUrlRevoke = 'FAIL'
      $result.FailureReason = "$($result.FailureReason); visual cleanup failed: $($_.Exception.Message)"
    }
    try { $socket.Dispose() } catch { }
  }

  if ($launchAttempted -and $codex) {
    try {
      $stopped = Stop-ValidatedCodexProcesses -Install $codex
      $result.DebugCleanup = if ($stopped) { 'PASS' } else { 'FAIL' }
    } catch {
      $stopped = $false
      $result.DebugCleanup = 'FAIL'
      $result.FailureReason = "$($result.FailureReason); debug cleanup failed: $($_.Exception.Message)"
    }
    if ($port) { $result.PortClosed = if (Wait-ForPortClosed -Port $port) { 'PASS' } else { 'FAIL' } }
    if ($stopped -and $result.PortClosed -eq 'PASS') {
      try { $result.ProfileRemoved = if (Remove-LabProfile -Path $profilePath) { 'PASS' } else { 'FAIL' } } catch { $result.ProfileRemoved = 'FAIL'; $result.FailureReason = "$($result.FailureReason); profile cleanup failed: $($_.Exception.Message)" }
      try {
        $current = Get-ValidatedCodexInstall
        if ($current.PackageFullName -cne $codex.PackageFullName) { throw 'Codex package changed during the lab.' }
        if (@(Get-CodexProcesses -Install $current).Count -eq 0) { [void](Start-PackageCodex -Install $current -Arguments @()) }
        $restoreDeadline = (Get-Date).AddSeconds(15)
        do { if (@(Get-CodexProcesses -Install $current).Count -gt 0) { $result.OrdinaryCodexRestored = 'PASS'; break }; Start-Sleep -Milliseconds 250 } while ((Get-Date) -lt $restoreDeadline)
        if ($result.OrdinaryCodexRestored -ne 'PASS') { $result.OrdinaryCodexRestored = 'FAIL' }
      } catch {
        $result.OrdinaryCodexRestored = 'FAIL'
        $result.FailureReason = "$($result.FailureReason); ordinary Codex restore failed: $($_.Exception.Message)"
      }
    } else {
      $result.ProfileRemoved = 'NOT_REMOVED_PROCESS_STILL_RUNNING'
      $result.OrdinaryCodexRestored = 'FAIL'
    }
  }

  $lifecycleRequired = @(
    $result.OfficialCodexValidation, $result.L1AssetHash,
    $(if ($SequenceReview) { $result.CoreBaselineValidation } else { $result.ProjectCommitValidation; $result.ProjectStatusValidation }),
    $result.Listener, $result.OwnerValidation, $result.BrowserIdValidation, $result.RendererValidation, $result.RuntimeEvaluate,
    $result.DebugOverlayRemoval, $result.OverrideStyleRemoved, $result.MainInlineStyleRestored, $result.MainComputedStyleRestored,
    $result.GlassCleanup, $result.RootRemoval, $result.ObjectUrlRevoke, $result.DebugCleanup, $result.PortClosed, $result.ProfileRemoved, $result.OrdinaryCodexRestored
  )
  $experimentRequired = @(
    $result.ShellSanity, $result.MainSelectorMatched, $result.MainBackgroundTransparent, $result.NonBackgroundPropertiesUnchanged,
    $result.BlobObjectUrl, $result.VisualRoot, $result.ImageLoaded, $result.Geometry, $result.HorizontalOverflow,
    $result.SidebarVisible, $result.ComposerVisible
  )
  $screenshotsAccepted = (@('PASS', 'SKIPPED_PRIVACY') -contains $result.FullHostScreenshot) -and (@('PASS', 'SKIPPED_PRIVACY') -contains $result.DebugBoundaryScreenshot)
  $immediateOverlayAccepted = $result.DebugBoundaryScreenshot -eq 'SKIPPED_PRIVACY' -or $result.DebugOverlayImmediateRemoval -eq 'PASS'
  $basePassed = @($lifecycleRequired | Where-Object { $_ -ne 'PASS' }).Count -eq 0 -and @($experimentRequired | Where-Object { $_ -ne 'PASS' }).Count -eq 0 -and $result.RootPointerEvents -eq 'none' -and $result.ImagePointerEvents -eq 'none' -and $result.NativeBusinessLogic -eq 'UNTOUCHED' -and $screenshotsAccepted -and $immediateOverlayAccepted
  $basePassed = $basePassed -and $result.FailureReason -eq 'NONE'
  if ($basePassed -and $result.CentralL1Visibility -eq 'PASS') {
    $result.Classification = 'D4_GLASS_PARTIAL'
    if ($result.PendingMaterialChecks -eq 'NONE' -and $glassEvidence.composerContext.status -eq 'APPLIED' -and $result.GlassLab -eq 'MATERIAL_APPLIED' -and $result.FullHostScreenshot -eq 'PASS' -and $result.DebugBoundaryScreenshot -eq 'PASS' -and $glassEvidence.topStrip.status -eq 'DECORATIVE_BACKGROUND_CLEARED_NEEDS_VISUAL_REVIEW') { $result.Classification = 'D4_GLASS_READY_FOR_REVIEW' }
    $result.FailureReason = 'NONE'
  } elseif ($basePassed -and $result.CentralL1Visibility -eq 'PARTIAL') {
    $result.Classification = 'D4_GLASS_PARTIAL'
    $result.FailureReason = 'NONE'
  } elseif ($result.FailureReason -eq 'NONE') {
    $result.FailureReason = 'One or more required D4 experiment or cleanup checks failed.'
  }
  if ($ContentReview) {
    $result.Classification = if ($basePassed -and $result.NativeContent -eq 'APPLIED' -and $result.GlassCleanup -eq 'PASS') { 'D5_CONTENT_APPLIED_PENDING_REVIEW' } else { 'D5_CONTENT_FAILED' }
  }
  if ($SequenceReview) {
    $result.Classification = if ($basePassed -and $result.GlassCleanup -eq 'PASS' -and $result.NativeContent -in @('APPLIED', 'NOT_FOUND') -and $result.SequenceCleanup -eq 'PASS' -and $result.Sequence -in @('ALL_LEVELS_VIDEO_AND_RETURN_REVIEWED', 'PARTIAL')) {
      if ($result.Sequence -eq 'ALL_LEVELS_VIDEO_AND_RETURN_REVIEWED' -and $result.NativeContent -eq 'APPLIED' -and $result.PendingMaterialChecks -eq 'NONE') { 'D6_SEQUENCE_READY_FOR_REVIEW' } else { 'D6_SEQUENCE_PARTIAL' }
    } else { 'D6_SEQUENCE_FAILED' }
  }
  Write-LabResult
}

Write-Host ''
Write-Host $result.Classification
Write-Host "Result: $ResultPath"
Write-Host "Pending material checks: $($result.PendingMaterialChecks)"
if ($result.FullHostScreenshot -eq 'PASS') { Write-Host "Full host: $FullHostScreenshotPath" }
if ($result.DebugBoundaryScreenshot -eq 'PASS') { Write-Host "Debug boundaries: $DebugScreenshotPath" }
if ($result.Classification -in @('D4_GLASS_READY_FOR_REVIEW', 'D4_GLASS_PARTIAL', 'D5_CONTENT_APPLIED_PENDING_REVIEW', 'D6_SEQUENCE_READY_FOR_REVIEW', 'D6_SEQUENCE_PARTIAL')) { exit 0 }
exit 3
