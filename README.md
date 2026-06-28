# Bypass MDM for macOS 💻

![mdm-screen](https://raw.githubusercontent.com/assafdori/bypass-mdm/main/mdm-screen.png)

A script to bypass Mobile Device Management (MDM) enrollment during macOS setup.

## 🚨 Update: June 28, 2026

**Version 4 Now Available!** This fork introduces full external storage support and multi-installation detection — fixing the issue where v3 would silently target the internal drive even when an external drive was intended.

### What's New in v4:

- **🖥️ External Storage Support** - Works on both internal and external macOS installations
- **🔎 Multi-Installation Detection** - Scans all mounted volumes and presents a numbered menu when multiple macOS installations are detected, showing System Volume, Data Volume, and Disk ID (e.g. `disk2s5`) so you can tell internal from external
- **⚡ Auto-Select for Single Installs** - If only one installation is found, it is selected automatically — no extra prompt
- **🚫 No Volume Renaming** - Removed the unreliable auto-rename of data volumes that could cause conflicts when multiple installs were present
- **✅ Correct Home Directory** - User home folder is always created on the chosen installation's data volume, not the internal drive

> The instructions below use **v4 by default** (recommended). You can use an older version by replacing `bypass-mdm-v4.sh` in the commands.

---

## ✨ Features

- **🔍 Smart Volume Detection** - Automatically detects all macOS system and data volumes, including on external drives
- **🖥️ Multi-Installation Selection** - Prompts you to choose when more than one macOS installation is found
- **✅ Input Validation** - Validates usernames and passwords to prevent common errors
- **🛡️ Comprehensive Error Handling** - Clear error messages guide you through any issues
- **🎯 UID Conflict Resolution** - Automatically finds available user IDs to avoid conflicts
- **📊 Real-time Progress** - Color-coded status messages show exactly what's happening
- **🔄 Duplicate Prevention** - Checks for existing entries to avoid duplicates

## ⚠️ Prerequisites

- **It is strongly recommended to erase the hard drive prior to starting**
- **It is recommended to reinstall macOS using an external flash drive**
- **English language recommended**
- **If targeting an external drive:** make sure it is connected and mounted before running the script

## 📋 Installation & Usage

### Step-by-Step Instructions

Follow these steps to bypass MDM enrollment during a fresh macOS installation:

> **Starting Point:** You've reached the MDM enrollment screen during macOS setup

**1.** **Force Shutdown** - Long press the Power button to shut down your Mac

**2.** **Boot into Recovery Mode:**

- **Apple Silicon Mac**: Hold Power button until "Loading startup options" appears
- **Intel-based Mac**: Hold <kbd>CMD</kbd> + <kbd>R</kbd> during boot

**3.** **Connect to WiFi** to activate your Mac

**4.** **Open Terminal** in Recovery Mode:

- Click **Utilities** in the menu bar
- Select **Terminal**

**5.** *(External drive only)* **Mount your external drive** if it isn't already visible in Disk Utility:

```bash
diskutil list          # find your external disk identifier (e.g. disk2)
diskutil mountDisk disk2
```

**6.** **Run the bypass script** - Copy and paste this command into Terminal:

```bash
curl -L https://raw.githubusercontent.com/roygoraposonjr/bypass-mdm/main/bypass-mdm-v4.sh -o bypass-mdm.sh && chmod +x ./bypass-mdm.sh && ./bypass-mdm.sh
```

**7.** **Volume Detection** - The script will automatically scan all mounted volumes:

- If **one** macOS installation is found → it is selected automatically
- If **multiple** installations are found → you will see a selection menu like this:

```
╔══════════════════════════════════════════════════════╗
║  Multiple macOS installations detected               ║
║  Please choose the one you want to bypass MDM on:    ║
╚══════════════════════════════════════════════════════╝

  [1]  System Volume : Macintosh HD
       Data Volume   : Macintosh HD - Data
       Disk ID       : disk1s1

  [2]  System Volume : ExternalMac
       Data Volume   : ExternalMac - Data
       Disk ID       : disk2s1

Enter the number of the installation to target [1-2]:
```

Use the **Disk ID** to identify internal (`disk0` / `disk1`) vs external (`disk2`, `disk3`, etc.) drives.

**8.** **Select Option 1** - "Bypass MDM from Recovery"

**9.** **Create Temporary User** - Configure the admin account (or press Enter for defaults):

- **Fullname**: Apple (default)
- **Username**: Apple (default)
- **Password**: 1234 (default)

> 💡 **Tip:** The script validates your input and will prompt you to retry if there are issues

**10.** **Wait for Completion** - You'll see progress messages:

- ✓ Validating system paths
- ✓ Creating user account
- ✓ Blocking MDM domains
- ✓ Configuring MDM bypass settings

**11.** **Reboot** - When you see "MDM Bypass Completed Successfully", close Terminal and reboot

---

### 🔄 Post-Installation Steps

**12.** **Login** with the temporary account:

- Username: `Apple` (or your custom username)
- Password: `1234` (or your custom password)

**13.** **Skip Setup** - Skip all prompts (Apple ID, Siri, Touch ID, Location Services)

**14.** **Create Real Account:**

- Navigate to **System Settings > Users and Groups**
- Create your actual Admin account with your preferred credentials

**15.** **Switch Accounts** - Log out and sign in to your new account

**16.** **Setup Properly** - Now configure Apple ID, Siri, Touch ID, etc.

**17.** **Clean Up** - Delete the temporary Apple profile:

- Go to **System Settings > Users and Groups**
- Select the Apple profile and click the minus (−) button

**18.** **🎉 Done!** You're MDM free!

---

## 🔧 Troubleshooting

### Volume Detection Issues

**Problem:** Script fails to detect volumes

**Solutions:**

- Ensure you're in Recovery Mode (not booted into macOS normally)
- Verify macOS is installed on your drive
- Check your drive is visible in Disk Utility
- For external drives, make sure the drive is mounted (`diskutil mountDisk diskX`)
- Try an older version:

```bash
curl -L https://raw.githubusercontent.com/roygoraposonjr/bypass-mdm/main/bypass-mdm-v3.sh -o bypass-mdm.sh && chmod +x ./bypass-mdm.sh && ./bypass-mdm.sh
```

### `mapfile` / bash version error

**Problem:** Script exits immediately with a `mapfile` error

**Cause:** macOS Recovery ships with bash 3.2 which does not support `mapfile`

**Solution:** Run bash explicitly with a newer version if available, or use v3 as a fallback.

### Permission Errors

**Problem:** Permission denied errors

**Solutions:**

- Confirm you're running from Terminal in Recovery Mode
- Recovery Mode automatically provides elevated privileges
- Make sure the script is executable: `chmod +x bypass-mdm.sh`

### Script Won't Execute

**Problem:** Script doesn't run

**Solutions:**

```bash
# Make sure it's executable
chmod +x bypass-mdm.sh

# Run it again
./bypass-mdm.sh
```

### Invalid Username or Password

**Problem:** Script rejects your username/password

**Validation Rules:**

- **Username:** Letters, numbers, underscore, hyphen only; must start with letter or underscore
- **Password:** Minimum 4 characters
- Press Enter to use defaults if unsure

---

## 📦 Version Information

| Version             | Description                                                         | Status              |
| ------------------- | ------------------------------------------------------------------- | ------------------- |
| `bypass-mdm-v4.sh`  | External storage support, multi-installation selection, no rename   | ✅ **Recommended**  |
| `bypass-mdm-v3.sh`  | Enhanced auto-detection & validation (internal drive only)          | ⚠️ Previous         |
| `bypass-mdm-v2.sh`  | Original auto-detection version                                     | ⚠️ Legacy           |
| `bypass-mdm.sh`     | Original version with hardcoded volume names                        | ⚠️ Legacy           |

---

## ⚖️ Legal Disclaimer

> **Important:** Although it's virtually impossible to detect that you've removed MDM (because it was never configured locally), be aware that your device's serial number will still appear in your organization's inventory system. This script prevents MDM from being configured locally, making the device unmanageable remotely.
>
> **Use responsibly and at your own risk.** This tool is intended for personal devices and should not be used to circumvent legitimate organizational policies without proper authorization.

---

## 📄 License

This project is provided as-is for educational purposes. Use at your own discretion.

> Originally by [Assaf Dori](https://assafdori.com). Extended with external storage support by [roygoraposonjr](https://github.com/roygoraposonjr/bypass-mdm).
