<#Header#>
Set-StrictMode -Version "Latest"
$sut = $PSCommandPath.ToLower().Replace(".tests", "")
. $sut
[string]$script:here=$PSScriptRoot
 <#EndHeader#>

 Import-Module -Name $PSScriptRoot\..\Modules\IntelliTect.Common
#IMPORTANT: Dispose needs to be called on this return.

Function Script:Get-TempDirectoryWith3Files {
        $tempDirectory = Get-TempDirectory
        # Place 3 files in the directory, each named after a time property.
        # For the file named after the specific time property being tested ($timeProperty),
        # set the date to a newer date.
        $TimeProperties | %{
            $file = New-Item (Join-Path $tempDirectory.FullName "$_") -ItemType File; #create a file for each time property
            $TimeProperties | %{ $file."$_" = [DateTime]"1/1/2000 1:0:0 AM"} #Set the date for each time property on the new file

            Write-Debug "$_ = $($tempDirectory."$_")"

            #Test that when everything is the same, the Get-ItemLastUsefulDate time is what we set.
            Write-Output $file
        } | ?{ $file.Name -eq $timeProperty # IF the file name is the same as the one being tested.
        } | %{
            $_."$timeProperty" = [DateTime]"1/1/2010 1:0:0 AM" # Then set that date to newer.
        }
        $TimeProperties | %{ $tempDirectory."$_" = [DateTime]"1/1/2000 1:0:0 AM" }  # Set the same value for all the time related properties on the directory
                                                                                # here because changing the date on file changes the access time on the directory.
        return $tempDirectory
}

Describe Get-ItemLastUsefulDate {
    $TimeProperties | %{
        $timeProperty = $_
        Function Get-TempItemName { Register-AutoDispose ($tempName = Get-TempFile) {}; return $tempName.FullName }
        ForEach($tempItem in (Get-TempFile),(Get-TempDirectory),(Get-TempFile "$(Get-TempItemName)[1]"),(Get-TempDirectory "$(Get-TempItemName)[1]")) {
            It "$timeProperty is correctly identified as the LastUsefulDate for $(if($tempItem -is [System.IO.DirectoryInfo]){"Directory"}else{"File"})" {
                Register-AutoDispose ($tempItem) {
                    $TimeProperties | %{ $tempItem."$_" = [DateTime]"1/1/2000 1:0:0 AM" }  # Set the same value for all the time related properties.
                    $parameters = $null;
                    if(!(Test-Path $tempItem.FullName)) {$parameters = @{ LiteralPath = $tempItem.FullName; } }
                    else { $parameters = @{ Path = $tempItem.FullName; } }

                    Get-ItemLastUsefulDate @parameters | Should Be ([DateTime]"1/1/2000 1:0:0 AM")
                    $tempItem."$timeProperty" = [DateTime]"1/1/2010 1:0:0 AM"
                    Get-ItemLastUsefulDate @parameters | Should Be $tempItem."$timeProperty"
                }
            }
        }
        It "$timeProperty is correctly identified as the LastUsefulDate directory)" {
            Register-AutoDispose ($tempDirectory = Script:Get-TempDirectoryWith3Files) {
                 $tempDirectory | Get-ItemLastUsefulDate | Should Be ([DateTime]"1/1/2010 1:0:0 AM")
            }
        }
    }
}

Describe Clear-Temp {
    $TimeProperties | %{
        $timeProperty = $_
        Context "Mocking out Remove-FileToRecycle" {
            Mock Remove-FileToRecycleBin -parameterFilter { $LiteralPath -in $timeProperties } {
                Remove-Item $LiteralPath -Force
            }

            It "Clean up only the $timeProperty file which is the past the cutoff" {
                Register-AutoDispose ($tempDirectory = Script:Get-TempDirectoryWith3Files) {

                     [int]$months = ([DateTime]::Now-[DateTime]"1/1/2010 1:0:0 AM").  #Determine how long it was since the lasted useful date on a file
                        Add([TimeSpan]"365").TotalDays/31                      # Add a year, and the roughly determine how many months that is.

                     Clear-Temp $tempDirectory.FullName -MonthsOld $months #Clear anything older than $months (leaving the latest file)

                     $tempDirectory.GetFiles().Count | Should Be 1
                     $tempDirectory.GetFiles()[0].Name | Should Be $timeProperty

                }
            }
        }
    }
}
