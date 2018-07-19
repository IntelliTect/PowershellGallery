

Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Common
Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Git

Function Script:Initialize-TestGitRepo {
    [CmdletBinding()]
    param ()
    $tempDirectory = Get-TempDirectory
    try {
        Push-Location $tempDirectory
        Invoke-GitCommand 'Init'
    }
    finally {
        Pop-Location
    }
    return $tempDirectory
}



