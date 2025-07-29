# Windows AutoIt Quick Start Guide

This guide will help you get started with the Windows AutoIt solution for GitHub Copilot Agent MCP configuration.

## Prerequisites

- Windows 10/11
- PowerShell 5.1 or later
- Administrator privileges (for initial setup)
- GitHub account with repository access

## Step 1: Initial Setup

Run the setup script as Administrator:

```powershell
# Open PowerShell as Administrator
# Navigate to the windows directory
cd windows

# Run setup
.\setup.ps1
```

This will:
- Download and install AutoIt
- Create configuration templates
- Check browser compatibility
- Set up logging directories

## Step 2: Configure Your Repositories

Edit the repository list file:

```powershell
# Edit the repository list
notepad config\repos.txt
```

Add your repositories in the format `owner/repository`:

```
myusername/repo1
myusername/repo2
myorganization/repo3
```

## Step 3: Configure MCP Settings

Edit the MCP configuration file:

```powershell
# Edit MCP configuration
notepad config\mcp-config.txt
```

The file contains a JSON configuration for your MCP servers:

```json
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
        "list_repositories"
      ]
    }
  }
}
```

## Step 4: Validate Configuration

Before running the main configuration, validate your setup:

```powershell
# Validate configuration
.\validate.ps1 -RepoList "config\repos.txt" -McpConfig "config\mcp-config.txt"
```

This will check:
- AutoIt installation
- Browser availability
- File formats
- Configuration validity

## Step 5: Run Configuration

### Dry Run (Recommended First)

Test the configuration without making changes:

```powershell
.\configure-copilot.ps1 -RepoList "config\repos.txt" -McpConfig "config\mcp-config.txt" -DryRun
```

### Interactive Mode

For repositories requiring manual authentication:

```powershell
.\configure-copilot.ps1 -RepoList "config\repos.txt" -McpConfig "config\mcp-config.txt" -Interactive
```

### Full Configuration

Apply the configuration to all repositories:

```powershell
.\configure-copilot.ps1 -RepoList "config\repos.txt" -McpConfig "config\mcp-config.txt"
```

## Common Options

### Verbose Logging
```powershell
.\configure-copilot.ps1 -RepoList "repos.txt" -McpConfig "mcp.txt" -Verbose
```

### Custom Delays
```powershell
.\configure-copilot.ps1 -RepoList "repos.txt" -McpConfig "mcp.txt" -DelayBetweenRepos 10
```

### Maximum Retries
```powershell
.\configure-copilot.ps1 -RepoList "repos.txt" -McpConfig "mcp.txt" -MaxRetries 5
```

## Troubleshooting

### AutoIt Not Found
```powershell
# Re-run setup as Administrator
.\setup.ps1 -ForceReinstall
```

### Browser Issues
```powershell
# Skip browser check during setup
.\setup.ps1 -SkipBrowserCheck
```

### Authentication Problems
```powershell
# Use interactive mode
.\configure-copilot.ps1 -RepoList "repos.txt" -McpConfig "mcp.txt" -Interactive
```

### Validation Failures
```powershell
# Run detailed validation
.\validate.ps1 -RepoList "repos.txt" -McpConfig "mcp.txt" -Detailed
```

## Log Files

All operations create log files in the `logs\` directory:

- `setup.log` - Setup process logs
- `configure-YYYYMMDD-HHMMSS.log` - Configuration session logs
- `autoit-YYYYMMDD-HHMMSS.log` - AutoIt script execution logs
- `summary-YYYYMMDD-HHMMSS.json` - Summary reports

## Integration with Main Project

You can use existing configuration files from the main project:

### Using YAML Repository Files

Convert YAML format to text format:

```powershell
# Import utility module
Import-Module utils\ConfigUtils.psm1

# Convert YAML to text
ConvertFrom-YamlRepos -YamlPath "..\repos.yaml" -OutputPath "config\repos.txt"
```

### Using JSON MCP Configuration

Copy the main project's MCP configuration:

```powershell
# Copy from main project
Copy-Item "..\mcp-config.json" "config\mcp-config.txt"
```

## Environment Variables

Set required environment variables before running:

```powershell
# Set GitHub token
$env:GITHUB_TOKEN = "your-github-token"

# Set custom API keys
$env:CUSTOM_API_KEY = "your-api-key"
```

## Security Notes

- Never commit tokens or secrets to version control
- Use environment variables for sensitive configuration
- Review logs for any accidentally logged sensitive data
- The scripts create temporary files that are cleaned up automatically

## Getting Help

For detailed help on any script:

```powershell
Get-Help .\setup.ps1 -Full
Get-Help .\configure-copilot.ps1 -Full
Get-Help .\validate.ps1 -Full
```

## Next Steps

After successful configuration:

1. Verify MCP settings in GitHub repository settings
2. Test MCP functionality in GitHub Copilot
3. Set up regular configuration updates if needed
4. Consider automating with scheduled tasks

## Support

If you encounter issues:

1. Check the logs in the `logs\` directory
2. Run validation with `-Detailed` flag
3. Try interactive mode for authentication issues
4. Ensure your GitHub account has proper repository access