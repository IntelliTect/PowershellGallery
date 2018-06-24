<#Header#>
Set-StrictMode -Version "Latest"

#Get-Module IntelliTect.Common | Remove-Module
Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Common -Force


#EndHeader#>

Function Script:Get-SampleDisposeObject {
    $object = New-Object object
    $object | Add-Member -MemberType NoteProperty -Name DisposeCalled -Value $false
    $object | Add-Member -MemberType ScriptMethod -Name Dispose -Value { $this.DisposeCalled = $true }
    return $object
}

Describe "Add-DisposeScript" {
    It "Verify that a dispose metthod is added." {
        $object = New-Object Object
        $object | Add-DisposeScript -DisposeScript { Write-Output  $true }
        $object.Dispose() | Should Be $true
        $object.IsDisposed | Should Be $true
    }
}

Describe "Regsiter-AutoDispose" {
    It "Verify that dispose is called on Add-DisposeScript object" {
        $sampleDisposeObject = New-Object Object
        $sampleDisposeObject | Add-DisposeScript -DisposeScript { Write-Output  "first" }
        Register-AutoDispose $sampleDisposeObject { Write-Output 42 } | Should Be "first",42
        $sampleDisposeObject.IsDisposed | Should Be $true
    }
    It "Verify that dispose is called" {
        $sampleDisposeObject = Get-SampleDisposeObject
        Register-AutoDispose $sampleDisposeObject { Write-Output $true } | Should Be $true
        $sampleDisposeObject.DisposeCalled | Should Be $true
    }
    It "NOTE: Both value types and refrence types can be passed in closure but neither will reflect change after the closure." {
        $sampleDisposeObject = Get-SampleDisposeObject
        [int]$count = 42
        [string]$text = "original"
        Register-AutoDispose $sampleDisposeObject {
            Write-Output "$text,$count";
            $count = 2
            $text = "updated"
        } | Should Be "original,42"
        $count | Should Be 42
        $text | Should Be "original"
    }
}

Describe "Get-Tempdirectory" {
    It 'Verify the item is in the %TEMP% (temporary) directory' {
        try {
            $tempItem = Get-TempDirectory
            $tempItem.Parent.FullName |Should Be ([IO.Path]::GetTempPath().TrimEnd([IO.Path]::DirectorySeparatorChar).TrimEnd([IO.Path]::AltDirectorySeparatorChar))
        }
        finally {
            Remove-Item $tempItem;
            Test-Path $tempItem | Should Be $false
        }
    }
}

Describe "Get-TempDirectory/Get-TempFile" {

    (Get-TempDirectory), (Get-TempFile) | % {
        It "Verify that the item has a Dispose member" {
            $tempItem = $null
            try {
                Write-Verbose ($_.Dispose)
                $tempItem = $_
                $tempItem.PSobject.Members.Name -match "Dispose" | Should Be $true
            }
            finally {
                Remove-Item $tempItem;
                Test-Path $tempItem | Should Be $false
            }
        }
        It "Verify that Dispose removes the folder" {
            $tempItem = $null
            try {
                $tempItem = Get-TempDirectory
                $tempItem.Dispose()
                Test-Path $tempItem | Should Be $false
            }
            finally {
                if (Test-Path $tempItem) {
                    Remove-Item $tempItem;
                    Test-Path $tempItem | Should Be $false
                }
            }
        }
        Function Debug-Temp {
            return Get-TempDirectory
        }
        It "Verify dispose member is called by Register-AutoDispose" {
            $tempItem = $null
            try {
                $tempItem = Get-TempDirectory
                Register-AutoDispose $tempItem {}
                Test-Path $tempItem | Should Be $false
            }
            finally {
                if (Test-Path $tempItem) {
                    Remove-Item $tempItem;
                    Test-Path $tempItem | Should Be $false
                }
            }
        }
    }
}

Describe "Get-TempFile" {
    It "Provide the full path (no name parameter)" {
        Register-AutoDispose ($tempFile = Get-TempFile) {} #Get the file but let is dispose automatically
        Test-Path $tempFile.FullName | Should Be $false
        Register-AutoDispose (Get-TempFile $tempFile.FullName) {
            Test-Path $tempFile.FullName | Should Be $true
        }
    }
    It "Provide the name but no path" {
        Register-AutoDispose ($tempFile = Get-TempFile) {} #Get the file but let is dispose automatically
        Test-Path $tempFile.FullName | Should Be $false
        Register-AutoDispose (Get-TempFile -name $tempFile.Name) {
            Test-Path $tempFile.FullName | Should Be $true
        }
    }
    It "Provide the path and the name" {
        Register-AutoDispose ($tempFile = Get-TempFile) {} #Get the file but let is dispose automatically
        Test-Path $tempFile.FullName | Should Be $false
        Register-AutoDispose (Get-TempFile $tempFile.Directory.FullName $tempFile.Name) {
            Test-Path $tempFile.FullName | Should Be $true
        }
    }
}