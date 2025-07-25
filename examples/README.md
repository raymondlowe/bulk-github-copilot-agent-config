# Example Configuration Files

This directory contains example configuration files for the Bulk GitHub Copilot Agent Configurator. The tool uses separate configuration files for different purposes.

## Configuration File Types

### Repository Selection Files
These files specify which repositories to configure:

- **[`basic-repos.yaml`](./basic-repos.yaml)** - Simple list of specific repositories
- **[`all-repos.yaml`](./all-repos.yaml)** - Apply to all accessible repositories with filters
- **[`pattern-based-repos.yaml`](./pattern-based-repos.yaml)** - Use patterns to select repositories

### MCP Configuration Files
These files contain the actual MCP server configurations to be applied. Both JSON and YAML formats are supported:

**JSON Format (Native MCP Format)**:
- **[`basic-mcp-config.json`](./basic-mcp-config.json)** - Simple GitHub + filesystem setup in JSON
- **[`advanced-mcp-config.json`](./advanced-mcp-config.json)** - Multiple MCP servers matching real-world usage

**YAML Format (Alternative)**:
- **[`basic-mcp-config.yaml`](./basic-mcp-config.yaml)** - Simple GitHub + Playwright setup
- **[`advanced-mcp-config.yaml`](./advanced-mcp-config.yaml)** - Multiple MCP servers with advanced features

> **💡 Tip**: JSON format is recommended as it matches the native format used by GitHub Copilot, Claude Desktop, VSCode, and other MCP tools. You can use your existing MCP configuration files directly!

### Optional Configuration Files
Additional configuration for repository secrets and variables:

- **[`secrets.yaml`](./secrets.yaml)** - Repository secrets and variables needed by MCP servers
- **[`basic-config.yaml`](./basic-config.yaml)** - Legacy single-file format (maintained for compatibility)

## Usage Examples

### Basic Usage
```bash
# Apply MCP configuration to specific repositories (JSON format recommended)
npm run configure -- --repos basic-repos.yaml --mcp-config basic-mcp-config.json --apply

# Include secrets configuration  
npm run configure -- --repos basic-repos.yaml --mcp-config basic-mcp-config.json --secrets secrets.yaml --apply

# YAML format also supported for compatibility
npm run configure -- --repos basic-repos.yaml --mcp-config basic-mcp-config.yaml --apply
```

### Advanced Usage
```bash
# Apply to all accessible repositories with filtering (JSON format)
npm run configure -- --repos all-repos.yaml --mcp-config advanced-mcp-config.json --apply

# Use pattern-based repository selection (JSON format)
npm run configure -- --repos pattern-based-repos.yaml --mcp-config basic-mcp-config.json --apply
```

### MCP Configuration Handling Options
```bash
# Don't overwrite existing MCP configurations
npm run configure -- --repos all-repos.yaml --mcp-config basic-mcp-config.json --skip-existing

# Merge new MCP servers with existing ones  
npm run configure -- --repos all-repos.yaml --mcp-config basic-mcp-config.json --merge

# Merge and overwrite servers with same names
npm run configure -- --repos all-repos.yaml --mcp-config basic-mcp-config.json --merge --overwrite-existing
```

## Configuration Validation

You can validate any configuration file using:

```bash
npm run validate-config -- path/to/your/config.json
# or  
npm run validate-config -- path/to/your/config.yaml
```

## Environment Variables

All configurations support environment variable substitution using the `{{ env.VARIABLE_NAME }}` syntax. Common environment variables include:

- `GITHUB_TOKEN`: GitHub personal access token
- `CUSTOM_API_TOKEN`: API key for custom MCP servers
- `DATABASE_URL`: Database connection string
- `LOG_LEVEL`: Logging verbosity level

## Configuration Tips

1. **Use JSON for MCP Configs**: JSON format is recommended for MCP configurations as it matches the native format used by GitHub Copilot, Claude Desktop, VSCode, and other MCP tools
2. **Start Simple**: Begin with `basic-repos.yaml` and `basic-mcp-config.json`
3. **Test First**: Always use `--dry-run` to preview changes before applying
4. **Use Filters**: When applying to all repositories, use filters to avoid unintended changes
5. **Separate Concerns**: Keep repository selection, MCP configuration, and secrets in separate files
6. **Version Control**: Store your configuration files in version control for change tracking
7. **Reuse Existing Configs**: You can directly use your existing MCP configuration files from Claude Desktop, VSCode, etc.