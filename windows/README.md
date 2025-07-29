# Windows AutoIt Solution for GitHub Copilot Agent MCP Configuration

This directory contains a Windows-specific solution using AutoIt for automating GitHub Copilot agent MCP configuration across multiple repositories.

## Overview

This Windows AutoIt solution provides an alternative to the main TypeScript/Playwright approach, specifically designed for Windows users who prefer AutoIt automation.

## Features

- **AutoIt-based browser automation** for GitHub Copilot settings
- **PowerShell orchestration** for managing multiple repositories
- **Automatic AutoIt installation** and setup
- **Configuration file support** compatible with main project
- **Environment variable management** for Copilot keys
- **Robust error handling** and logging

## Files

- `setup.ps1` - PowerShell script to install and configure AutoIt
- `configure-copilot.ps1` - Main orchestration script
- `autoit/` - Directory containing AutoIt scripts
  - `github-copilot-config.au3` - AutoIt script for MCP configuration
  - `github-auth.au3` - AutoIt script for GitHub authentication
- `config/` - Configuration templates and examples
- `utils/` - Utility scripts and helpers

## Quick Start

1. **Run setup** (as Administrator):
   ```powershell
   .\setup.ps1
   ```

2. **Configure your repositories** (edit `repos.txt`):
   ```
   owner/repo1
   owner/repo2
   owner/repo3
   ```

3. **Prepare MCP configuration** (edit `mcp-config.txt`):
   ```json
   {
     "mcpServers": {
       "github-mcp": {
         "type": "http",
         "url": "https://api.github.com/mcp"
       }
     }
   }
   ```

4. **Run the configuration**:
   ```powershell
   .\configure-copilot.ps1 -RepoList "repos.txt" -McpConfig "mcp-config.txt"
   ```

## Requirements

- Windows 10/11
- PowerShell 5.1 or later
- Internet connection
- GitHub account with repository access
- Administrative privileges for initial setup

## How It Works

1. **Setup Phase**: Downloads and installs AutoIt, configures environment
2. **Repository Processing**: Reads repository list and processes each one
3. **Browser Automation**: Uses AutoIt to navigate GitHub Copilot settings
4. **Configuration Update**: Finds MCP configuration field and updates content
5. **Save and Verify**: Saves changes and verifies successful update

## Configuration Options

The scripts support various configuration options:

- `-DryRun` - Preview changes without applying them
- `-Verbose` - Enable detailed logging
- `-Interactive` - Enable interactive mode for manual authentication
- `-DelayBetweenRepos` - Specify delay between repository processing
- `-MaxRetries` - Set maximum retry attempts for failed operations

## Error Handling

The solution includes comprehensive error handling:
- Automatic retry for transient failures
- Detailed logging to `logs/` directory
- Graceful handling of authentication issues
- Repository-level error isolation

## Integration with Main Project

This Windows solution can work alongside the main TypeScript project:
- Uses same configuration file formats where possible
- Compatible with existing `repos.yaml` and `mcp-config.json`
- Can be used as fallback when Playwright isn't available
- Provides Windows-specific optimizations

## Troubleshooting

Common issues and solutions:

1. **AutoIt installation fails**: Run setup.ps1 as Administrator
2. **Browser automation fails**: Check if GitHub interface has changed
3. **Authentication issues**: Use `-Interactive` flag for manual login
4. **Permission errors**: Ensure repository access rights

## Development

To modify or extend the AutoIt scripts:

1. Install AutoIt SciTE editor
2. Edit `.au3` files in `autoit/` directory
3. Test changes with single repository first
4. Update documentation for any new features

## License

Same as parent project (MIT License)