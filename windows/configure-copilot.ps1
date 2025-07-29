<#
.SYNOPSIS
    GitHub Copilot Agent MCP Configuration automation using AutoIt.

.DESCRIPTION
    This script automates the configuration of GitHub Copilot agent MCP settings
    across multiple repositories using AutoIt browser automation.

.PARAMETER RepoList
    Path to file containing list of repositories (format: owner/repo).

.PARAMETER McpConfig
    Path to file containing MCP configuration JSON.

.PARAMETER DryRun
    Preview changes without applying them.

.PARAMETER Verbose
    Enable detailed logging.

.PARAMETER Interactive
    Enable interactive mode for manual authentication.

.PARAMETER DelayBetweenRepos
    Delay in seconds between processing repositories (default: 5).

.PARAMETER MaxRetries
    Maximum retry attempts for failed operations (default: 3).

.EXAMPLE
    .\configure-copilot.ps1 -RepoList "config\repos.txt" -McpConfig "config\mcp-config.txt"
    .\configure-copilot.ps1 -RepoList "repos.txt" -McpConfig "mcp.json" -DryRun -Verbose
    .\configure-copilot.ps1 -RepoList "repos.txt" -McpConfig "mcp.json" -Interactive

.NOTES
    Requires AutoIt to be installed (run setup.ps1 first).
    Requires internet connection and GitHub repository access.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$RepoList,
    
    [Parameter(Mandatory=$true)]
    [string]$McpConfig,
    
    [switch]$DryRun,
    [switch]$Verbose,
    [switch]$Interactive,
    
    [int]$DelayBetweenRepos = 5,
    [int]$MaxRetries = 3
)

# Configuration
$LogFile = "logs\configure-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$AutoItScript = "autoit\github-copilot-config.au3"
$AuthScript = "autoit\github-auth.au3"
$TempDir = "$env:TEMP\github-copilot-config"

# Create required directories
@("logs", "temp") | ForEach-Object {
    if (!(Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

# Logging functions
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARN"  { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        default { Write-Host $logEntry }
    }
    
    Add-Content -Path $LogFile -Value $logEntry
}

function Write-VerboseLog {
    param([string]$Message)
    if ($Verbose) {
        Write-Log $Message "VERBOSE"
    }
}

# Validation functions
function Test-Prerequisites {
    Write-Log "Checking prerequisites..."
    
    # Check AutoIt installation
    $autoItPath = Get-Command "AutoIt3.exe" -ErrorAction SilentlyContinue
    if (!$autoItPath) {
        Write-Log "AutoIt not found. Please run setup.ps1 first." "ERROR"
        return $false
    }
    Write-VerboseLog "AutoIt found at: $($autoItPath.Source)"
    
    # Check input files
    if (!(Test-Path $RepoList)) {
        Write-Log "Repository list file not found: $RepoList" "ERROR"
        return $false
    }
    
    if (!(Test-Path $McpConfig)) {
        Write-Log "MCP configuration file not found: $McpConfig" "ERROR"
        return $false
    }
    
    # Check AutoIt scripts
    if (!(Test-Path $AutoItScript)) {
        Write-Log "AutoIt script not found: $AutoItScript" "ERROR"
        return $false
    }
    
    Write-Log "Prerequisites check passed"
    return $true
}

function Get-RepositoryList {
    Write-Log "Reading repository list from: $RepoList"
    
    $repos = @()
    $lines = Get-Content $RepoList | Where-Object { $_ -match '\S' -and !$_.StartsWith('#') }
    
    foreach ($line in $lines) {
        $line = $line.Trim()
        if ($line -match '^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$') {
            $repos += $line
            Write-VerboseLog "Added repository: $line"
        }
        else {
            Write-Log "Invalid repository format: $line" "WARN"
        }
    }
    
    Write-Log "Found $($repos.Count) repositories to process"
    return $repos
}

function Get-McpConfiguration {
    Write-Log "Reading MCP configuration from: $McpConfig"
    
    try {
        $content = Get-Content $McpConfig -Raw
        $json = $content | ConvertFrom-Json
        Write-VerboseLog "MCP configuration loaded successfully"
        return $content
    }
    catch {
        Write-Log "Failed to parse MCP configuration: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Save-TempConfig {
    param([string]$Content)
    
    $tempConfigPath = "$TempDir\mcp-config.json"
    
    # Create temp directory
    if (!(Test-Path $TempDir)) {
        New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
    }
    
    # Save configuration to temp file
    Set-Content -Path $tempConfigPath -Value $Content -Encoding UTF8
    Write-VerboseLog "Saved temporary configuration to: $tempConfigPath"
    
    return $tempConfigPath
}

function Invoke-AutoItScript {
    param(
        [string]$ScriptPath,
        [string]$Repository,
        [string]$ConfigPath,
        [bool]$InteractiveMode = $false
    )
    
    Write-VerboseLog "Invoking AutoIt script: $ScriptPath"
    
    $arguments = @(
        "`"$ScriptPath`"",
        "`"$Repository`"",
        "`"$ConfigPath`""
    )
    
    if ($InteractiveMode) {
        $arguments += "`"interactive`""
    }
    
    if ($DryRun) {
        $arguments += "`"dryrun`""
    }
    
    try {
        $process = Start-Process -FilePath "AutoIt3.exe" -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
        
        Write-VerboseLog "AutoIt process completed with exit code: $($process.ExitCode)"
        return $process.ExitCode -eq 0
    }
    catch {
        Write-Log "Error executing AutoIt script: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Process-Repository {
    param(
        [string]$Repository,
        [string]$ConfigPath,
        [int]$AttemptNumber = 1
    )
    
    Write-Log "Processing repository: $Repository (attempt $AttemptNumber/$MaxRetries)"
    
    if ($DryRun) {
        Write-Log "[DRY RUN] Would configure MCP for repository: $Repository"
        return $true
    }
    
    # Invoke AutoIt script
    $success = Invoke-AutoItScript -ScriptPath $AutoItScript -Repository $Repository -ConfigPath $ConfigPath -InteractiveMode $Interactive
    
    if ($success) {
        Write-Log "Successfully configured repository: $Repository" "SUCCESS"
        return $true
    }
    else {
        if ($AttemptNumber -lt $MaxRetries) {
            Write-Log "Retrying repository: $Repository" "WARN"
            Start-Sleep -Seconds $DelayBetweenRepos
            return Process-Repository -Repository $Repository -ConfigPath $ConfigPath -AttemptNumber ($AttemptNumber + 1)
        }
        else {
            Write-Log "Failed to configure repository after $MaxRetries attempts: $Repository" "ERROR"
            return $false
        }
    }
}

function Show-Summary {
    param(
        [int]$Total,
        [int]$Successful,
        [int]$Failed,
        [array]$FailedRepos
    )
    
    Write-Log ""
    Write-Log "=== CONFIGURATION SUMMARY ==="
    Write-Log "Total repositories: $Total"
    Write-Log "Successful: $Successful" "SUCCESS"
    Write-Log "Failed: $Failed" $(if ($Failed -gt 0) { "ERROR" } else { "INFO" })
    
    if ($Failed -gt 0) {
        Write-Log ""
        Write-Log "Failed repositories:"
        $FailedRepos | ForEach-Object { Write-Log "  - $_" "ERROR" }
    }
    
    Write-Log ""
    Write-Log "Log file: $LogFile"
}

# Main execution function
function Start-Configuration {
    Write-Log "GitHub Copilot Agent MCP Configuration Tool (Windows AutoIt)"
    Write-Log "================================================================"
    
    if ($DryRun) {
        Write-Log "DRY RUN MODE - No changes will be applied" "WARN"
    }
    
    # Check prerequisites
    if (!(Test-Prerequisites)) {
        exit 1
    }
    
    # Load configuration
    $repositories = Get-RepositoryList
    if ($repositories.Count -eq 0) {
        Write-Log "No valid repositories found in list." "ERROR"
        exit 1
    }
    
    $mcpConfig = Get-McpConfiguration
    if (!$mcpConfig) {
        Write-Log "Failed to load MCP configuration." "ERROR"
        exit 1
    }
    
    # Save temporary configuration file
    $tempConfigPath = Save-TempConfig -Content $mcpConfig
    
    # Process repositories
    $successCount = 0
    $failCount = 0
    $failedRepos = @()
    
    Write-Log ""
    Write-Log "Starting repository processing..."
    
    foreach ($repo in $repositories) {
        try {
            if (Process-Repository -Repository $repo -ConfigPath $tempConfigPath) {
                $successCount++
            }
            else {
                $failCount++
                $failedRepos += $repo
            }
            
            # Delay between repositories (except for last one)
            if ($repo -ne $repositories[-1] -and !$DryRun) {
                Write-VerboseLog "Waiting $DelayBetweenRepos seconds before next repository..."
                Start-Sleep -Seconds $DelayBetweenRepos
            }
        }
        catch {
            Write-Log "Unexpected error processing repository $repo`: $($_.Exception.Message)" "ERROR"
            $failCount++
            $failedRepos += $repo
        }
    }
    
    # Cleanup
    if (Test-Path $TempDir) {
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Show summary
    Show-Summary -Total $repositories.Count -Successful $successCount -Failed $failCount -FailedRepos $failedRepos
    
    # Exit with appropriate code
    if ($failCount -gt 0) {
        exit 1
    }
    else {
        Write-Log "All repositories configured successfully!" "SUCCESS"
        exit 0
    }
}

# Start the configuration process
Start-Configuration