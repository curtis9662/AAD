# 🛡️ Enterprise WSL Deployment Runbook [2026 Baseline]

**Document Owner:** DevSecOps / Security Architecture & Engineering  
**Target OS:** Windows 11 (24H2 / 25H2 and later)  
**Session Type:** Team Enablement & TTX  
**Latest Validation:** 2026, IV

---

## 🎯 Session Objectives

This is my WSL Enablement Tabletop! This runbook is designed to guide engineers through deploying the Windows Subsystem for Linux (WSL) on Windows 11 using PowerShell, with a strict focus on **Zero Trust and Advanced Security**.

By the end of this session, your team will understand how to:

1. Prevent **unauthorized distribution** installations  
2. Enforce Hyper-V firewall rules on WSL traffic  
3. Utilize Mirrored Networking and DNS Tunneling for enterprise compliance  

---

## 📋 Phase 1: Environmental Validation

Before making system changes, we must ensure the host environment meets the 2026 security baseline for virtualization.

### 1. Run an Elevated PowerShell Prompt

Right-click your terminal and select **"Run as Administrator"**.

### 2. Verify Host Build & Virtualization Capabilities

~~~powershell
# Validate Windows 11 Build (Ensure >= Build 22631 / 26xxx series for advanced networking)
[System.Environment]::OSVersion.Version

# Verify Virtual Machine Platform status
Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
~~~

> 💬 **Tabletop Prompt:** *Why do we validate the host build first?*  
> **Answer:** Modern WSL security features (like `mirrored` networking and Hyper-V Firewall integration) require specific, recent Windows 11 builds to function correctly.

---

## 🛠️ Phase 2: Hardened WSL Installation

In our enterprise (any secure 🛡🔱) environment, we *do not* want to use the default `wsl --install` command, as it automatically pulls down the default Ubuntu 🐂, distro w/ 0 governance. We will install the subsystem core only.

### 1. Install WSL Core (No Default Distro)

~~~powershell
# Installs the WSL engine and Virtual Machine Platform without downloading an unapproved Linux distro - CJONES
wsl.exe --install --no-distribution
~~~

### 2. Update WSL to the Latest 2026 Core Version

~~~powershell
# Ensures we have the latest security patches and features directly from Microsoft - CJONES
wsl.exe --update
~~~

---

## 🔒 Phase 3: Advanced Security Configuration (`.wslconfig`)

This is the most critical step for enterprise security. We will generate a global `.wslconfig` file to enforce mirrored networking, integrate WSL with the Windows Defender/Hyper-V Firewall, and ensure DNS traffic flows through corporate security controls.

### 1. Generate the Configuration via PowerShell

~~~powershell
# Define the path to the global WSL configuration file - CJONES
$wslConfigPath = "$env:USERPROFILE\.wslconfig"

# Define 2026 secure baseline parameters - CJONES
$wslConfigContent = @"
[wsl2]
# Enforces WSL to share the host's network stack, subjecting it to Windows Firewall rules - CJONES
networkingMode=mirrored

# Ensures Linux DNS requests go through the host's corporate DNS/VPN tunnels - CJONES
dnsTunneling=true

# Strictly applies Windows Hyper-V Firewall rules to the Linux container - CJONES
firewall=true

# Automatically synchronizes host proxy settings to the Linux container - CJONES
autoProxy=true

# Optimizes disk space by automatically releasing unused storage back to Windows - CJONES
sparseVhd=true

# Disables GUI app support if not required for development (Reduces attack surface) - CJONES
guiApplications=false
"@

# Write the configuration - CJONES
Set-Content -Path $wslConfigPath -Value $wslConfigContent -Force

Write-Host "✅ Enterprise .wslconfig successfully deployed to $wslConfigPath" -ForegroundColor Green
~~~

> 💬 **Tabletop Prompt:** *If a developer needs to access a corporate database over the VPN from within WSL, which of the settings above makes this seamlessly secure?*  
> **Answer:** Both `networkingMode=mirrored` and `dnsTunneling=true` ensure that WSL routing and DNS resolution perfectly match the host's VPN tunnel configuration.
⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐
---

## 🐧 Phase 4: Provisioning an Approved Distribution

Now that the foundation is hardened, we will deploy a specific, approved Linux distribution.

### 1. List Available Distributions

~~~powershell
wsl.exe --list --online
~~~

### 2. Install an Approved Distro (e.g., Ubuntu-24.04)

~~~powershell
# Specify the exact distribution required by your enterprise baseline - CJONES
wsl.exe --install -d Ubuntu-24.04
~~~

### 3. Enforce a Non-Root Default User

Once the installation finishes and the terminal prompts you to create a UNIX username and password, **do not use `root`**. Create a standard developer account.

---

## ✅ Phase 5: Verification & Audit Logging

Security isn't complete without verification. Let's validate our deployment.

### 1. Validate the Running Instance and Version

~~~powershell
# Confirm WSL version 2 is running - CJONES
wsl.exe --list --verbose
~~~

### 2. Verify Network Mirroring & DNS within the Distro

Drop into the WSL shell to confirm the security settings applied.

~~~powershell
# Enter the WSL environment - CJONES
wsl.exe

# (Inside Linux) Check that the IP address matches the Windows Host IP
ip addr

# (Inside Linux) Verify DNS resolution is hitting the corporate resolver - CJONES
cat /etc/resolv.conf

# Note: You should see it reflecting the Windows host configuration rather than a virtual switch IP. - C_JONES

# Exit back to PowerShell - C_JONES
exit
~~~

### 3. Restart WSL Engine (If changes are made)

~~~powershell
# Use this command to forcefully restart the WSL engine to apply any future .wslconfig updates - C_JONES
wsl.exe --shutdown
~~~

---

## 🎉 Session Wrap-up

**Congratulations!** We've successfully deployed a zero-trust aligned WSL instance. By leveraging `wsl --install --no-distribution` and a strict `.wslconfig`, you maintain deep visibility and control over developer environments while empowering them with native Linux tooling.


```By - C_JONES```
*Maintainer Note: Please commit any updates to this runbook to the team's Git repository via standard Pull Request procedures.*
