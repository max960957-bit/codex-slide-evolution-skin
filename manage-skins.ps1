[CmdletBinding()]
param([string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'CodexSlideEvolutionSkin'))
$ErrorActionPreference = 'Stop'; Add-Type -AssemblyName System.Windows.Forms
$skins = Join-Path $InstallRoot 'skins'; New-Item -ItemType Directory -Path $skins -Force | Out-Null
$form = New-Object Windows.Forms.Form; $form.Text = 'Codex 滑动变富器 · 皮肤管理'; $form.Width = 520; $form.Height = 390; $form.StartPosition = 'CenterScreen'
$list = New-Object Windows.Forms.ListBox; $list.Dock = 'Top'; $list.Height = 240
function Refresh-Skins { $list.Items.Clear(); Get-ChildItem -LiteralPath $skins -Directory | ForEach-Object { $cfg=Join-Path $_.FullName 'skin.json'; if(Test-Path $cfg){ try{$j=Get-Content $cfg -Raw | ConvertFrom-Json; [void]$list.Items.Add([pscustomobject]@{Label="$($j.name) · $($j.author)";Path=$_.FullName})}catch{ } } } }
$list.DisplayMember='Label'; Refresh-Skins; $form.Controls.Add($list)
$import = New-Object Windows.Forms.Button; $import.Text='导入 ZIP'; $import.Width=110; $import.Top=255; $import.Left=20
$import.Add_Click({ $importer=Join-Path $InstallRoot 'import-skin.ps1'; & powershell.exe -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File $importer; Refresh-Skins })
$start = New-Object Windows.Forms.Button; $start.Text='启动所选皮肤'; $start.Width=130; $start.Top=255; $start.Left=145
$start.Add_Click({ if(-not $list.SelectedItem){[Windows.Forms.MessageBox]::Show('请先选择皮肤。');return}; $form.Hide(); & (Join-Path $InstallRoot 'glass-lab.ps1') -SequenceReview -DisableGpu -SkinDirectory $list.SelectedItem.Path; $form.Close() })
$help = New-Object Windows.Forms.Label; $help.Text='请先保存工作并退出普通 Codex，再启动皮肤。'; $help.AutoSize=$true; $help.Top=310; $help.Left=20
$form.Controls.AddRange(@($import,$start,$help)); [void]$form.ShowDialog()
