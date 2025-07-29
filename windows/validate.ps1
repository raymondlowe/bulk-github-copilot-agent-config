<#
.SYNOPSIS
    Validation script for GitHub Copilot Agent MCP Configuration.

.DESCRIPTION
    This script validates the environment and configuration files before
    running the main configuration process.

.PARAMETER RepoList
    Path to repository list file.

.PARAMETER McpConfig
    Path to MCP configuration file.

.PARAMETER Detailed
    Show detailed validation information.

.EXAMPLE
    .\validate.ps1 -RepoList "config\repos.txt" -McpConfig "config\mcp-config.txt"
    .\validate.ps1 -RepoList "repos.txt" -McpConfig "mcp.json" -Detailed

.NOTES
    This script helps ensure everything is ready before running the main configuration.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$RepoList,
    
    [Parameter(Mandatory=$true)]
    [string]$McpConfig,
    
    [switch]$Detailed
)

# Import utility functions
Import-Module "$PSScriptRoot\utils\ConfigUtils.psm1" -Force

# Validation results
$validationResults = @{
    Environment = @()
    Files = @()
    Configuration = @()
    Overall = $true
}

function Write-ValidationResult {
    param(
        [string]$Category,
        [string]$Test,
        [bool]$Passed,
        [string]$Message = "",
        [string]$Details = ""
    )
    
    $result = @{
        Test = $Test
        Passed = $Passed
        Message = $Message
        Details = $Details
    }
    
    $validationResults[$Category] += $result
    
    if (!$Passed) {
        $validationResults.Overall = $false
    }
    
    $status = if ($Passed) { "✓" } else { "✗" }
    $color = if ($Passed) { "Green" } else { "Red" }
    
    Write-Host "$status $Test" -ForegroundColor $color
    
    if ($Message -and ($Detailed -or !$Passed)) {
        Write-Host "  $Message" -ForegroundColor Gray
    }
    
    if ($Details -and $Detailed) {
        Write-Host "  Details: $Details" -ForegroundColor DarkGray
    }
}

function Test-Environment {
    Write-Host "`n📋 Environment Validation" -ForegroundColor Cyan
    Write-Host "========================" -ForegroundColor Cyan
    
    # Test PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    $psVersionPassed = $psVersion.Major -ge 5
    Write-ValidationResult "Environment" "PowerShell Version" $psVersionPassed `
        "Found PowerShell $($psVersion.ToString())" `
        "Minimum required: 5.0"
    
    # Test Windows version
    $osVersion = [System.Environment]::OSVersion.Version
    $osVersionPassed = ($osVersion.Major -eq 10) -or ($osVersion.Major -eq 6 -and $osVersion.Minor -ge 1)
    Write-ValidationResult "Environment" "Windows Version" $osVersionPassed `
        "Found Windows $($osVersion.ToString())" `
        "Minimum required: Windows 7/Server 2008 R2"
    
    # Test AutoIt installation
    $autoItPassed = Test-AutoItInstallation
    Write-ValidationResult "Environment" "AutoIt Installation" $autoItPassed `
        $(if ($autoItPassed) { "AutoIt is properly installed" } else { "AutoIt not found - run setup.ps1" })
    
    # Test browser availability
    $browsers = Get-BrowserInfo
    $browserPassed = $browsers.Count -gt 0
    $browserMessage = if ($browserPassed) { 
        "Found $($browsers.Count) supported browser(s): $($browsers.Name -join ', ')" 
    } else { 
        "No supported browsers found - install Chrome, Edge, or Firefox" 
    }
    Write-ValidationResult "Environment" "Browser Availability" $browserPassed $browserMessage
    
    # Test internet connectivity
    try {
        $connectTest = Test-NetConnection -ComputerName "github.com" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
        Write-ValidationResult "Environment" "Internet Connectivity" $connectTest `
            $(if ($connectTest) { "Can reach github.com" } else { "Cannot reach github.com" })
    }
    catch {
        Write-ValidationResult "Environment" "Internet Connectivity" $false `
            "Network connectivity test failed: $($_.Exception.Message)"
    }
    
    # Test required directories
    $dirsToCheck = @("logs", "config", "autoit", "utils")
    foreach ($dir in $dirsToCheck) {
        $dirExists = Test-Path $dir
        Write-ValidationResult "Environment" "Directory: $dir" $dirExists `
            $(if ($dirExists) { "Directory exists" } else { "Directory missing - will be created" })
    }
}

function Test-Files {
    Write-Host "`n📁 File Validation" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    
    # Test repository list file
    $repoListExists = Test-Path $RepoList
    Write-ValidationResult "Files" "Repository List File" $repoListExists `
        $(if ($repoListExists) { "File exists: $RepoList" } else { "File not found: $RepoList" })
    
    if ($repoListExists) {
        $repoContent = Get-Content $RepoList | Where-Object { $_ -match '\S' -and !$_.StartsWith('#') }
        $repoCount = $repoContent.Count
        $repoCountPassed = $repoCount -gt 0
        Write-ValidationResult "Files" "Repository List Content" $repoCountPassed `
            "Found $repoCount repositories in list"
        
        # Validate repository formats
        $invalidRepos = @()
        foreach ($repo in $repoContent) {
            if (!(Test-RepositoryFormat $repo.Trim())) {
                $invalidRepos += $repo.Trim()
            }
        }
        
        $repoFormatPassed = $invalidRepos.Count -eq 0
        Write-ValidationResult "Files" "Repository Format" $repoFormatPassed `
            $(if ($repoFormatPassed) { "All repositories have valid format" } else { "Invalid repositories: $($invalidRepos -join ', ')" })
    }
    
    # Test MCP configuration file
    $mcpConfigExists = Test-Path $McpConfig
    Write-ValidationResult "Files" "MCP Configuration File" $mcpConfigExists `
        $(if ($mcpConfigExists) { "File exists: $McpConfig" } else { "File not found: $McpConfig" })
    
    if ($mcpConfigExists) {
        $mcpConfigValid = Test-JsonConfiguration $McpConfig
        Write-ValidationResult "Files" "MCP Configuration Format" $mcpConfigValid `
            $(if ($mcpConfigValid) { "Valid JSON configuration" } else { "Invalid JSON or missing mcpServers" })
    }
    
    # Test AutoIt script files
    $autoItScripts = @("autoit\github-copilot-config.au3", "autoit\github-auth.au3")
    foreach ($script in $autoItScripts) {
        $scriptExists = Test-Path $script
        Write-ValidationResult "Files" "AutoIt Script: $(Split-Path $script -Leaf)" $scriptExists `
            $(if ($scriptExists) { "Script file exists" } else { "Script file missing" })
    }
}

function Test-Configuration {
    Write-Host "`n⚙️  Configuration Validation" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    
    if (Test-Path $McpConfig) {
        try {
            $mcpContent = Get-Content $McpConfig -Raw | ConvertFrom-Json
            
            # Test MCP servers configuration
            if ($mcpContent.mcpServers) {
                $serverCount = ($mcpContent.mcpServers | Get-Member -MemberType NoteProperty).Count
                Write-ValidationResult "Configuration" "MCP Servers Count" ($serverCount -gt 0) `
                    "Found $serverCount MCP server(s) configured"
                
                # Check each server configuration
                foreach ($serverName in $mcpContent.mcpServers.PSObject.Properties.Name) {
                    $server = $mcpContent.mcpServers.$serverName
                    
                    # Check server type
                    $hasType = $server.type -ne $null
                    Write-ValidationResult "Configuration" "Server '$serverName' Type" $hasType `
                        $(if ($hasType) { "Type: $($server.type)" } else { "Missing type property" })
                    
                    # Check server configuration based on type
                    switch ($server.type) {
                        "http" {
                            $hasUrl = $server.url -ne $null
                            Write-ValidationResult "Configuration" "Server '$serverName' URL" $hasUrl `
                                $(if ($hasUrl) { "URL: $($server.url)" } else { "Missing URL for HTTP server" })
                        }
                        "local" {
                            $hasCommand = $server.command -ne $null
                            Write-ValidationResult "Configuration" "Server '$serverName' Command" $hasCommand `
                                $(if ($hasCommand) { "Command: $($server.command)" } else { "Missing command for local server" })
                        }
                    }
                    
                    # Check tools array
                    $hasTools = $server.tools -ne $null -and $server.tools.Count -gt 0
                    Write-ValidationResult "Configuration" "Server '$serverName' Tools" $hasTools `
                        $(if ($hasTools) { "Tools: $($server.tools.Count) configured" } else { "No tools configured" })
                }
            }
        }
        catch {
            Write-ValidationResult "Configuration" "MCP Configuration Parsing" $false `
                "Error parsing configuration: $($_.Exception.Message)"
        }
    }
    
    # Test environment variable references
    if (Test-Path $McpConfig) {
        $configContent = Get-Content $McpConfig -Raw
        $envVars = [regex]::Matches($configContent, '\{\{\s*env\.(\w+)\s*\}\}') | ForEach-Object { $_.Groups[1].Value }
        
        foreach ($envVar in $envVars) {
            $envVarExists = [System.Environment]::GetEnvironmentVariable($envVar) -ne $null
            Write-ValidationResult "Configuration" "Environment Variable: $envVar" $envVarExists `
                $(if ($envVarExists) { "Variable is set" } else { "Variable not set - may cause issues" })
        }
    }
}

function Show-Summary {
    Write-Host "`n📊 Validation Summary" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    
    $categories = @("Environment", "Files", "Configuration")
    $totalTests = 0
    $passedTests = 0
    
    foreach ($category in $categories) {
        $categoryResults = $validationResults[$category]
        $categoryPassed = ($categoryResults | Where-Object { $_.Passed }).Count
        $categoryTotal = $categoryResults.Count
        
        $totalTests += $categoryTotal
        $passedTests += $categoryPassed
        
        $categoryStatus = if ($categoryPassed -eq $categoryTotal) { "✓" } else { "⚠" }
        $categoryColor = if ($categoryPassed -eq $categoryTotal) { "Green" } else { "Yellow" }
        
        Write-Host "$categoryStatus $category`: $categoryPassed/$categoryTotal passed" -ForegroundColor $categoryColor
    }
    
    Write-Host ""
    
    if ($validationResults.Overall) {
        Write-Host "🎉 All validations passed! Ready to run configuration." -ForegroundColor Green
    }
    else {
        Write-Host "⚠️  Some validations failed. Please address the issues above." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Common fixes:" -ForegroundColor Gray
        Write-Host "• Run setup.ps1 to install AutoIt" -ForegroundColor Gray
        Write-Host "• Check file paths and formats" -ForegroundColor Gray
        Write-Host "• Install a supported browser" -ForegroundColor Gray
        Write-Host "• Set required environment variables" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "Overall: $passedTests/$totalTests tests passed" -ForegroundColor $(if ($validationResults.Overall) { "Green" } else { "Red" })
}

# Main validation process
Write-Host "🔍 GitHub Copilot Agent MCP Configuration - Validation" -ForegroundColor White
Write-Host "=========================================================" -ForegroundColor White

Test-Environment
Test-Files  
Test-Configuration
Show-Summary

# Exit with appropriate code
if ($validationResults.Overall) {
    exit 0
} else {
    exit 1
}