#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Setup script for Windows AutoIt GitHub Copilot Agent MCP Configuration tool.

.DESCRIPTION
    This script downloads and installs AutoIt, configures the environment,
    and prepares the system for automated GitHub Copilot agent MCP configuration.

.PARAMETER ForceReinstall
    Force reinstallation even if AutoIt is already installed.

.PARAMETER SkipBrowserCheck
    Skip browser compatibility checks.

.EXAMPLE
    .\setup.ps1
    .\setup.ps1 -ForceReinstall
    .\setup.ps1 -SkipBrowserCheck

.NOTES
    Requires Administrator privileges.
    Compatible with Windows 10/11.
#>

param(
    [switch]$ForceReinstall,
    [switch]$SkipBrowserCheck
)

# Configuration
$AutoItDownloadUrl = "https://www.autoitscript.com/cgi-bin/getfile.pl?autoit3/autoit-v3-setup.exe"
$AutoItInstaller = "$env:TEMP\autoit-v3-setup.exe"
$LogFile = "logs\setup.log"

# Create logs directory
if (!(Test-Path "logs")) {
    New-Item -ItemType Directory -Path "logs" -Force | Out-Null
}

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry
    Add-Content -Path $LogFile -Value $logEntry
}

# Check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check AutoIt installation
function Test-AutoItInstalled {
    $autoItPath = Get-Command "AutoIt3.exe" -ErrorAction SilentlyContinue
    if ($autoItPath) {
        Write-Log "AutoIt found at: $($autoItPath.Source)"
        return $true
    }
    
    # Check common installation paths
    $commonPaths = @(
        "${env:ProgramFiles}\AutoIt3\AutoIt3.exe",
        "${env:ProgramFiles(x86)}\AutoIt3\AutoIt3.exe",
        "${env:USERPROFILE}\AutoIt3\AutoIt3.exe"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            Write-Log "AutoIt found at: $path"
            return $true
        }
    }
    
    return $false
}

# Download AutoIt installer
function Get-AutoItInstaller {
    Write-Log "Downloading AutoIt installer..."
    try {
        Invoke-WebRequest -Uri $AutoItDownloadUrl -OutFile $AutoItInstaller -UseBasicParsing
        Write-Log "AutoIt installer downloaded successfully"
        return $true
    }
    catch {
        Write-Log "Failed to download AutoIt installer: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Install AutoIt
function Install-AutoIt {
    Write-Log "Installing AutoIt..."
    try {
        $process = Start-Process -FilePath $AutoItInstaller -ArgumentList "/S" -Wait -PassThru
        if ($process.ExitCode -eq 0) {
            Write-Log "AutoIt installed successfully"
            return $true
        }
        else {
            Write-Log "AutoIt installation failed with exit code: $($process.ExitCode)" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error during AutoIt installation: $($_.Exception.Message)" "ERROR"
        return $false
    }
    finally {
        # Clean up installer
        if (Test-Path $AutoItInstaller) {
            Remove-Item $AutoItInstaller -Force
        }
    }
}

# Check browser compatibility
function Test-BrowserCompatibility {
    Write-Log "Checking browser compatibility..."
    
    # Check for supported browsers
    $browsers = @(
        @{Name="Chrome"; Path="${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"},
        @{Name="Chrome (x86)"; Path="${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"},
        @{Name="Edge"; Path="${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"},
        @{Name="Firefox"; Path="${env:ProgramFiles}\Mozilla Firefox\firefox.exe"}
    )
    
    $foundBrowser = $false
    foreach ($browser in $browsers) {
        if (Test-Path $browser.Path) {
            Write-Log "Found supported browser: $($browser.Name)"
            $foundBrowser = $true
        }
    }
    
    if (!$foundBrowser) {
        Write-Log "Warning: No supported browsers found. Please install Chrome, Edge, or Firefox." "WARN"
        return $false
    }
    
    return $true
}

# Create configuration files
function New-ConfigurationFiles {
    Write-Log "Creating configuration templates..."
    
    # Create example repository list
    $repoListContent = @"
# Repository list for GitHub Copilot Agent MCP Configuration
# Format: owner/repository
# Example:
# myusername/repo1
# myusername/repo2
# myusername/repo3

# Add your repositories below (remove the # to uncomment):
# owner/repository-name
"@
    Set-Content -Path "config\repos.txt" -Value $repoListContent
    
    # Create example MCP configuration
    $mcpConfigContent = @"
{
  "mcpServers": {
    "github-mcp": {
      "type": "http",
      "url": "https://api.github.com/mcp",
      "headers": {
        "Authorization": "Bearer {{ env.GITHUB_TOKEN }}"
      },
      "tools": [
        "create_repository",
        "list_repositories",
        "get_repository",
        "create_issue",
        "list_issues"
      ]
    },
    "filesystem-mcp": {
      "type": "local",
      "command": "npx",
      "args": [
        "filesystem-mcp"
      ],
      "env": {
        "ROOT_PATH": "/workspace"
      },
      "tools": [
        "read_file",
        "write_file",
        "list_directory",
        "create_directory"
      ]
    }
  }
}
"@
    Set-Content -Path "config\mcp-config.txt" -Value $mcpConfigContent
    
    Write-Log "Configuration templates created in config\ directory"
}

# Main setup function
function Start-Setup {
    Write-Log "Starting AutoIt GitHub Copilot Agent MCP Configuration setup..."
    
    # Check administrator privileges
    if (!(Test-Administrator)) {
        Write-Log "This script requires Administrator privileges. Please run as Administrator." "ERROR"
        exit 1
    }
    
    # Check if AutoIt is already installed
    if ((Test-AutoItInstalled) -and !$ForceReinstall) {
        Write-Log "AutoIt is already installed. Use -ForceReinstall to reinstall."
    }
    else {
        # Download and install AutoIt
        if (Get-AutoItInstaller) {
            if (!(Install-AutoIt)) {
                Write-Log "Setup failed during AutoIt installation." "ERROR"
                exit 1
            }
        }
        else {
            Write-Log "Setup failed during AutoIt download." "ERROR"
            exit 1
        }
    }
    
    # Check browser compatibility
    if (!$SkipBrowserCheck) {
        if (!(Test-BrowserCompatibility)) {
            Write-Log "Browser compatibility check failed. Use -SkipBrowserCheck to continue anyway." "WARN"
        }
    }
    
    # Create configuration files
    New-ConfigurationFiles
    
    # Final verification
    if (Test-AutoItInstalled) {
        Write-Log "Setup completed successfully!" "SUCCESS"
        Write-Log ""
        Write-Log "Next steps:"
        Write-Log "1. Edit config\repos.txt to add your repositories"
        Write-Log "2. Edit config\mcp-config.txt to configure your MCP servers"
        Write-Log "3. Run .\configure-copilot.ps1 to start configuration"
    }
    else {
        Write-Log "Setup verification failed. AutoIt installation may have issues." "ERROR"
        exit 1
    }
}

# Run setup
Start-Setup