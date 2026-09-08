[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
$picker = New-Object System.Windows.Forms.OpenFileDialog
$picker.Title = '选择皮肤文件夹中的 skin.json'
$picker.Filter = '皮肤配置 (skin.json)|skin.json'
$picker.InitialDirectory = Join-Path $PSScriptRoot 'skins'
try {
  if ($picker.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { exit 0 }
  $selectedSkin = Split-Path -Parent $picker.FileName
} finally { $picker.Dispose() }
& (Join-Path $PSScriptRoot 'glass-lab.ps1') -SequenceReview -DisableGpu -SkinDirectory $selectedSkin
