# Exercise: Check a Remote PC

Exercise code for the lesson **Exercise: Check a Remote PC** in PowerShell in Depth on [ask-codey.com](https://www.ask-codey.com).

A small office has three PCs, and you're the one who looks after them. `OfficeCheck.ps1` has two tools for that job. `Test-PcConnection` should say, for each PC, whether it answers and whether its remoting door (port 5985) is open; it's empty. `Get-PcHealth` should report each PC's free space on C: and its print service; its first try sends the check through remoting every time, even to the PC you're sitting at, so it fails on any PC where remoting isn't turned on, which is most of them. Finish both, so they work on your own PC with nothing turned on, and reach another PC only when its door is open. A Pester check tests them on your PC and stands in for the other PCs, so you don't need remoting or a second computer.

## What's here

- `OfficeCheck.ps1`: the two tools. For you to finish. The health check itself, `$check`, is written: don't change it.
- `office-pcs.txt`: the office's PCs, one name a line. Your own PC plays two of them under its two names, `localhost` and `127.0.0.1`. The third, `meeting-room.invalid`, plays the PC that's switched off: a name that ends in `.invalid` never exists.
- `Check.Tests.ps1`: the check. You don't need to change it.

## What to do

Open PowerShell 7 in this folder (the one with `office-pcs.txt` in it), and open the tools in VS Code (`code .`) or with `edit .\OfficeCheck.ps1`. Load them, and try the first try:

```powershell
. .\OfficeCheck.ps1
Get-PcHealth -ComputerName localhost
```

Unless remoting is on, it fails with *Connecting to remote server localhost failed*, and the row it prints is empty. Load the file again with `. .\OfficeCheck.ps1` after every change. Then, one job at a time:

1. **Test-PcConnection.** For the PC in `-ComputerName`, output one object with three properties: `ComputerName` (the name you were given), `Answers` (from `Test-Connection -TargetName $name -Count 1 -Quiet`) and `RemotingOpen` (from `Test-Connection -TargetName $name -TcpPort 5985 -TimeoutSeconds 2 -Quiet`). Both give True or False. `[pscustomobject]@{ ... }` makes the object. Then `Test-PcConnection -ComputerName localhost` says True for Answers.
2. **Get-PcHealth.** Decide where the check runs. If the name is this PC (`localhost`, `127.0.0.1`, `.` or `$env:COMPUTERNAME`), run it right here with `& $check`: no remoting needed. Otherwise ask `Test-PcConnection` first: if its `RemotingOpen` is True, send the check with `Invoke-Command -ComputerName $name -ScriptBlock $check`; if not, say so with `Write-Warning` (name the PC) and output nothing for it. Keep the row it outputs: `ComputerName`, `FreeSpaceGB` and `PrintSpooler`.
3. **Many PCs, from the pipeline.** Make `-ComputerName` take several names (`[string[]]`) and take them from the pipeline (`[Parameter(ValueFromPipeline)]`) in both tools, with the work in a `process` block and a `foreach` over the names. Keep the defaults: `'localhost'` for Test-PcConnection, `$env:COMPUTERNAME` for Get-PcHealth. Then `Get-Content .\office-pcs.txt | Get-PcHealth` checks the whole office: two rows, and a warning for `meeting-room.invalid`.

## Check your work

The check needs Pester 5 or newer. Install it once, if you haven't already:

```powershell
Install-PSResource Pester
```

Then, from this folder:

```powershell
Invoke-Pester
```

At first most tests fail: that is expected. Each job you finish turns its tests green. A failing test's message says what to look at. The check runs your tools on your own PC for real. Where a test needs another PC, it uses a Pester **mock**: a pretend `Invoke-Command` or `Test-PcConnection` that answers the way the real one would and remembers how it was called, so the check can see that your tool sent the check to `front-desk`, or skipped `back-office`, without connecting to anything. Nothing on your PC is changed, and remoting doesn't need to be on.

If PowerShell says the check *cannot be loaded* because it *is not digitally signed*, or because *running scripts is disabled*, the folder came from a download that Windows marked as from the internet. Unblock its files once with `Get-ChildItem -Recurse | Unblock-File`, from this folder, and run `Invoke-Pester` again.

## The rules

- Keep the file's name, `OfficeCheck.ps1`, the tools' names, `Test-PcConnection` and `Get-PcHealth`, and the parameter name `-ComputerName`.
- Keep the properties' names: `ComputerName`, `Answers` and `RemotingOpen`; `ComputerName`, `FreeSpaceGB` and `PrintSpooler`.
- This PC is checked right here, never through `Invoke-Command`. Another PC is reached only when `Test-PcConnection` says its remoting door is open.
- A skipped PC gets a `Write-Warning` that names it, and no row.

## Tips

- `$name -in 'localhost', '127.0.0.1', '.', $env:COMPUTERNAME` is True when `$name` is one of them, capital letters or not.
- `(Test-PcConnection -ComputerName $name).RemotingOpen` reads one property of the object your first tool outputs.
- `continue` inside a `foreach` skips to the next name.
- Without a `process` block, a function sees only the last name that comes down the pipeline.
- A Windows PC often ignores pings, so `Answers` can be False for a PC that's on. That's why Get-PcHealth asks about the door, not the ping.
- Where remoting is on and you're allowed to use it, as on some work networks, give `Get-PcHealth -ComputerName` a real PC's name. The tool doesn't change.

## Hand it in

When it works, push your solution to a public repo of your own on GitHub, then paste that repo's address into **Submit your exercise** on the lesson page at [ask-codey.com](https://www.ask-codey.com). That's what completes the lesson. The lesson page shows the Git commands, step by step.
