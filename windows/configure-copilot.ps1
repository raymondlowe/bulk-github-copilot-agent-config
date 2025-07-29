<#
.SYNOPSIS
    GitHub Copilot Agent MCP Configuration automation using AutoIt.

.DESCRIPTION
    This script automates the configuration of GitHub Copilot agent MCP settings
    across multiple repositories using AutoIt browser automation.
    
    Features:
    - Test against a small subset of repositories first
    - Dry run mode to preview changes
    - Interactive authentication support
    - Configurable automation parameters
    - Comprehensive logging and error handling
    - Easy adjustment of timing and interaction parameters

.PARAMETER RepoList
    Path to file containing list of repositories (format: owner/repo).

.PARAMETER McpConfig
    Path to file containing MCP configuration JSON.

.PARAMETER DryRun
    Preview changes without applying them.

.PARAMETER Verbose
    Enable detailed logging and progress information.

.PARAMETER Interactive
    Enable interactive mode for manual authentication.

.PARAMETER TestFirst
    Number of repositories to test first before processing all (default: 0 = process all).
    Useful for testing the automation on a small subset before running on all repositories.

.PARAMETER DelayBetweenRepos
    Delay in seconds between processing repositories (default: 5).
    Increase if you experience rate limiting or want to be more cautious.

.PARAMETER MaxRetries
    Maximum retry attempts for failed operations (default: 3).
    Each repository will be retried this many times before marking as failed.

.PARAMETER TabAttempts
    Number of Tab key presses to try when searching for MCP configuration field (default: 20).
    Increase if the field is deeper in the page structure.

.PARAMETER ActionDelay
    Delay in milliseconds between AutoIt actions (default: 500).
    Increase if automation is too fast for the browser to keep up.

.PARAMETER PageLoadDelay
    Delay in seconds to wait for pages to load (default: 3).
    Increase for slower internet connections or when pages take longer to load.

.EXAMPLE
    # Test automation on first 2 repositories only
    .\configure-copilot.ps1 -RepoList "config\repos.txt" -McpConfig "config\mcp-config.txt" -TestFirst 2 -Verbose

.EXAMPLE
    # Dry run on all repositories with detailed logging
    .\configure-copilot.ps1 -RepoList "repos.txt" -McpConfig "mcp.json" -DryRun -Verbose

.EXAMPLE
    # Interactive mode with slower automation timing
    .\configure-copilot.ps1 -RepoList "repos.txt" -McpConfig "mcp.json" -Interactive -ActionDelay 1000 -PageLoadDelay 5

.EXAMPLE
    # Production run with custom retry and tab settings
    .\configure-copilot.ps1 -RepoList "repos.txt" -McpConfig "mcp.json" -MaxRetries 5 -TabAttempts 30

.NOTES
    Requires AutoIt to be installed (run setup.ps1 first).
    Requires internet connection and GitHub repository access.
    
    For troubleshooting:
    - Use -TestFirst 1 to test on a single repository
    - Use -Verbose to see detailed progress information
    - Adjust timing parameters if automation is too fast/slow
    - Check logs directory for detailed AutoIt execution logs
#>

param(
    [Parameter(Mandatory=$true, HelpMessage="Path to file containing repository list")]
    [string]$RepoList,
    
    [Parameter(Mandatory=$true, HelpMessage="Path to file containing MCP configuration")]
    [string]$McpConfig,
    
    [switch]$DryRun,
    [switch]$Verbose,
    [switch]$Interactive,
    
    [Parameter(HelpMessage="Test on this many repositories first (0 = all)")]
    [int]$TestFirst = 0,
    
    [Parameter(HelpMessage="Delay in seconds between processing repositories")]
    [int]$DelayBetweenRepos = 5,
    
    [Parameter(HelpMessage="Maximum retry attempts for failed operations")]
    [int]$MaxRetries = 3,
    
    [Parameter(HelpMessage="Number of Tab key presses when searching for MCP field")]
    [int]$TabAttempts = 20,
    
    [Parameter(HelpMessage="Delay in milliseconds between AutoIt actions")]
    [int]$ActionDelay = 500,
    
    [Parameter(HelpMessage="Delay in seconds to wait for pages to load")]
    [int]$PageLoadDelay = 3
)

# Configuration and global variables
$LogFile = "logs\configure-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$AutoItScript = "autoit\github-copilot-config.au3"
$AuthScript = "autoit\github-auth.au3"
$TempDir = "$env:TEMP\github-copilot-config"

# Global configuration passed to AutoIt scripts
$GlobalConfig = @{
    TabAttempts = $TabAttempts
    ActionDelay = $ActionDelay
    PageLoadDelay = $PageLoadDelay
    MaxRetries = $MaxRetries
    Verbose = $Verbose.IsPresent
    Interactive = $Interactive.IsPresent
    DryRun = $DryRun.IsPresent
}

Write-Host "🚀 GitHub Copilot Agent MCP Configuration Tool (Windows AutoIt)" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# Show configuration summary
Write-Host ""
Write-Host "📋 Configuration Summary:" -ForegroundColor Yellow
Write-Host "  Repository List: $RepoList" -ForegroundColor Gray
Write-Host "  MCP Config: $McpConfig" -ForegroundColor Gray
Write-Host "  Test First: $(if ($TestFirst -eq 0) { 'All repositories' } else { "$TestFirst repositories" })" -ForegroundColor Gray
Write-Host "  Dry Run: $($DryRun.IsPresent)" -ForegroundColor Gray
Write-Host "  Interactive Mode: $($Interactive.IsPresent)" -ForegroundColor Gray
Write-Host "  Verbose Logging: $($Verbose.IsPresent)" -ForegroundColor Gray
Write-Host "  Tab Attempts: $TabAttempts" -ForegroundColor Gray
Write-Host "  Action Delay: ${ActionDelay}ms" -ForegroundColor Gray
Write-Host "  Page Load Delay: ${PageLoadDelay}s" -ForegroundColor Gray
Write-Host "  Max Retries: $MaxRetries" -ForegroundColor Gray
Write-Host "  Delay Between Repos: ${DelayBetweenRepos}s" -ForegroundColor Gray
Write-Host ""

if ($DryRun) {
    Write-Host "🔍 DRY RUN MODE - No changes will be applied" -ForegroundColor Yellow
    Write-Host ""
}

# Create required directories
@("logs", "temp") | ForEach-Object {
    if (!(Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

# Enhanced logging functions with verbose support
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Color coding for different log levels
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARN"  { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        "VERBOSE" { 
            if ($Verbose) { 
                Write-Host $logEntry -ForegroundColor Cyan 
            }
        }
        "PROGRESS" { Write-Host $logEntry -ForegroundColor Magenta }
        default { Write-Host $logEntry }
    }
    
    # Always write to log file, regardless of verbose setting
    Add-Content -Path $LogFile -Value $logEntry -ErrorAction SilentlyContinue
}

function Write-VerboseLog {
    param([string]$Message)
    Write-Log $Message "VERBOSE"
}

function Write-ProgressLog {
    param([string]$Message)
    Write-Log $Message "PROGRESS"
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
    Write-ProgressLog "Reading repository list from: $RepoList"
    
    $repos = @()
    $lines = Get-Content $RepoList | Where-Object { $_ -match '\S' -and !$_.StartsWith('#') }
    
    Write-VerboseLog "Found $($lines.Count) non-empty lines in repository list"
    
    foreach ($line in $lines) {
        $line = $line.Trim()
        Write-VerboseLog "Processing line: '$line'"
        
        if ($line -match '^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$') {
            $repos += $line
            Write-VerboseLog "✓ Added repository: $line"
        }
        else {
            Write-Log "⚠ Invalid repository format (skipping): $line" "WARN"
        }
    }
    
    Write-Log "📊 Found $($repos.Count) valid repositories to process"
    
    # Apply TestFirst limitation if specified
    if ($TestFirst -gt 0 -and $repos.Count -gt $TestFirst) {
        $originalCount = $repos.Count
        $repos = $repos[0..($TestFirst-1)]
        Write-Log "🧪 TEST MODE: Limited to first $TestFirst repositories (of $originalCount total)" "WARN"
        Write-Host ""
        Write-Host "📝 Repositories to be processed in test mode:" -ForegroundColor Yellow
        for ($i = 0; $i -lt $repos.Count; $i++) {
            Write-Host "  $($i+1). $($repos[$i])" -ForegroundColor Gray
        }
        Write-Host ""
        
        # Ask for confirmation when testing
        if (!$DryRun) {
            $response = Read-Host "Continue with these $($repos.Count) repositories? (y/N)"
            if ($response -notmatch '^[Yy]') {
                Write-Log "❌ Operation cancelled by user" "ERROR"
                exit 1
            }
        }
    }
    else {
        Write-VerboseLog "Processing all repositories (no test limitation)"
        if ($repos.Count -gt 0) {
            Write-Host "📝 All repositories to be processed:" -ForegroundColor Yellow
            for ($i = 0; $i -lt $repos.Count; $i++) {
                Write-Host "  $($i+1). $($repos[$i])" -ForegroundColor Gray
            }
            Write-Host ""
        }
    }
    
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
    
    Write-VerboseLog "🔧 Preparing AutoIt script execution"
    Write-VerboseLog "  Script: $ScriptPath"
    Write-VerboseLog "  Repository: $Repository"
    Write-VerboseLog "  Config: $ConfigPath"
    Write-VerboseLog "  Interactive: $InteractiveMode"
    Write-VerboseLog "  Tab Attempts: $TabAttempts"
    Write-VerboseLog "  Action Delay: ${ActionDelay}ms"
    Write-VerboseLog "  Page Load Delay: ${PageLoadDelay}s"
    
    # Build arguments for AutoIt script
    # Format: script.au3 repository config-path [interactive] [dryrun] [tab-attempts] [action-delay] [page-delay]
    $arguments = @(
        "`"$ScriptPath`"",
        "`"$Repository`"",
        "`"$ConfigPath`""
    )
    
    # Add optional mode flags
    if ($InteractiveMode) {
        $arguments += "`"interactive`""
        Write-VerboseLog "  Added interactive mode flag"
    }
    
    if ($DryRun) {
        $arguments += "`"dryrun`""
        Write-VerboseLog "  Added dry run mode flag"
    }
    
    # Add configuration parameters
    $arguments += "`"$TabAttempts`""
    $arguments += "`"$ActionDelay`""
    $arguments += "`"$PageLoadDelay`""
    
    Write-VerboseLog "  AutoIt arguments: $($arguments -join ' ')"
    
    try {
        Write-ProgressLog "🤖 Executing AutoIt automation for $Repository"
        
        $startTime = Get-Date
        $process = Start-Process -FilePath "AutoIt3.exe" -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        Write-VerboseLog "  AutoIt process completed in $($duration.TotalSeconds) seconds"
        Write-VerboseLog "  Exit code: $($process.ExitCode)"
        
        # Interpret exit codes
        switch ($process.ExitCode) {
            0 { 
                Write-VerboseLog "  ✅ AutoIt script completed successfully"
                return $true
            }
            1 { 
                Write-Log "  ❌ AutoIt script failed with general error" "ERROR"
                return $false
            }
            2 { 
                Write-Log "  🔐 AutoIt script failed due to authentication issues" "ERROR"
                return $false
            }
            3 { 
                Write-Log "  🌐 AutoIt script failed due to navigation issues" "ERROR"
                return $false
            }
            4 { 
                Write-Log "  🔍 AutoIt script failed to find MCP configuration field" "ERROR"
                return $false
            }
            5 { 
                Write-Log "  💾 AutoIt script failed to save configuration" "ERROR"
                return $false
            }
            default { 
                Write-Log "  ❓ AutoIt script failed with unknown exit code: $($process.ExitCode)" "ERROR"
                return $false
            }
        }
    }
    catch {
        Write-Log "💥 Error executing AutoIt script: $($_.Exception.Message)" "ERROR"
        Write-VerboseLog "  Exception details: $($_.Exception.ToString())"
        return $false
    }
}

function Process-Repository {
    param(
        [string]$Repository,
        [string]$ConfigPath,
        [int]$AttemptNumber = 1,
        [int]$RepositoryIndex = 0,
        [int]$TotalRepositories = 1
    )
    
    Write-Host ""
    Write-ProgressLog "🏃‍♂️ Processing repository [$($RepositoryIndex + 1)/$TotalRepositories]: $Repository (attempt $AttemptNumber/$MaxRetries)"
    
    if ($DryRun) {
        Write-Log "🔍 [DRY RUN] Would configure MCP for repository: $Repository"
        Write-VerboseLog "  Would navigate to: https://github.com/$Repository/settings/copilot/coding_agent"
        Write-VerboseLog "  Would use Tab attempts: $TabAttempts"
        Write-VerboseLog "  Would use action delay: ${ActionDelay}ms"
        Write-VerboseLog "  Would use page load delay: ${PageLoadDelay}s"
        Write-VerboseLog "  Would apply MCP configuration from: $ConfigPath"
        
        # Simulate processing time for realistic dry run
        Start-Sleep -Seconds 2
        return $true
    }
    
    Write-VerboseLog "🎯 Starting automation for repository: $Repository"
    Write-VerboseLog "  Target URL: https://github.com/$Repository/settings/copilot/coding_agent"
    Write-VerboseLog "  Configuration source: $ConfigPath"
    Write-VerboseLog "  Attempt: $AttemptNumber of $MaxRetries"
    
    # Invoke AutoIt script with current configuration
    $success = Invoke-AutoItScript -ScriptPath $AutoItScript -Repository $Repository -ConfigPath $ConfigPath -InteractiveMode $Interactive
    
    if ($success) {
        Write-Log "✅ Successfully configured repository: $Repository" "SUCCESS"
        Write-VerboseLog "  Configuration applied and saved successfully"
        return $true
    }
    else {
        Write-Log "❌ Failed to configure repository: $Repository (attempt $AttemptNumber)" "ERROR"
        
        if ($AttemptNumber -lt $MaxRetries) {
            Write-Log "🔄 Retrying repository: $Repository" "WARN"
            Write-VerboseLog "  Waiting $DelayBetweenRepos seconds before retry..."
            Start-Sleep -Seconds $DelayBetweenRepos
            
            # Recursive retry with incremented attempt number
            return Process-Repository -Repository $Repository -ConfigPath $ConfigPath -AttemptNumber ($AttemptNumber + 1) -RepositoryIndex $RepositoryIndex -TotalRepositories $TotalRepositories
        }
        else {
            Write-Log "💥 Failed to configure repository after $MaxRetries attempts: $Repository" "ERROR"
            Write-VerboseLog "  All retry attempts exhausted"
            return $false
        }
    }
}

function Show-Summary {
    param(
        [int]$Total,
        [int]$Successful,
        [int]$Failed,
        [array]$FailedRepos,
        [TimeSpan]$Duration
    )
    
    Write-Host ""
    Write-Log "📊 CONFIGURATION BATCH SUMMARY" "PROGRESS"
    Write-Log "==============================" "PROGRESS"
    Write-Log "⏱️  Total execution time: $($Duration.ToString('hh\:mm\:ss'))"
    Write-Log "📈 Total repositories processed: $Total"
    Write-Log "✅ Successfully configured: $Successful" $(if ($Successful -gt 0) { "SUCCESS" } else { "INFO" })
    Write-Log "❌ Failed to configure: $Failed" $(if ($Failed -gt 0) { "ERROR" } else { "INFO" })
    
    if ($Total -gt 0) {
        $successRate = [math]::Round(($Successful / $Total) * 100, 1)
        Write-Log "📊 Success rate: $successRate%"
    }
    
    if ($Failed -gt 0) {
        Write-Host ""
        Write-Log "❌ Failed repositories:" "ERROR"
        for ($i = 0; $i -lt $FailedRepos.Count; $i++) {
            Write-Log "  $($i + 1). $($FailedRepos[$i])" "ERROR"
        }
        
        Write-Host ""
        Write-Log "💡 Troubleshooting suggestions:" "WARN"
        Write-Log "  • Check internet connectivity and GitHub access"
        Write-Log "  • Verify repository permissions (must have admin access)"
        Write-Log "  • Try running with -Interactive flag for manual authentication"
        Write-Log "  • Use -TestFirst 1 to test automation on a single repository"
        Write-Log "  • Increase timing delays: -ActionDelay 1000 -PageLoadDelay 5"
        Write-Log "  • Check logs in logs\ directory for detailed error information"
    }
    
    if ($TestFirst -gt 0) {
        Write-Host ""
        Write-Log "🧪 TEST MODE COMPLETE" "WARN"
        Write-Log "This was a test run on the first $TestFirst repositories."
        if ($Successful -eq $TestFirst) {
            Write-Log "✅ All test repositories succeeded! You can now run on all repositories."
            Write-Log "💡 To process all repositories, run without -TestFirst parameter:"
            Write-Log "   .\configure-copilot.ps1 -RepoList '$RepoList' -McpConfig '$McpConfig'"
        }
        else {
            Write-Log "⚠️  Some test repositories failed. Please review and adjust settings before processing all repositories."
            Write-Log "💡 Consider adjusting timing parameters or using interactive mode."
        }
    }
    
    Write-Host ""
    Write-Log "📋 Log file location: $LogFile"
    
    if ($Verbose) {
        Write-VerboseLog "Detailed execution statistics:"
        Write-VerboseLog "  Average time per repository: $($Duration.TotalSeconds / $Total) seconds"
        Write-VerboseLog "  Configuration parameters used:"
        Write-VerboseLog "    - Tab attempts: $TabAttempts"
        Write-VerboseLog "    - Action delay: ${ActionDelay}ms"
        Write-VerboseLog "    - Page load delay: ${PageLoadDelay}s"
        Write-VerboseLog "    - Max retries: $MaxRetries"
        Write-VerboseLog "    - Delay between repos: ${DelayBetweenRepos}s"
    }
}

# Main execution function
function Start-Configuration {
    Write-Log "🎯 GitHub Copilot Agent MCP Configuration Tool Starting..." "PROGRESS"
    
    # Create required directories with detailed logging
    @("logs", "temp") | ForEach-Object {
        if (!(Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
            Write-VerboseLog "Created directory: $_"
        } else {
            Write-VerboseLog "Directory already exists: $_"
        }
    }
    
    # Check prerequisites with enhanced validation
    Write-ProgressLog "🔍 Validating prerequisites and configuration..."
    if (!(Test-Prerequisites)) {
        Write-Log "❌ Prerequisites check failed - cannot continue" "ERROR"
        exit 1
    }
    Write-Log "✅ Prerequisites validation passed" "SUCCESS"
    
    # Load and validate configuration
    Write-ProgressLog "📋 Loading repository list and MCP configuration..."
    $repositories = Get-RepositoryList
    if ($repositories.Count -eq 0) {
        Write-Log "❌ No valid repositories found in list - cannot continue" "ERROR"
        exit 1
    }
    
    $mcpConfig = Get-McpConfiguration
    if (!$mcpConfig) {
        Write-Log "❌ Failed to load MCP configuration - cannot continue" "ERROR"
        exit 1
    }
    Write-Log "✅ Configuration loading completed successfully" "SUCCESS"
    
    # Save temporary configuration file for AutoIt
    Write-VerboseLog "💾 Preparing temporary configuration file for AutoIt..."
    $tempConfigPath = Save-TempConfig -Content $mcpConfig
    Write-VerboseLog "Temporary config saved to: $tempConfigPath"
    
    # Initialize processing statistics
    $successCount = 0
    $failCount = 0
    $failedRepos = @()
    $startTime = Get-Date
    
    Write-Host ""
    Write-ProgressLog "🚀 Starting repository processing batch..."
    Write-Log "📊 Processing $($repositories.Count) repositories with the following settings:" "PROGRESS"
    Write-Log "  - Max retries per repository: $MaxRetries"
    Write-Log "  - Delay between repositories: ${DelayBetweenRepos}s"
    Write-Log "  - Tab navigation attempts: $TabAttempts"
    Write-Log "  - Action delay: ${ActionDelay}ms"
    Write-Log "  - Page load delay: ${PageLoadDelay}s"
    Write-Log "  - Interactive mode: $($Interactive.IsPresent)"
    Write-Log "  - Dry run mode: $($DryRun.IsPresent)"
    Write-Host ""
    
    # Process each repository with detailed progress tracking
    for ($i = 0; $i -lt $repositories.Count; $i++) {
        $repo = $repositories[$i]
        $progressPercent = [math]::Round((($i + 1) / $repositories.Count) * 100, 1)
        
        Write-Host "=" * 80 -ForegroundColor DarkGray
        Write-ProgressLog "📈 Progress: $progressPercent% ($($i + 1) of $($repositories.Count))"
        
        try {
            $repoStartTime = Get-Date
            
            if (Process-Repository -Repository $repo -ConfigPath $tempConfigPath -RepositoryIndex $i -TotalRepositories $repositories.Count) {
                $successCount++
                $repoEndTime = Get-Date
                $repoDuration = $repoEndTime - $repoStartTime
                Write-VerboseLog "✅ Repository '$repo' completed successfully in $($repoDuration.TotalSeconds) seconds"
            }
            else {
                $failCount++
                $failedRepos += $repo
                $repoEndTime = Get-Date
                $repoDuration = $repoEndTime - $repoStartTime
                Write-VerboseLog "❌ Repository '$repo' failed after $($repoDuration.TotalSeconds) seconds"
            }
            
            # Progress delay between repositories (except for last one)
            if ($i -lt ($repositories.Count - 1) -and !$DryRun) {
                Write-VerboseLog "⏳ Waiting $DelayBetweenRepos seconds before processing next repository..."
                Start-Sleep -Seconds $DelayBetweenRepos
            }
        }
        catch {
            Write-Log "💥 Unexpected error processing repository '$repo': $($_.Exception.Message)" "ERROR"
            Write-VerboseLog "Exception details: $($_.Exception.ToString())"
            $failCount++
            $failedRepos += $repo
        }
    }
    
    $endTime = Get-Date
    $totalDuration = $endTime - $startTime
    
    # Cleanup temporary files
    Write-VerboseLog "🧹 Cleaning up temporary files..."
    if (Test-Path $TempDir) {
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-VerboseLog "Removed temporary directory: $TempDir"
    }
    
    # Generate detailed summary report
    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor DarkGray
    Show-Summary -Total $repositories.Count -Successful $successCount -Failed $failCount -FailedRepos $failedRepos -Duration $totalDuration
    
    # Exit with appropriate code based on results
    if ($failCount -gt 0) {
        Write-Log "⚠️ Batch completed with $failCount failures" "WARN"
        exit 1
    }
    else {
        Write-Log "🎉 All repositories configured successfully!" "SUCCESS"
        exit 0
    }
}

# Start the configuration process
Start-Configuration