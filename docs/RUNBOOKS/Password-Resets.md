# Runbook: Password Resets

This runbook provides guidance for common password reset scenarios, including Active Directory, Office 365, and local machine accounts. It highlights relevant scripts from the SysAdmin Toolkit.

---

## 1. Active Directory User Password Reset

**Scenario:** A user has forgotten their Active Directory password, or their account is locked out.

**Steps:**

1.  **Verify User Identity:** Always confirm the user's identity through established procedures (e.g., asking security questions, checking ID).
2.  **Open Active Directory Users and Computers (ADUC):**
    *   Navigate to the user account.
    *   Right-click the user account and select "Reset Password...".
3.  **Use SysAdmin Toolkit Script (Recommended):**
    *   For a more automated and auditable approach, use:
        ```powershell
        .\Identity-Access\ActiveDirectory\Reset-UserPasswordAndUnlock.ps1 -SamAccountName "jsmith" -NewPassword "P@ssw0rd123!" -ForcePasswordChangeAtLogon
        ```
    *   This script will:
        *   Unlock the account if it's locked.
        *   Set the new password.
        *   Optionally force the user to change their password at the next logon (highly recommended).
        *   Perform basic password policy checks.
    *   **Note:** If `-NewPassword` is not provided, the script will prompt for a secure string password input.
4.  **Confirm with User:** Inform the user that their password has been reset and if they need to change it at next logon.

---

## 2. Office 365 / Entra ID Password Reset

**Scenario:** A user cannot log in to Office 365 or cloud-only applications.

**Steps:**

1.  **Verify User Identity:** Confirm user identity.
2.  **Open Microsoft 365 Admin Center / Azure Portal:**
    *   Navigate to **Users > Active users** in M365 Admin Center or **Azure Active Directory > Users** in Azure Portal.
    *   Select the user.
    *   Click "Reset password" or "Reset Password" (depending on portal).
3.  **Use PowerShell (Recommended):**
    *   Ensure you are connected to Microsoft Graph: `Connect-MgGraph -Scopes "User.ReadWrite.All"`.
    *   Use the `Update-MgUser` cmdlet:
        ```powershell
        $NewPassword = ConvertTo-SecureString "YourNewPassword123!" -AsPlainText -Force
        Update-MgUser -UserId "jsmith@yourdomain.com" -PasswordProfile @{ ForceChangePasswordNextSignIn = $true; Password = (ConvertTo-SecureString "YourNewPassword123!" -AsPlainText -Force) }
        ```
    *   **Note:** Replace `"jsmith@yourdomain.com"` and `"YourNewPassword123!"` with actual values.
4.  **Confirm with User:** Inform the user about the reset and if they need to change it.

---

## 3. Local Administrator Password Reset (Workstation/Server)

**Scenario:** Need to reset a local administrator password on a machine, especially if it's not domain-joined or LAPS is not in use.

**Steps:**

1.  **Access the Machine:** This might require physical access or console access (e.g., via Hyper-V/VMware console).
2.  **Boot into Recovery Mode (if necessary):** If you cannot log in, you might need to boot into Windows Recovery Environment (WinRE) to access a command prompt.
3.  **Using `net user` (Command Prompt):**
    ```cmd
    net user Administrator NewSecurePassword123!
    ```
    (Replace `Administrator` with the local admin account name and `NewSecurePassword123!` with a strong new password.)
4.  **Consider LAPS:** For domain-joined machines, ensure LAPS (Local Administrator Password Solution) is deployed. The toolkit includes `Security\Get-LAPSStatus.ps1` to check LAPS status.

---

## 4. Account Lockout Troubleshooting

**Scenario:** A user's account is repeatedly locking out, and you need to find the source.

**Steps:**

1.  **Identify Lockout Events:**
    *   Use the toolkit script:
        ```powershell
        .\Identity-Access\ActiveDirectory\Find-AccountLockoutSource.ps1 -UserName "jsmith"
        ```
    *   This script queries Domain Controller logs for lockout event ID 4740 and attempts to identify the source workstation/IP.
2.  **Check Workstation:** If a source workstation is identified, log in (as an administrator) and check:
    *   **Credential Manager:** Look for old, cached credentials.
    *   **Mapped Drives:** Ensure no mapped drives are using old credentials.
    *   **Scheduled Tasks:** Check for tasks running with old credentials.
    *   **Services:** Check for services running with old credentials.
    *   **Mobile Devices:** Advise the user to turn off Wi-Fi on their mobile devices temporarily to rule out mobile sync issues.
3.  **Unlock Account:** Use `.\Identity-Access\ActiveDirectory\Reset-UserPasswordAndUnlock.ps1 -SamAccountName "jsmith" -UnlockOnly`.

---
