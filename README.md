# Codex Runtime Repair (Windows)

> **Unofficial community tool.** Not affiliated with, endorsed by, or supported by OpenAI. Use at your own risk.

[简体中文](README.zh-CN.md)

A small PowerShell repair tool for **Codex Desktop on Windows** when the app seems to start — `ChatGPT.exe` stays in the background — but no window appears.

## Symptoms

- Codex Desktop does not open a window after launch.
- One or more `ChatGPT.exe` processes stay in Task Manager.
- Restarting the app or Windows does not help.
- The problem often follows an update, a crashed update, or an interrupted runtime staging step.

## What it fixes

Codex ships a bundled `cua_node` runtime. On startup it is staged and moved into:

```
%LOCALAPPDATA%\OpenAI\Codex\runtimes\cua_node\<runtime-id>
```

If staging is interrupted, a `.staging-<runtime-id>-*` folder can be left behind while the final `<runtime-id>` folder is missing or incomplete. Codex then keeps waiting and never shows a window.

This script rebuilds that folder from the runtime files inside the installed package, verifies the copy, and only then removes the staging leftovers.

## Requirements

- Windows 10 or Windows 11
- Codex Desktop installed as an AppX/MSIX package (`OpenAI.Codex`)
- Windows PowerShell 5.1 (included with Windows)
- A normal user session — **do not use "Run as administrator"**

## Quick start

1. Download this repository (Code → Download ZIP) or the latest release.
2. Extract it to any folder. Do not run it from inside the ZIP.
3. Double-click `Run-Repair.bat`.
4. Read the result, then start Codex normally.

No paths need to be edited — the script finds the installed package and runtime folder automatically.

## Manual usage

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Repair-CodexRuntime.ps1
```

Show the built-in help:

```powershell
Get-Help .\Repair-CodexRuntime.ps1 -Full
```

## What the script does

1. Finds the installed `OpenAI.Codex` package and reads its version.
2. Locates the official `cua_node` source inside the package.
3. Finds the newest `.staging-*` folder and reads its runtime ID.
4. Stops only `ChatGPT.exe` processes that run from the Codex install folder.
5. Copies the runtime with `xcopy /E /I /H /Y /G`.
6. Verifies `bin\node.exe` and `bin\node_repl.exe`.
7. Compares file counts between the source and destination.
8. Removes `.staging-*` folders only after steps 6 and 7 pass.

`/G` keeps the copy usable without administrator rights, which matters because MSIX files carry special ACLs.

## Safety

- Does not require administrator rights and warns if the window is elevated.
- Does not touch the installed package; files are only read from it.
- Does not delete an existing runtime folder.
- Only stops Codex `ChatGPT.exe` processes (matched by install path), not other apps with the same name.
- Deletes staging folders only after both verification checks pass.
- Makes no registry, service, or system configuration changes.

Running the script again is safe; it simply repeats the checks.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Repair completed, or there was nothing to repair. |
| `1` | A required check failed. Staging files were left in place. |
| `2` | The copy finished, but the destination has fewer files than the source. Staging files were left in place. |

## Troubleshooting

| Problem | What to do |
|---|---|
| `Package 'OpenAI.Codex' was not found` | Codex is not installed for the current Windows user. Install it, or run the script as the user who installed it. |
| `No .staging-* directory found` | Start Codex once so the failure happens, then run the script again. If Codex opens normally, no repair is needed. |
| `xcopy failed` | Close Codex and retry. Check free disk space and that the runtime folder is writable. |
| `Destination has fewer files` | Run the script again. If it repeats, inspect the copy manually or reinstall Codex. |
| Core files are missing | The runtime source in the package may be damaged. Repair or reinstall Codex Desktop. |
| Still no window | Make sure Codex was started normally, not as administrator. Then check the Codex application logs. |

## Configuration

The script auto-detects everything. The only reason to edit it is if OpenAI changes the package name or folder layout. The settings are at the top of `Repair-CodexRuntime.ps1`:

```powershell
$PackageName         = "OpenAI.Codex"
$InstallRelativePath = "app\resources\cua_node"
$AppDataFolder       = "OpenAI\Codex"
$RuntimeName         = "cua_node"
$ProcessName         = "ChatGPT"
```

## Publishing checklist (maintainers)

This repository intentionally contains **no hard-coded repository URLs, usernames, or local file paths**. Before publishing your own copy or fork:

- [ ] In `LICENSE`, replace `<YOUR NAME OR ORGANIZATION>` with the copyright holder.
- [ ] Optionally add your repository URL, badges, or contact details to both READMEs — they are intentionally left out.
- [ ] Keep `Run-Repair.bat` and `Repair-CodexRuntime.ps1` in the same folder; the launcher uses `%~dp0`, so the folder can be moved anywhere.
- [ ] For a release, package these files together as a ZIP:
  - `Run-Repair.bat`
  - `Repair-CodexRuntime.ps1`
  - `README.md`
  - `README.zh-CN.md`
  - `LICENSE`
- [ ] If you rename the repository or either script, update the manual command in this README.
- [ ] Test the ZIP from a clean folder (and ideally a clean Windows user profile) before publishing.

## Contributing

Issues and pull requests are welcome. Please include:

- your Windows version and Codex version (shown by the script),
- the full console output,
- the steps that reproduce the problem.

Do not paste personal file paths, tokens, or other private data.

## License

[MIT](LICENSE)
