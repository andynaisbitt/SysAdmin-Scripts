# SysAdmin Toolkit Scripting Standards

This document outlines the coding standards and best practices for developing scripts within the SysAdmin Toolkit. Adhering to these standards ensures consistency, readability, maintainability, and reusability across the entire project.

---

## 1. Naming Conventions

*   **Files:** Use `Verb-Noun.ps1` format (e.g., `Get-ServiceHealthReport.ps1`, `Invoke-WorkstationTriage.ps1`). The verb should reflect the primary action of the script.
*   **Functions/Cmdlets:** Follow PowerShell's `Verb-Noun` naming convention. For internal helper functions, use a unique prefix (e.g., `_Get-CustomData`).
*   **Variables:** Use descriptive, camelCase names (e.g., `$ComputerName`, `$ExportPath`). Avoid abbreviations where clarity is sacrificed.
*   **Parameters:** Use PascalCase (e.g., `-ComputerName`, `-WhatIf`).

---

## 2. Standard Parameters

Every script should, where applicable, include the following common parameters:

*   **`-ComputerName <string[]>`:**
    *   **Purpose:** Specifies one or more remote computer names to execute the script against.
    *   **Default:** `$env:COMPUTERNAME` (local machine) if not provided and the script supports local execution.
    *   **Implementation:** Use `Invoke-Command` for remote execution.
*   **`-WhatIf <switch>`:**
    *   **Purpose:** Simulates the effect of running the command without performing any actual changes.
    *   **Implementation:** Use `[CmdletBinding(SupportsShouldProcess = $true)]` at the top of the script and wrap destructive actions in `if ($pscmdlet.ShouldProcess("Action description", "Target"))`.
*   **`-Confirm <switch>`:**
    *   **Purpose:** Prompts for confirmation before performing a destructive action.
    *   **Implementation:** Use `[CmdletBinding(SupportsShouldProcess = $true)]` and `ConfirmImpact = 'High'` (or other appropriate level) for destructive scripts.
*   **`-ExportPath <string>`:**
    *   **Purpose:** Specifies a file path to export the script's output (e.g., CSV, HTML, JSON).
    *   **Implementation:** Scripts should internally call `Core\Export-Report.ps1` for consistent output formatting.
*   **`-LogPath <string>`:**
    *   **Purpose:** Specifies a custom log file path for script-specific logging.
    *   **Implementation:** Scripts should internally call `Core\Write-Log.ps1`.

---

## 3. Output Objects

*   **Consistency:** All scripts should output custom PowerShell objects (`[PSCustomObject]`) for structured data. This allows easy piping and filtering.
*   **Properties:** Object properties should be consistently named and represent meaningful data (e.g., `ComputerName`, `Status`, `Message`, `Timestamp`).
*   **Errors/Warnings:** Include a consistent `Error` or `Warning` property in output objects when an operation fails for a specific target, rather than just throwing an error and stopping the entire pipeline.

---

## 4. Error Handling

*   **`try/catch/finally` blocks:** Use these for robust error management, especially when interacting with remote systems or external resources.
*   **`ErrorAction`:** Use `-ErrorAction Stop` for critical operations that must succeed, and `-ErrorAction SilentlyContinue` for non-critical operations where an error doesn't break the script flow.
*   **`Write-Warning` / `Write-Error`:** Use these cmdlets for user feedback on issues, rather than just throwing raw exceptions.
*   **Logging:** All significant events (start, success, failure, warnings) should be logged using `Core\Write-Log.ps1`.

---

## 5. Logging

*   **Centralized Logging:** All scripts *must* use `Core\Write-Log.ps1` for logging script activity.
*   **Log Levels:** Utilize `INFO`, `WARN`, `ERROR`, `DEBUG`, `CRITICAL` levels appropriately.
*   **Default Log File:** By default, logs should go to a `Logs` subfolder relative to the script's location, or a path specified by `-LogPath`.

---

## 6. Code Structure and Readability

*   **Parameter Block:** Always define parameters at the top of the script using `param(...)` block.
*   **CmdletBinding:** Use `[CmdletBinding()]` for advanced features like `SupportsShouldProcess`, `ConfirmImpact`, and common parameters.
*   **Verbosity:** Use `Write-Host` for user-friendly output during interactive execution, and `Write-Verbose` for detailed debug information (controlled by `-$Verbose` common parameter).
*   **Comments:** Use comment-based help (`<# .SYNOPSIS ... #>`) at the top of each script and inline comments for complex logic.
*   **Indentation and Formatting:** Use consistent indentation (4 spaces) and follow PowerShell best practices for code formatting.
*   **No Hardcoding:** Avoid hardcoding paths, credentials, or other configurable values. Use parameters, environment variables, or configuration files.

---

## 7. Dependencies

*   **Module Management:** If a script requires a specific PowerShell module, add a comment at the top (e.g., `# Requires -Module ActiveDirectory`) and optionally include `Import-Module` with error handling.
*   **External Tools:** If a script relies on external executables (e.g., `tshark.exe`, `PrintBrm.exe`), clearly document this dependency in the script's help and ensure appropriate error handling if the tool is not found.

---

## 8. Examples

Each script should include one or more examples in its comment-based help to demonstrate common usage.

---

## 9. Integration with Core Scripts

*   Scripts should import and utilize functions from the `Core` folder (e.g., `.\Core\Write-Log.ps1`, `.\Core\Export-Report.ps1`, `.\Core\Get-Targets.ps1`) to maintain consistency and reduce code duplication. This often involves dot-sourcing (`. .\Core\Write-Log.ps1`).

---

By following these standards, we can ensure the SysAdmin Toolkit remains a high-quality, reliable, and user-friendly resource.
