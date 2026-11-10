# OfficeCheck.ps1: two tools for looking after the office's PCs.
# Load them into your PowerShell with a dot:  . .\OfficeCheck.ps1
# The jobs are in README.md.

function Test-PcConnection {
    # Job 1: for each PC, does it answer, and is its remoting door (port 5985) open?
    # Output one object for each PC, with ComputerName, Answers and RemotingOpen.
    # Job 3: take several names, from the pipeline too.
    [CmdletBinding()]
    param(
        [string] $ComputerName = 'localhost'
    )

}

function Get-PcHealth {
    # Job 2: run $check right here for this PC, and send it with Invoke-Command only to another PC
    # whose remoting door is open. Warn about, and skip, a PC whose door is closed.
    # Job 3: take several names, from the pipeline too.
    [CmdletBinding()]
    param(
        [string] $ComputerName = $env:COMPUTERNAME
    )

    # The health check itself. Ready to use: don't change it.
    $check = {
        $drive = Get-PSDrive -Name C
        [pscustomobject]@{
            FreeSpaceGB  = [math]::Round($drive.Free / 1GB, 1)
            PrintSpooler = (Get-Service -Name Spooler).Status.ToString()
        }
    }

    # A first try: it sends the check through remoting every time, even to this PC,
    # so it fails on any PC where remoting isn't turned on.
    $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock $check
    [pscustomobject]@{
        ComputerName = $ComputerName
        FreeSpaceGB  = $result.FreeSpaceGB
        PrintSpooler = $result.PrintSpooler
    }
}
