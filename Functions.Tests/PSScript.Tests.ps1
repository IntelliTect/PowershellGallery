<#Header#>
Set-StrictMode -Version "Latest"
$sut = $PSCommandPath.ToLower().Replace(".tests", "")
. $sut
[string]$here=$PSScriptRoot;
<#EndHeader#>

. (Join-Path (Split-Path $sut) "Common.ps1")


