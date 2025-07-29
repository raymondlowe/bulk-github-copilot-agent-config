<#
.SYNOPSIS
    Integration script to use main project configuration with Windows AutoIt solution.

.DESCRIPTION
    This script demonstrates how to use the existing TypeScript project's configuration
    files with the Windows AutoIt solution, providing a bridge between the two approaches.

.EXAMPLE
    .\integration-example.ps1
    .\integration-example.ps1 -UseMainProjectConfig

.NOTES
    This script shows how the Windows solution can complement the main TypeScript project.
#>

param(
    [switch]$UseMainProjectConfig,
    [switch]$DryRun
)

Write-Host "🔗 Integration Example: Main Project + Windows AutoIt" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# Import utility functions
Import-Module "$PSScriptRoot\utils\ConfigUtils.psm1" -Force

# Check if we're in the windows directory
if (!(Test-Path "autoit\github-copilot-config.au3")) {
    Write-Host "❌ Please run this script from the windows\ directory" -ForegroundColor Red
    exit 1
}

# Main project paths
$mainProjectRoot = ".."
$mainReposYaml = "$mainProjectRoot\repos.yaml"
$mainMcpJson = "$mainProjectRoot\mcp-config.json"

Write-Host "`n📋 Configuration Integration Options" -ForegroundColor Yellow

if ($UseMainProjectConfig) {
    Write-Host "Using main project configuration files..." -ForegroundColor Green
    
    # Convert main project repos.yaml to Windows format
    if (Test-Path $mainReposYaml) {
        Write-Host "✓ Found main project repos.yaml" -ForegroundColor Green
        
        if (ConvertFrom-YamlRepos -YamlPath $mainReposYaml -OutputPath "config\repos.txt") {
            Write-Host "✓ Converted repos.yaml to Windows format" -ForegroundColor Green
        } else {
            Write-Host "❌ Failed to convert repos.yaml" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "❌ Main project repos.yaml not found at: $mainReposYaml" -ForegroundColor Red
        exit 1
    }
    
    # Copy main project MCP configuration
    if (Test-Path $mainMcpJson) {
        Write-Host "✓ Found main project mcp-config.json" -ForegroundColor Green
        Copy-Item $mainMcpJson "config\mcp-config.txt"
        Write-Host "✓ Copied MCP configuration to Windows format" -ForegroundColor Green
    } else {
        Write-Host "❌ Main project mcp-config.json not found at: $mainMcpJson" -ForegroundColor Red
        exit 1
    }
    
    $repoList = "config\repos.txt"
    $mcpConfig = "config\mcp-config.txt"
} else {
    Write-Host "Using Windows-specific configuration files..." -ForegroundColor Green
    $repoList = "config\repos.txt"
    $mcpConfig = "config\mcp-config.txt"
}

Write-Host "`n🔍 Validating Configuration" -ForegroundColor Yellow

# Run validation
$validationResult = & "$PSScriptRoot\validate.ps1" -RepoList $repoList -McpConfig $mcpConfig
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Validation failed. Please address the issues above." -ForegroundColor Red
    exit 1
}

Write-Host "`n🚀 Running Configuration" -ForegroundColor Yellow

# Build arguments for configuration script
$configArgs = @(
    "-RepoList", $repoList,
    "-McpConfig", $mcpConfig
)

if ($DryRun) {
    $configArgs += "-DryRun"
}

$configArgs += "-Interactive"  # Use interactive mode for this example
$configArgs += "-Verbose"      # Enable verbose logging

# Run the configuration
Write-Host "Executing: .\configure-copilot.ps1 $($configArgs -join ' ')" -ForegroundColor Gray
& "$PSScriptRoot\configure-copilot.ps1" @configArgs

$configResult = $LASTEXITCODE

Write-Host "`n📊 Integration Results" -ForegroundColor Cyan

if ($configResult -eq 0) {
    Write-Host "✅ Configuration completed successfully!" -ForegroundColor Green
    
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "1. Verify MCP settings in your GitHub repositories" -ForegroundColor Gray
    Write-Host "2. Test GitHub Copilot functionality with new MCP servers" -ForegroundColor Gray
    Write-Host "3. Check logs in logs\ directory for detailed information" -ForegroundColor Gray
    
    if ($UseMainProjectConfig) {
        Write-Host "4. Consider updating main project configuration based on results" -ForegroundColor Gray
    }
} else {
    Write-Host "❌ Configuration failed. Check logs for details." -ForegroundColor Red
    
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Check logs\ directory for detailed error information" -ForegroundColor Gray
    Write-Host "2. Run validation again: .\validate.ps1 -RepoList '$repoList' -McpConfig '$mcpConfig' -Detailed" -ForegroundColor Gray
    Write-Host "3. Try interactive mode if authentication failed" -ForegroundColor Gray
    Write-Host "4. Verify repository access permissions" -ForegroundColor Gray
}

Write-Host "`n🔄 Comparison with Main Project" -ForegroundColor Cyan

if (Test-Path "$mainProjectRoot\dist\cli.js") {
    Write-Host "The main TypeScript project is also available. You can compare approaches:" -ForegroundColor Gray
    Write-Host "# Main project (TypeScript/Playwright):" -ForegroundColor DarkGray
    Write-Host "cd .." -ForegroundColor DarkGray
    Write-Host "npm run configure -- configure --repos repos.yaml --mcp-config mcp-config.json --dry-run" -ForegroundColor DarkGray
    Write-Host "" -ForegroundColor DarkGray
    Write-Host "# Windows project (AutoIt):" -ForegroundColor DarkGray
    Write-Host "cd windows" -ForegroundColor DarkGray
    Write-Host ".\configure-copilot.ps1 -RepoList 'config\repos.txt' -McpConfig 'config\mcp-config.txt' -DryRun" -ForegroundColor DarkGray
} else {
    Write-Host "To use the main TypeScript project:" -ForegroundColor Gray
    Write-Host "cd .." -ForegroundColor DarkGray
    Write-Host "npm install && npm run build" -ForegroundColor DarkGray
    Write-Host "npm run configure -- configure --repos repos.yaml --mcp-config mcp-config.json" -ForegroundColor DarkGray
}

Write-Host "`n✨ Integration Complete" -ForegroundColor Green

exit $configResult