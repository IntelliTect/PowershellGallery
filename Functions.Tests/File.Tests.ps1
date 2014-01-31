$here = $PSScriptRoot
$sut = $PSCommandPath.Replace(".Tests", "")
. $sut

Describe "Edit-File" {
    It "Create a new temp file and open it to edit" {
        $tempFile = [IO.Path]::ChangeExtension([IO.Path]::GetTempFileName(), ".txt")
        $notepadProcesses = Get-Process #Only needed when not in ISE
        try {
            Edit-File $tempFile
            $openedFileProcess = Get-Process | ?{ $notepadProcesses.id -notcontains $_.id }
            $openedFileProcess.Count | Should Be 1;
            $openedFileProcess | Stop-Process
        }
        finally {
            Remove-Item $tempFile;
        }
    }
    It "Create a new temp file and open from the pipeline" {
        $tempFile = [IO.Path]::ChangeExtension([IO.Path]::GetTempFileName(), ".txt")
        $notepadProcesses = Get-Process #Only needed when not in ISE
        try {
            $tempFile | Edit-File
            $openedFileProcess = Get-Process | ?{ $notepadProcesses.id -notcontains $_.id }
            $openedFileProcess.Count | Should Be 1;
            $openedFileProcess | Stop-Process
        }
        finally {
            Remove-Item $tempFile;
        }
    }
}