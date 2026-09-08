[CmdletBinding()]
param([string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'CodexSlideEvolutionSkin'), [string]$ZipPath)
$ErrorActionPreference = 'Stop'; Add-Type -AssemblyName System.Windows.Forms
$zip = $ZipPath
if (-not $zip) { $picker = New-Object System.Windows.Forms.OpenFileDialog; $picker.Filter = '皮肤包 (*.zip)|*.zip'; $picker.Title = '选择皮肤 ZIP'; try { if ($picker.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { exit 0 }; $zip = $picker.FileName } finally { $picker.Dispose() } }
$staging = Join-Path ([IO.Path]::GetTempPath()) ('codex-skin-' + [Guid]::NewGuid().ToString('N')); New-Item -ItemType Directory -Path $staging | Out-Null
try {
  Expand-Archive -LiteralPath $zip -DestinationPath $staging -Force
  $configs = @(Get-ChildItem -LiteralPath $staging -Filter skin.json -File -Recurse)
  if ($configs.Count -ne 1) { throw 'ZIP must contain exactly one skin.json' }
  $pack = $configs[0].Directory.FullName; $target = Join-Path (Join-Path ([IO.Path]::GetFullPath($InstallRoot)) 'skins') $configs[0].BaseName
  $target = Join-Path (Join-Path ([IO.Path]::GetFullPath($InstallRoot)) 'skins') ((Get-Content $configs[0].FullName -Raw | ConvertFrom-Json).name -replace '[^\p{L}\p{N}_. -]','_')
  if (Test-Path -LiteralPath $target) { throw 'A skin with this name already exists.' }
  New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
  Copy-Item -LiteralPath $pack -Destination $target -Recurse
  & (Join-Path $InstallRoot 'vendor\node\node.exe') (Join-Path $InstallRoot 'skin-pack.js') validate $target
  if ($LASTEXITCODE) { throw 'Skin validation failed' }; Write-Output "Imported to $target"
} finally { if (Test-Path $staging) { Remove-Item $staging -Recurse -Force } }
