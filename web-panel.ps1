# Local-only WebView2 presentation. Existing WinForms actions remain the controller.
$sdk=Join-Path $InstallRoot 'vendor\webview2'
Add-Type -Path (Join-Path $sdk 'Microsoft.Web.WebView2.Core.dll')
Add-Type -Path (Join-Path $sdk 'Microsoft.Web.WebView2.WinForms.dll')
if(-not ('SkinNativeLoader' -as [type])){Add-Type 'using System; using System.Runtime.InteropServices; public static class SkinNativeLoader { [DllImport("kernel32", CharSet=CharSet.Unicode, SetLastError=true)] public static extern IntPtr LoadLibrary(string name); }'}
if([SkinNativeLoader]::LoadLibrary((Join-Path $sdk 'WebView2Loader.dll')) -eq [IntPtr]::Zero){throw 'WebView2 loader unavailable'}
$web=New-Object Microsoft.Web.WebView2.WinForms.WebView2
$properties=New-Object Microsoft.Web.WebView2.WinForms.CoreWebView2CreationProperties
$properties.UserDataFolder=Join-Path $InstallRoot 'runtime\panel-webview'
$web.CreationProperties=$properties;$web.Dock='Fill'
$form.ClientSize=New-Object Drawing.Size(1120,800)
$form.Text='Codex 换肤 · Liquid Studio'
$form.BackColor=[Drawing.Color]::FromArgb(16,23,24)
$script:webReady=$false;$script:previewKey='';$script:previewData='';$script:previewLevel=0
function Sync-WebPanel {
 if(-not $script:webReady){return}
 $key="$($list.SelectedIndex):$script:previewLevel"
 if($key -ne $script:previewKey){
  $script:previewKey=$key;$script:previewData=''
  try{
   $item=$list.SelectedItem
   if($item){
    $name=if($script:previewLevel -eq 6){$item.Config.ex.poster}else{$item.Config.levels[$script:previewLevel]}
    $path=[IO.Path]::GetFullPath((Join-Path $item.Path $name))
    if((Split-Path $path) -ne [IO.Path]::GetFullPath($item.Path)){throw 'Invalid image path'}
    if((Get-Item -LiteralPath $path).Length -gt 20MB){throw 'Image too large'}
    $original=[Drawing.Image]::FromFile($path)
    try{
     $thumb=New-Object Drawing.Bitmap($original,1000,([int](1000*$original.Height/$original.Width)))
     $stream=New-Object IO.MemoryStream
     try{$thumb.Save($stream,[Drawing.Imaging.ImageFormat]::Jpeg);$script:previewData='data:image/jpeg;base64,'+[Convert]::ToBase64String($stream.ToArray())}finally{$stream.Dispose();$thumb.Dispose()}
    }finally{$original.Dispose()}
   }
  }catch{$details.Text=$_.Exception.Message}
 }
 $state=@{names=@($list.Items|ForEach-Object{$_.Label});selected=$list.SelectedIndex;preview=$script:previewData;status=$status.Text;details=$details.Text;busy=[bool]($script:waiting -or $script:worker)}
 $web.CoreWebView2.PostWebMessageAsJson(($state|ConvertTo-Json -Compress -Depth 4))
}
$web.Add_CoreWebView2InitializationCompleted({param($sender,$event)
 if($PanelTestOutput){[IO.File]::AppendAllText(($PanelTestOutput+'.log'),"initialized $($event.IsSuccess)`r`n")}
 if(-not $event.IsSuccess){$details.Text='WebView2 初始化失败，已保留基础面板。';return}
 $core=$web.CoreWebView2
 $core.Settings.AreDevToolsEnabled=$false;$core.Settings.AreDefaultContextMenusEnabled=$false
 $core.SetVirtualHostNameToFolderMapping('skin.local',(Join-Path $InstallRoot 'panel'),[Microsoft.Web.WebView2.Core.CoreWebView2HostResourceAccessKind]::DenyCors)
 $core.add_NavigationStarting({param($sender,$e) if($e.Uri -ne 'https://skin.local/index.html'){$e.Cancel=$true}})
 $core.add_NewWindowRequested({param($sender,$e) $e.Handled=$true})
 $core.add_PermissionRequested({param($sender,$e) $e.State=[Microsoft.Web.WebView2.Core.CoreWebView2PermissionState]::Deny})
 $core.add_WebMessageReceived({param($sender,$e)
  if($e.Source -ne 'https://skin.local/index.html'){return}
  try{
   $m=$e.WebMessageAsJson|ConvertFrom-Json
   switch($m.action){
    'ready' {$script:webReady=$true;Sync-WebPanel}
    'select' {if(-not $script:waiting -and -not $script:worker -and $m.value -is [int] -and $m.value -ge 0 -and $m.value -lt $list.Items.Count){$script:previewLevel=0;$list.SelectedIndex=$m.value}}
    'preview' {if($m.value -is [int] -and $m.value -ge 0 -and $m.value -le 6){$script:previewLevel=$m.value}}
    default {
     $button=switch($m.action){'start'{$start};'stop'{$stop};'import'{$import};'uninstall'{$uninstall};default{$null}}
     if($button -and $button.Enabled){$button.GetType().GetMethod('OnClick',[Reflection.BindingFlags]'Instance,NonPublic').Invoke($button,@([EventArgs]::Empty))}
    }
   }
   Sync-WebPanel
  }catch{$details.Text=$_.Exception.Message}
 })
 $core.add_NavigationCompleted({param($sender,$e) if($e.IsSuccess){foreach($c in $form.Controls){if($c -ne $web){$c.Visible=$false}};$web.Visible=$true;$web.BringToFront()}})
 $core.Navigate('https://skin.local/index.html')
})
$web.Visible=$false;$form.Controls.Add($web)
$form.Add_Shown({if($PanelTestOutput){[IO.File]::AppendAllText(($PanelTestOutput+'.log'),"shown`r`n")};[void]$web.EnsureCoreWebView2Async()})
$timer.Add_Tick({Sync-WebPanel})
$form.Add_FormClosed({$web.Dispose()})

if($PanelTestOutput){
 $script:captureTask=$null;$script:captureStream=$null;$script:probeTicks=0
 $timer.Add_Tick({
  $script:probeTicks++
  if($script:probeTicks -gt 25){$form.Close();throw 'Web panel load timed out'}
  if($script:webReady -and $script:probeTicks -eq 3){[void]$web.CoreWebView2.ExecuteScriptAsync("document.querySelectorAll('.levels button')[1].click()")}
  if($script:webReady -and $script:probeTicks -eq 4 -and $script:previewLevel -ne 1){throw 'Preview bridge failed'}
  if($script:webReady -and -not $script:captureTask -and $script:probeTicks -gt 4){
   $script:captureStream=[IO.File]::Create($PanelTestOutput)
   $script:captureTask=$web.CoreWebView2.CapturePreviewAsync([Microsoft.Web.WebView2.Core.CoreWebView2CapturePreviewImageFormat]::Png,$script:captureStream)
  }
  if($script:captureTask -and $script:captureTask.IsCompleted){
   $script:captureTask.GetAwaiter().GetResult();$script:captureStream.Dispose()
   [IO.File]::WriteAllText(($PanelTestOutput+'.txt'),'PASS: WebView2 ready and screenshot captured')
   $form.Close()
  }
 })
}