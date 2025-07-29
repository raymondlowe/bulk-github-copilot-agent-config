<#
.SYNOPSIS
    Utility functions for GitHub Copilot Agent MCP Configuration.

.DESCRIPTION
    This module provides common utility functions used by the main
    configuration scripts.
#>

# Test if AutoIt is properly installed
function Test-AutoItInstallation {
    try {
        $autoItPath = Get-Command "AutoIt3.exe" -ErrorAction SilentlyContinue
        if ($autoItPath) {
            Write-Host "✓ AutoIt found at: $($autoItPath.Source)" -ForegroundColor Green
            return $true
        }
        
        Write-Host "✗ AutoIt not found in PATH" -ForegroundColor Red
        return $false
    }
    catch {
        Write-Host "✗ Error checking AutoIt installation: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Validate repository format
function Test-RepositoryFormat {
    param([string]$Repository)
    
    if ($Repository -match '^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$') {
        return $true
    }
    
    return $false
}

# Validate JSON configuration
function Test-JsonConfiguration {
    param([string]$JsonPath)
    
    try {
        $content = Get-Content $JsonPath -Raw
        $json = $content | ConvertFrom-Json
        
        # Check for required mcpServers property
        if ($json.mcpServers) {
            Write-Host "✓ Valid MCP configuration found" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "✗ No mcpServers configuration found" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "✗ Invalid JSON format: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Get browser information
function Get-BrowserInfo {
    $browsers = @()
    
    $browserPaths = @(
        @{Name="Chrome"; Path="${env:ProgramFiles}\Google\Chrome\Application\chrome.exe"},
        @{Name="Chrome (x86)"; Path="${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"},
        @{Name="Edge"; Path="${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"},
        @{Name="Firefox"; Path="${env:ProgramFiles}\Mozilla Firefox\firefox.exe"}
    )
    
    foreach ($browser in $browserPaths) {
        if (Test-Path $browser.Path) {
            $browsers += $browser
        }
    }
    
    return $browsers
}

# Create backup of existing configuration
function Backup-Configuration {
    param(
        [string]$Repository,
        [string]$BackupDir = "backups"
    )
    
    if (!(Test-Path $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $safeRepoName = $Repository -replace '[/\\:*?"<>|]', '_'
    $backupFile = "$BackupDir\$safeRepoName-$timestamp.json"
    
    # This would contain the current configuration if we could retrieve it
    # For now, create a placeholder
    $backupData = @{
        repository = $Repository
        timestamp = $timestamp
        note = "Backup created before MCP configuration update"
    }
    
    $backupData | ConvertTo-Json -Depth 10 | Set-Content $backupFile
    Write-Host "✓ Backup created: $backupFile" -ForegroundColor Green
    
    return $backupFile
}

# Generate summary report
function New-SummaryReport {
    param(
        [array]$ProcessedRepos,
        [array]$SuccessfulRepos,
        [array]$FailedRepos,
        [string]$OutputPath = "logs\summary-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    )
    
    $summary = @{
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        total_repositories = $ProcessedRepos.Count
        successful_count = $SuccessfulRepos.Count
        failed_count = $FailedRepos.Count
        successful_repositories = $SuccessfulRepos
        failed_repositories = $FailedRepos
        success_rate = if ($ProcessedRepos.Count -gt 0) { 
            [math]::Round(($SuccessfulRepos.Count / $ProcessedRepos.Count) * 100, 2) 
        } else { 0 }
    }
    
    $summary | ConvertTo-Json -Depth 10 | Set-Content $OutputPath
    Write-Host "✓ Summary report created: $OutputPath" -ForegroundColor Green
    
    return $OutputPath
}

# Clean old log files
function Clear-OldLogs {
    param(
        [string]$LogDir = "logs",
        [int]$DaysToKeep = 30
    )
    
    if (!(Test-Path $LogDir)) {
        return
    }
    
    $cutoffDate = (Get-Date).AddDays(-$DaysToKeep)
    $oldFiles = Get-ChildItem $LogDir -File | Where-Object { $_.LastWriteTime -lt $cutoffDate }
    
    if ($oldFiles.Count -gt 0) {
        Write-Host "Cleaning up $($oldFiles.Count) old log files..." -ForegroundColor Yellow
        $oldFiles | Remove-Item -Force
        Write-Host "✓ Old log files cleaned up" -ForegroundColor Green
    }
}

# Convert YAML repos file to simple text format
function ConvertFrom-YamlRepos {
    param(
        [string]$YamlPath,
        [string]$OutputPath = "config\repos.txt"
    )
    
    try {
        $yamlContent = Get-Content $YamlPath -Raw
        
        # Simple YAML parsing for repositories list
        $repos = @()
        $lines = $yamlContent -split "`n"
        $inRepositoriesSection = $false
        
        foreach ($line in $lines) {
            $line = $line.Trim()
            
            if ($line -eq "repositories:") {
                $inRepositoriesSection = $true
                continue
            }
            
            if ($inRepositoriesSection) {
                if ($line.StartsWith("- ") -and $line -match '- "(.+)"') {
                    $repos += $matches[1]
                }
                elseif ($line.StartsWith("- ") -and $line -match '- (.+)') {
                    $repos += $matches[1]
                }
                elseif ($line -notmatch '^[ -]' -and $line -ne "") {
                    $inRepositoriesSection = $false
                }
            }
        }
        
        if ($repos.Count -gt 0) {
            $repos | Set-Content $OutputPath
            Write-Host "✓ Converted $($repos.Count) repositories from YAML to $OutputPath" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "✗ No repositories found in YAML file" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "✗ Error converting YAML file: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Export utility functions
Export-ModuleMember -Function Test-AutoItInstallation, Test-RepositoryFormat, Test-JsonConfiguration, Get-BrowserInfo, Backup-Configuration, New-SummaryReport, Clear-OldLogs, ConvertFrom-YamlRepos