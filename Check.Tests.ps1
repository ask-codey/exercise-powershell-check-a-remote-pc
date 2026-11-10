# Checks the two tools in OfficeCheck.ps1, one or more tests per job in README.md.
# It loads OfficeCheck.ps1 the way you do, with a dot. Remoting doesn't need to be turned on: where a test
# needs another PC, it stands in for Invoke-Command and Test-PcConnection with a Pester mock, a pretend
# command that answers the way the real one would and remembers how it was called. Nothing connects to
# another computer, and nothing on this PC is changed.
# Run it from this folder with: Invoke-Pester
# You don't need to change this file.

BeforeAll {
    $script:tools = Join-Path $PSScriptRoot 'OfficeCheck.ps1'
    . $tools

    # Is there a function with this name? Then the message can say "write it first" instead of failing oddly.
    function Test-Tool([string] $Name) { [bool](Get-Command $Name -CommandType Function -ErrorAction SilentlyContinue) }

    # This PC's own readings, taken the same way as the health check, to compare with.
    function Get-OwnReading {
        [pscustomobject]@{
            FreeSpaceGB  = [math]::Round((Get-PSDrive -Name C).Free / 1GB, 1)
            PrintSpooler = (Get-Service -Name Spooler).Status.ToString()
        }
    }
}

Describe 'Exercise: Check a Remote PC' {

    It 'OfficeCheck.ps1 is here' {
        Test-Path -LiteralPath $tools -PathType Leaf | Should -BeTrue -Because 'the tools live in OfficeCheck.ps1, in this folder. Did it get moved or renamed?'
    }

    It '1) Test-PcConnection says localhost answers, and whether its remoting door is open' {
        Test-Tool 'Test-PcConnection' | Should -BeTrue -Because 'Test-PcConnection should be in OfficeCheck.ps1'
        $out = @(Test-PcConnection -ComputerName localhost)
        $out.Count | Should -Be 1 -Because 'one name in should give one object out'
        $out[0].ComputerName | Should -Be 'localhost' -Because 'each object should name its PC in a ComputerName property'
        $out[0].Answers | Should -BeTrue -Because 'your own PC always answers a ping to localhost. Use Test-Connection -TargetName $name -Count 1 -Quiet, which gives True or False'
        $out[0].RemotingOpen | Should -BeOfType [bool] -Because 'RemotingOpen should be True or False, from Test-Connection -TargetName $name -TcpPort 5985 -Quiet'
        $out[0].RemotingOpen | Should -Be (Test-Connection -TargetName localhost -TcpPort 5985 -TimeoutSeconds 2 -Quiet) -Because 'RemotingOpen should say whether port 5985, the remoting door, answers on that PC'
    }

    It '1) Test-PcConnection reports a PC that is not there' {
        Test-Tool 'Test-PcConnection' | Should -BeTrue -Because 'Test-PcConnection should be in OfficeCheck.ps1'
        $out = @(Test-PcConnection -ComputerName meeting-room.invalid)
        $out.Count | Should -Be 1 -Because 'a PC that is not there still gets its object, so the report shows it'
        $out[0].ComputerName | Should -Be 'meeting-room.invalid'
        $out[0].Answers | Should -BeFalse -Because 'a name that ends in .invalid never exists, so nothing answers'
        $out[0].RemotingOpen | Should -BeFalse -Because 'a PC that is not there has no open door either'
    }

    It '2) Get-PcHealth checks this PC right here, without remoting' {
        Test-Tool 'Get-PcHealth' | Should -BeTrue -Because 'Get-PcHealth should be in OfficeCheck.ps1'
        Mock Invoke-Command { throw 'Invoke-Command was called for this PC' }
        $own = Get-OwnReading
        $out = @(Get-PcHealth)
        Should -Invoke Invoke-Command -Times 0 -Exactly -Because 'for this PC, run the check right here with & $check: Invoke-Command needs remoting, which is off on most PCs'
        $out.Count | Should -Be 1 -Because 'with no -ComputerName, Get-PcHealth should check this PC once'
        $out[0].ComputerName | Should -Be $env:COMPUTERNAME -Because 'with no -ComputerName, it checks this PC, $env:COMPUTERNAME'
        $out[0].PrintSpooler | Should -Be $own.PrintSpooler -Because 'PrintSpooler should be the status the check reads, such as Running'
        [math]::Abs([double]$out[0].FreeSpaceGB - $own.FreeSpaceGB) | Should -BeLessThan 1 -Because "FreeSpaceGB should be the free space on C: in GB, which is about $($own.FreeSpaceGB) here"
    }

    It '2) Get-PcHealth knows localhost and 127.0.0.1 are this PC too' {
        Test-Tool 'Get-PcHealth' | Should -BeTrue -Because 'Get-PcHealth should be in OfficeCheck.ps1'
        Mock Invoke-Command { throw 'Invoke-Command was called for this PC' }
        foreach ($name in 'localhost', '127.0.0.1') {
            $out = @(Get-PcHealth -ComputerName $name)
            $out.Count | Should -Be 1 -Because "$name is this PC, so it should be checked right here"
            $out[0].ComputerName | Should -Be $name -Because 'ComputerName should be the name you asked about'
        }
        Should -Invoke Invoke-Command -Times 0 -Exactly -Because 'localhost and 127.0.0.1 are names for this PC: run the check here, with no remoting'
    }

    It '2) Get-PcHealth sends the check to another PC with Invoke-Command' {
        Test-Tool 'Get-PcHealth' | Should -BeTrue -Because 'Get-PcHealth should be in OfficeCheck.ps1'
        # Pretend front-desk is switched on with its remoting door open, and answers with these readings.
        Mock Test-PcConnection { [pscustomobject]@{ ComputerName = 'front-desk'; Answers = $true; RemotingOpen = $true } }
        Mock Invoke-Command { [pscustomobject]@{ FreeSpaceGB = 48.2; PrintSpooler = 'Running' } }
        $out = @(Get-PcHealth -ComputerName front-desk)
        Should -Invoke Test-PcConnection -Times 1 -Because 'before sending the check to another PC, ask Test-PcConnection whether its remoting door is open'
        Should -Invoke Invoke-Command -Times 1 -Exactly -ParameterFilter { $ComputerName -contains 'front-desk' -and $null -ne $ScriptBlock } -Because 'for another PC, send the check with Invoke-Command -ComputerName $name -ScriptBlock $check'
        $out.Count | Should -Be 1 -Because 'one PC in, one row out'
        $out[0].ComputerName | Should -Be 'front-desk'
        $out[0].FreeSpaceGB | Should -Be 48.2 -Because 'the row should carry the FreeSpaceGB that came back from the other PC'
        $out[0].PrintSpooler | Should -Be 'Running' -Because 'the row should carry the PrintSpooler that came back from the other PC'
    }

    It '2) Get-PcHealth skips a PC whose remoting door is closed, with a warning' {
        Test-Tool 'Get-PcHealth' | Should -BeTrue -Because 'Get-PcHealth should be in OfficeCheck.ps1'
        # Pretend back-office answers, but remoting isn't turned on there.
        Mock Test-PcConnection { [pscustomobject]@{ ComputerName = 'back-office'; Answers = $true; RemotingOpen = $false } }
        Mock Invoke-Command { throw 'Invoke-Command was called for a PC whose door is closed' }
        $all = @(Get-PcHealth -ComputerName back-office 3>&1)
        $warnings = @($all | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
        $rows = @($all | Where-Object { $_ -isnot [System.Management.Automation.WarningRecord] })
        Should -Invoke Test-PcConnection -Times 1 -Because 'before sending the check to another PC, ask Test-PcConnection whether its remoting door is open'
        Should -Invoke Invoke-Command -Times 0 -Exactly -Because 'with the door closed, Invoke-Command can only fail: skip that PC'
        $rows.Count | Should -Be 0 -Because 'a skipped PC gets no row'
        $warnings.Count | Should -Be 1 -Because 'say which PC was skipped with Write-Warning'
        $warnings[0].Message | Should -BeLike '*back-office*' -Because 'the warning should name the PC that was skipped'
    }

    It '3) Test-PcConnection takes several names, from the pipeline too' {
        Test-Tool 'Test-PcConnection' | Should -BeTrue -Because 'Test-PcConnection should be in OfficeCheck.ps1'
        @(Test-PcConnection -ComputerName localhost, meeting-room.invalid | ForEach-Object ComputerName) | Should -Be @('localhost', 'meeting-room.invalid') -Because '-ComputerName should take several names ([string[]]) and give one object for each, in order'
        @('localhost', 'meeting-room.invalid' | Test-PcConnection | ForEach-Object ComputerName) | Should -Be @('localhost', 'meeting-room.invalid') -Because '-ComputerName needs [Parameter(ValueFromPipeline)], and the work goes in a process block, so every name piped in gets its object'
    }

    It '3) Get-PcHealth checks every PC in office-pcs.txt, from the pipeline' {
        Test-Tool 'Get-PcHealth' | Should -BeTrue -Because 'Get-PcHealth should be in OfficeCheck.ps1'
        $list = Join-Path $PSScriptRoot 'office-pcs.txt'
        Test-Path -LiteralPath $list | Should -BeTrue -Because 'office-pcs.txt should be in this folder'
        Mock Invoke-Command { throw 'Invoke-Command was called, but no PC in office-pcs.txt needs it' }
        $all = @(Get-Content -Path $list | Get-PcHealth 3>&1)
        $warnings = @($all | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
        $rows = @($all | Where-Object { $_ -isnot [System.Management.Automation.WarningRecord] })
        @($rows | ForEach-Object ComputerName) | Should -Be @('localhost', '127.0.0.1') -Because 'localhost and 127.0.0.1 are this PC, so both get a row. -ComputerName needs [Parameter(ValueFromPipeline)] and a process block'
        @($warnings | Where-Object Message -like '*meeting-room.invalid*').Count | Should -Be 1 -Because 'meeting-room.invalid is not there, so its door is closed: warn and skip it'
    }
}
