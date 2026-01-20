# Legacy Scripts

This folder contains scripts designed for older systems, non-Windows environments (like Linux Bash scripts), or specific appliances that might not fully support modern PowerShell capabilities or standard Windows management tools.

These scripts are kept here for historical reference, specific edge cases, or environments where modernization is not feasible.

---

## 📁 Subfolders

*   **`Bash/`**: Contains Bash shell scripts primarily for Linux systems.
*   **`Windows/`**: Contains PowerShell or batch scripts for older Windows versions or specific legacy scenarios.

---

## 🐧 Running Bash Scripts

Bash scripts (files with `.sh` extension) are typically run on Linux or Unix-like systems.

1.  **Make Executable:** Before running, you often need to make the script executable:
    ```bash
    chmod +x your_script.sh
    ```
2.  **Execute:** Then, you can run it:
    ```bash
    ./your_script.sh
    ```
    Or with `sudo` if it requires root privileges:
    ```bash
    sudo ./your_script.sh
    ```

### Example Cron Entries

Bash scripts are commonly used with `cron` for scheduled tasks.

To edit your cron table:
```bash
crontab -e
```

Example cron entries:
*   Run `disk_report.sh` daily at 3:00 AM, saving output to a log file:
    ```cron
    0 3 * * * /path/to/Legacy/Bash/disk_report.sh > /var/log/disk_report.log 2>&1
    ```
*   Run `service_health.sh` every 10 minutes, emailing output if there are failures:
    ```cron
    */10 * * * * /path/to/Legacy/Bash/service_health.sh && exit 0 || mail -s "Service Health Alert" admin@example.com < /tmp/service_health_output
    ```
    (Note: You might need to redirect script output to a temporary file for `mail` command.)

---

## 🪟 Running Legacy Windows Scripts

Scripts in the `Windows/` subfolder are generally PowerShell or Batch files that target older Windows versions or specific scenarios. Always review these scripts carefully before execution.

---

## ⚠️ Important Considerations

*   **Review Code:** Always review the code of any legacy script before running it. Understand what it does.
*   **Permissions:** Ensure the script has the necessary permissions to execute and access resources.
*   **Environment Differences:** Be aware that behavior can vary significantly across different OS versions and environments.
*   **No Active Development:** Scripts in the `_Legacy` folders are generally not actively maintained or updated. Use at your own discretion.
