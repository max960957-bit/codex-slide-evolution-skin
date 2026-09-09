[CmdletBinding()]
param([string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'CodexSlideEvolutionSkin'), [switch]$SelfTest, [string]$PanelTestOutput)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$form=New-Object Windows.Forms.Form
$form.Text='Codex 换肤 · 控制面板';$form.ClientSize=New-Object Drawing.Size(820,610);$form.StartPosition='CenterScreen'
$form.Font=New-Object Drawing.Font('Microsoft YaHei UI',10);$form.FormBorderStyle='FixedDialog';$form.MaximizeBox=$false
function Add-Control($type,$text,$x,$y,$w,$h){$c=New-Object ('Windows.Forms.'+$type);$c.Text=$text;$c.SetBounds($x,$y,$w,$h);$form.Controls.Add($c);return $c}
$title=Add-Control Label '选皮肤 → 启动 → 结束，全部在这里操作' 20 15 770 30
$status=Add-Control Label '正在检查环境…' 20 50 780 55
$list=Add-Control ListBox '' 20 115 260 245;$list.DisplayMember='Label'
$preview=Add-Control PictureBox '' 295 115 505 245;$preview.SizeMode='Zoom';$preview.BackColor=[Drawing.Color]::FromArgb(32,32,32)
$import=Add-Control Button '导入皮肤 ZIP' 20 375 145 38
$start=Add-Control Button '启动所选皮肤' 180 375 155 38
$stop=Add-Control Button '结束 / 取消等待' 350 375 165 38;$stop.Enabled=$false
$help=Add-Control Button '使用帮助' 530 375 125 38
$uninstall=Add-Control Button '卸载工具' 670 375 130 38
$details=Add-Control TextBox '' 20 430 780 160;$details.Multiline=$true;$details.ReadOnly=$true;$details.ScrollBars='Vertical'
$details.Text='首次使用已自动安装。点击启动后，面板会等待你保存工作并退出普通 Codex，然后自动继续。'
$script:worker=$null;$script:waiting=$false;$script:session=$null;$script:pendingSkin=$null
function Set-Busy($busy){$start.Enabled=-not $busy;$import.Enabled=-not $busy;$list.Enabled=-not $busy;$uninstall.Enabled=-not $busy;$stop.Enabled=$busy}
function Refresh-Skins {
 $list.Items.Clear()
 foreach($dir in @(Get-ChildItem -LiteralPath (Join-Path $InstallRoot 'skins') -Directory)){
  try{$cfg=Get-Content (Join-Path $dir.FullName 'skin.json') -Raw|ConvertFrom-Json;[void]$list.Items.Add([pscustomobject]@{Label=$cfg.name;Path=$dir.FullName;Config=$cfg})}catch{$details.Text="皮肤配置无法读取：$($dir.Name)"}
 }
 if($list.Items.Count){$list.SelectedIndex=0}
}
$list.Add_SelectedIndexChanged({
 if($preview.Image){$preview.Image.Dispose();$preview.Image=$null};if(-not $list.SelectedItem){return}
 try{
  $root=[IO.Path]::GetFullPath($list.SelectedItem.Path);$file=[IO.Path]::GetFullPath((Join-Path $root $list.SelectedItem.Config.levels[0]))
  if((Split-Path $file) -ne $root){throw 'Invalid preview path'}
  $img=[Drawing.Image]::FromFile($file);try{$preview.Image=New-Object Drawing.Bitmap($img)}finally{$img.Dispose()}
 }catch{$details.Text='无法预览此皮肤，请检查图片文件。'}
})
function Check-Environment {
 foreach($file in @('vendor\node\node.exe','glass-lab.ps1','skin-pack.js')){if(-not(Test-Path -LiteralPath (Join-Path $InstallRoot $file))){throw '安装文件缺失，请重新解压并双击启动换肤。'}}
 $pkg=Get-AppxPackage -Name OpenAI.Codex|Sort-Object Version -Descending|Select-Object -First 1
 if(-not $pkg){throw '未找到支持的 Codex 桌面应用。'}
 if("$($pkg.Version)" -ne '26.901.6511.0'){throw "当前 Codex $($pkg.Version)，本版支持 26.901.6511.0，需要适配后才能启动。"}
 $status.Text="工具已安装 · Codex $($pkg.Version) · 请选择皮肤并启动"
}
function Test-CodexUiRunning {
  return @(Get-CimInstance Win32_Process -Filter "Name='ChatGPT.exe'" -ErrorAction SilentlyContinue | Where-Object {
    $_.ExecutablePath -and $_.ExecutablePath -like '*WindowsApps*OpenAI.Codex*ChatGPT.exe'
  }).Count -gt 0
}
function Start-Session {
 $script:session=Join-Path $InstallRoot ('runtime\panel-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($script:session)
 $args=@('-NoLogo','-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',('"'+(Join-Path $InstallRoot 'glass-lab.ps1')+'"'),'-SequenceReview','-DisableGpu','-SkinDirectory',('"'+$script:pendingSkin+'"'),'-StopRequestPath',('"'+(Join-Path $script:session 'stop')+'"'))
 $script:worker=Start-Process powershell.exe -ArgumentList $args -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $script:session 'out.txt') -RedirectStandardError (Join-Path $script:session 'error.txt')
 $script:waiting=$false;$status.Text='正在启动和加载素材… 面板会保持打开。'
}
$start.Add_Click({
 try{
  Check-Environment;if(-not $list.SelectedItem){throw '请先导入或选择皮肤。'}
  $script:pendingSkin=$list.SelectedItem.Path
  $validation=& (Join-Path $InstallRoot 'vendor\node\node.exe') (Join-Path $InstallRoot 'skin-pack.js') validate $script:pendingSkin 2>&1
  if($LASTEXITCODE -ne 0){throw "皮肤校验失败：$validation"}
  Set-Busy $true;$script:waiting=$true;$status.Text='请保存工作并退出普通 Codex，面板将自动继续。'
 }catch{$status.Text='暂时无法启动';$details.Text=$_.Exception.Message;Set-Busy $false}
})
$stopAction={
 if($script:waiting){$script:waiting=$false;Set-Busy $false;$status.Text='已取消等待';return}
 if($script:worker -and -not $script:worker.HasExited){[IO.File]::WriteAllText((Join-Path $script:session 'stop'),'stop');$status.Text='已请求结束；加载完成后清理皮肤并恢复普通 Codex。';$stop.Enabled=$false}
}
$stop.Add_Click($stopAction)
$timer=New-Object Windows.Forms.Timer;$timer.Interval=1500
$timer.Add_Tick({
 try{
  if($script:waiting -and -not(Test-CodexUiRunning)){Start-Session}
  if($script:worker){
   $script:worker.Refresh()
   $output=Get-Content (Join-Path $script:session 'out.txt') -Tail 18 -ErrorAction SilentlyContinue
   $errors=Get-Content (Join-Path $script:session 'error.txt') -Tail 12 -ErrorAction SilentlyContinue
   $details.Text=(@($output)+@($errors)) -join "`r`n"
   if($script:worker.HasExited){$status.Text='本次运行已结束，结果见下方。可重新选择皮肤启动。';$script:worker.Dispose();$script:worker=$null;Set-Busy $false}
  }
 }catch{$details.Text=$_.Exception.Message;if(-not $script:worker){$script:waiting=$false;Set-Busy $false}}
})
$import.Add_Click({
 $picker=New-Object Windows.Forms.OpenFileDialog;$picker.Filter='皮肤包 (*.zip)|*.zip'
 try{if($picker.ShowDialog() -ne 'OK'){return};$details.Text=(& (Join-Path $InstallRoot 'import-skin.ps1') -InstallRoot $InstallRoot -ZipPath $picker.FileName|Out-String);Refresh-Skins;$status.Text='导入完成，请选择皮肤。'}catch{$status.Text='导入失败';$details.Text=$_.Exception.Message}finally{$picker.Dispose()}
})
$help.Add_Click({$details.Text="1. 左侧选皮肤，右侧预览。`r`n2. 点击启动，保存工作并退出普通 Codex，面板自动继续。`r`n3. 原生滑块切换六档，闪电按钮切换 EX。`r`n4. 本面板点击结束，恢复普通 Codex。`r`n5. 导入 ZIP 添加自定义皮肤：需有 skin.json、六张 PNG、EX 海报和 MP4。"})
$uninstall.Add_Click({
 if([Windows.Forms.MessageBox]::Show('将删除工具和已导入皮肤，请先备份个人皮肤。确定卸载？','卸载工具','YesNo','Warning') -ne 'Yes'){return}
 try{if($preview.Image){$preview.Image.Dispose();$preview.Image=$null};& (Join-Path $InstallRoot 'uninstall.ps1');$form.Close()}catch{$details.Text=$_.Exception.Message}
})
$form.Add_FormClosing({param($sender,$e) if($script:worker -and -not $script:worker.HasExited){$e.Cancel=$true;$status.Text='请先点击结束，等待清理完成后关闭面板。'}})
Refresh-Skins
if($SelfTest){
 if($list.Items.Count -lt 1 -or -not $preview.Image){throw 'Skin list or preview failed'}
 $start.GetType().GetMethod('OnClick',[Reflection.BindingFlags]'Instance,NonPublic').Invoke($start,@([EventArgs]::Empty)); Write-Output ('START_CHECK: '+$status.Text+' / '+$details.Text+' / waiting='+$script:waiting)
 Set-Busy $true;if($start.Enabled -or -not $stop.Enabled){throw 'Busy controls failed'}
 $script:waiting=$true;& $stopAction
 if($script:waiting -or -not $start.Enabled){throw 'Cancel wait failed'}
 $script:session=Join-Path $env:TEMP ('panel-stop-test-'+[guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($script:session)
 $script:worker=Get-Process -Id $PID
 & $stopAction
 if(-not(Test-Path (Join-Path $script:session 'stop'))){throw 'Missing stop request'}
 $script:worker.Dispose();$script:worker=$null
 $preview.Image.Dispose();$form.Dispose();'PASS: preview, busy controls, cancel waiting, cooperative stop request';return
}
if($PanelTestOutput){[IO.File]::WriteAllText(($PanelTestOutput+'.log'),"before web`r`n")}
if(Test-Path (Join-Path $InstallRoot 'web-panel.ps1')){try{. (Join-Path $InstallRoot 'web-panel.ps1')}catch{$details.Text='高级面板不可用，使用基础面板。'+$_.Exception.Message}}
$form.Add_Shown({try{Check-Environment}catch{$status.Text=$_.Exception.Message}})
if($PanelTestOutput){[IO.File]::AppendAllText(($PanelTestOutput+'.log'),"before show`r`n")}
$timer.Start();try{[void]$form.ShowDialog()}finally{$timer.Stop();$timer.Dispose();if($preview.Image){$preview.Image.Dispose()};$form.Dispose()}
