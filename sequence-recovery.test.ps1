$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'glass-lab.ps1'),[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors | Out-String)}
foreach($name in @('Throw-LabFailure','Assert-LocalWebSocketUrl','Get-SequenceRecoveryTarget','Restore-SequenceVisual','Repair-SequenceConnection')){
  $node=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
  Invoke-Expression $node.Extent.Text
}
function Assert($condition,$message){if(-not $condition){throw $message}}
function MustFail($action){$failed=$false; try{& $action}catch{$failed=$true}; Assert $failed 'Unsafe recovery accepted'}
$port=51375; $baseUri="http://127.0.0.1:$port"; $codex=@{}
$sessionIdentity=[pscustomobject]@{ProcessId=123;CreationDate='original'}
$browserUri=[uri]"ws://127.0.0.1:$port/devtools/browser/original"
$owner=123; $created='original'; $browserEndpoint=$browserUri.AbsoluteUri
$page=[pscustomobject]@{type='page';url='app://local';webSocketDebuggerUrl="ws://127.0.0.1:$port/devtools/page/replacement"}
$webview=[pscustomobject]@{type='webview';url='https://skin.local';webSocketDebuggerUrl="ws://127.0.0.1:$port/devtools/page/panel"}
$pages=@($page,$webview)
function Get-NetTCPConnection { [pscustomobject]@{OwningProcess=123} }
function Assert-LoopbackListenerOwner {return $script:owner}
function Get-CimInstance { [pscustomobject]@{CreationDate=$script:created} }
function Invoke-RestMethod {param($Uri,$TimeoutSec,$MaximumRedirection)
  if($Uri.EndsWith('/version')){return [pscustomobject]@{webSocketDebuggerUrl=$script:browserEndpoint}}
  # REST JSON arrays are returned as one pipeline object in Windows PowerShell.
  return ,$script:pages
}
Assert ((Get-SequenceRecoveryTarget).AbsoluteUri -eq $page.webSocketDebuggerUrl) 'Mixed page/webview array not flattened'
$owner=999; MustFail {Get-SequenceRecoveryTarget}; $owner=123
$created='reused-pid'; MustFail {Get-SequenceRecoveryTarget}; $created='original'
$browserEndpoint='ws://127.0.0.1:51375/devtools/browser/other'; MustFail {Get-SequenceRecoveryTarget}; $browserEndpoint=$browserUri.AbsoluteUri
$pages=@($page,$page); MustFail {Get-SequenceRecoveryTarget}
$pages=@($webview); MustFail {Get-SequenceRecoveryTarget}
$pages=@($page); $page.webSocketDebuggerUrl='ws://example.com:51375/devtools/page/remote'; MustFail {Get-SequenceRecoveryTarget}
$socket=$null; $glassSource='glass'; $visualExpression='visual'; $sequenceBundle=Join-Path $PSScriptRoot 'sequence-host.js'
$sequenceEvidence=[pscustomobject]@{level=4;phase='ambient'}
$stages=[Collections.Generic.List[string]]::new(); $mounts=0
$state=[pscustomobject]@{shell=$true;mounted=$true}
function Invoke-CdpValue {param($Socket,$Id,$Stage,$Expression)
  $script:stages.Add($Stage)
  if($Stage -eq 'recovery-state'){return $script:state}
  return $true
}
function Mount-Sequence {param($Socket,$Source) $script:mounts++}
Restore-SequenceVisual
Assert ($mounts -eq 0 -and $stages.Count -eq 1) 'Transport reconnect duplicated the skin'
$state.mounted=$false; $stages.Clear(); Restore-SequenceVisual
Assert ($mounts -eq 1) 'Reload did not remount'
Assert (($stages -join ',') -eq 'recovery-state,recovery-reset,recovery-glass,recovery-background,recovery-material,recovery-level,recovery-ex') 'Reload restore order/selection failed'
$state.shell=$false; MustFail {Restore-SequenceVisual}
Assert ($mounts -eq 1) 'Injected into an unsupported shell'
$StopRequestPath=''; $attempts=0; $clock=0
function Get-SequenceRecoveryTarget {$script:attempts++; throw 'Temporary target absence'}
function Start-Sleep {}
function Get-Date {$script:clock++; return [datetime]::new(2026,1,1).AddSeconds(($script:clock-1)*40)}
MustFail {Repair-SequenceConnection}
Assert ($attempts -eq 2) 'Recovery did not retry or was unbounded'
$StopRequestPath='cancel'; $attempts=0
function Test-Path {return $true}
MustFail {Repair-SequenceConnection}
Assert ($attempts -eq 0) 'End Skin ignored during recovery'
'PASS: nested REST arrays; owner/PID/browser/target guards; reconnect without remount; reload restores level and EX; unsupported shell rejected.'
'PASS: transient failures retry within a bounded window; End Skin cancels before reconnecting.'
