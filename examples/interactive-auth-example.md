# Interactive Authentication Example

This example demonstrates how to use the interactive authentication feature when the GitHub API approach fails.

## When to Use Interactive Authentication

The `--interactive-auth` option should be used when:
1. The GitHub API endpoints for MCP configuration are not working
2. You want to ensure browser-based configuration works by manually logging in
3. You're troubleshooting authentication issues

## Command Examples

### Basic Interactive Authentication
```bash
npm run configure -- configure \
  --repos examples/basic-repos.yaml \
  --mcp-config examples/basic-mcp-config.json \
  --interactive-auth
```

### Interactive Auth with Dry Run (for testing)
```bash
npm run configure -- configure \
  --repos examples/basic-repos.yaml \
  --mcp-config examples/basic-mcp-config.json \
  --interactive-auth \
  --dry-run
```

### Interactive Auth with Verbose Logging
```bash
npm run configure -- configure \
  --repos examples/basic-repos.yaml \
  --mcp-config examples/basic-mcp-config.json \
  --interactive-auth \
  --verbose
```

## How It Works

1. **API First**: The tool first attempts to use GitHub API endpoints for MCP configuration
2. **API Failure Detection**: If the API approach fails (which is currently expected)
3. **Browser Fallback**: The tool automatically falls back to browser automation
4. **Interactive Login**: With `--interactive-auth`, the browser opens visibly for manual login
5. **User Authentication**: You manually log in to GitHub in the browser window
6. **Automated Processing**: After authentication, the browser switches to background mode for automated configuration

## Interactive Flow

When you run with `--interactive-auth`, you'll see:

```
🔑 Interactive GitHub Authentication Required
The browser will open for you to manually log in to GitHub.
Please complete the login process and then return to this terminal.

📋 Please log in to GitHub in the browser window that just opened.
Press Enter in this terminal after you have successfully logged in...
```

After you log in and press Enter, the tool will:
- Verify your authentication
- Switch to background mode (headless) for automation
- Continue with the MCP configuration process

## Notes

- This is a **one-time manual interaction** per session
- The browser will automatically switch to background mode after authentication
- Cannot be used with `--api-only` mode (they are mutually exclusive)
- Best used when API endpoints are not available or working