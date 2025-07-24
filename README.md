# Bulk GitHub Copilot Agent Configurator

A simple automation tool that combines GitHub CLI (`gh`) with browser automation to manage GitHub Copilot agent MCP configurations across your personal repositories.

## 🎯 Purpose

Managing GitHub Copilot agent MCP (Model Context Protocol) server settings across multiple personal repositories manually is time-consuming and error-prone. This tool automates the bulk configuration of:

- **MCP (Model Context Protocol) servers** - Configure external tools and context sources for GitHub Copilot
- **Repository secrets and variables** - Manage API keys and configuration needed by MCP servers

## ✨ Key Features

- **Hybrid Automation**: Leverages GitHub CLI for secrets/variables and browser automation for MCP configuration
- **Personal Repository Focus**: Designed for individual GitHub accounts and personal repositories
- **Flexible Repository Selection**: Apply to specific repos or all repositories you have access to
- **Smart MCP Config Handling**: Options to merge, skip existing, or overwrite MCP configurations
- **Configuration as Code**: Define settings in simple YAML configuration files
- **Safe Operations**: Dry-run mode and comprehensive logging of all changes

## 🚀 Quick Start

### Prerequisites

- **GitHub CLI** (`gh`) installed and authenticated with your personal account
- **Node.js** 18+ for browser automation components
- **Repository admin access** for target repositories (your own repos or repos you collaborate on)

### Installation

```bash
# Clone the repository
git clone https://github.com/your-org/bulk-github-copilot-agent-config
cd bulk-github-copilot-agent-config

# Install dependencies
npm install

# Configure authentication
gh auth login
```

### Basic Usage

1. **Create a repository list file** (`repos.yaml`):

```yaml
# Option 1: Specify individual repositories
repositories:
  - "myusername/repo1"
  - "myusername/repo2"
  - "myusername/my-project"

# Option 2: Apply to all repositories you have access to
all_accessible_repos: true

# Optional: Filter when using all_accessible_repos
filters:
  # Only include repos you own (not just collaborate on)
  owner_only: true
  
  # Only include repos with specific topics
  topics:
    - "copilot-enabled"
    - "automation"
  
  # Exclude specific repos
  exclude:
    - "myusername/archived-project"
    - "myusername/template-repo"
```

2. **Create an MCP configuration file** (`mcp-config.yaml`):

```yaml
# This is the content that will be inserted into the MCP configuration field
# in GitHub Copilot Agent settings

github:
  enabled: true
  config:
    token_source: "env:GITHUB_TOKEN"
    
playwright:
  enabled: true
  config:
    headless: true

# You can add any MCP servers you want to configure
custom_server:
  enabled: true
  config:
    endpoint: "https://api.example.com"
    auth_token: "env:CUSTOM_API_TOKEN"
```

3. **Optional: Configure repository secrets/variables** (`secrets.yaml`):

```yaml
# Repository-level secrets needed by your MCP servers
secrets:
  CUSTOM_API_TOKEN: "{{ env.CUSTOM_API_TOKEN }}"
  DATABASE_URL: "{{ env.DATABASE_URL }}"
    
# Repository-level variables
variables:
  MCP_ENVIRONMENT: "production"
  LOG_LEVEL: "info"
```

4. **Run the configurator**:

```bash
# Dry run to preview changes
npm run configure -- --repos repos.yaml --mcp-config mcp-config.yaml --dry-run

# Apply MCP configuration only
npm run configure -- --repos repos.yaml --mcp-config mcp-config.yaml --apply

# Apply MCP config and secrets/variables
npm run configure -- --repos repos.yaml --mcp-config mcp-config.yaml --secrets secrets.yaml --apply
```

## 📋 Configuration Options

### MCP Configuration Handling

Control how existing MCP configurations are handled:

```bash
# Don't overwrite existing MCP configs (skip repos that already have MCP config)
npm run configure -- --repos repos.yaml --mcp-config mcp-config.yaml --skip-existing

# Merge new MCP servers with existing ones (keep existing, add new)
npm run configure -- --repos repos.yaml --mcp-config mcp-config.yaml --merge

# Merge with overwrite option (replace existing servers if they have the same name)
npm run configure -- --repos repos.yaml --mcp-config mcp-config.yaml --merge --overwrite-existing

# Force overwrite all MCP configuration (replace entirely)
npm run configure -- --repos repos.yaml --mcp-config mcp-config.yaml --force-overwrite
```

### Repository Selection Options

Different ways to specify which repositories to configure:

```yaml
# repos.yaml examples:

# Option 1: Explicit list
repositories:
  - "myusername/project1"
  - "myusername/project2"

# Option 2: All accessible repos
all_accessible_repos: true

# Option 3: All accessible repos with filters
all_accessible_repos: true
filters:
  owner_only: true  # Only repos you own
  topics: ["copilot", "automation"]  # Only repos with these topics
  exclude: ["myusername/old-project"]  # Exclude specific repos
  
# Option 4: Pattern matching
repositories:
  patterns:
    - "myusername/*-service"  # All repos ending with -service
    - "myusername/app-*"      # All repos starting with app-
```

### MCP Server Configuration

Define the MCP servers to be configured in your repositories:

```yaml
# mcp-config.yaml - This content goes into the GitHub Copilot Agent MCP config field

github:
  enabled: true
  config:
    token_source: "env:GITHUB_TOKEN"
    repositories: ["*"]  # Access all repos, or specify specific ones
  
playwright:
  enabled: true
  config:
    headless: true
    timeout: 30000
  
custom_api_server:
  enabled: true
  config:
    endpoint: "https://api.example.com"
    auth_header: "Bearer {{ secrets.CUSTOM_API_KEY }}"
    
filesystem:
  enabled: true
  config:
    root_path: "/workspace"
    readonly: false
```

### Repository Secrets and Variables

Configure repository-level secrets and variables needed by your MCP servers:

```yaml
# secrets.yaml

secrets:
  # Environment variable references
  CUSTOM_API_KEY: "{{ env.CUSTOM_API_KEY }}"
  DATABASE_URL: "{{ env.DATABASE_URL }}"
  
  # Direct values (not recommended for sensitive data)
  PUBLIC_CONFIG: "some-public-value"
    
variables:
  MCP_ENVIRONMENT: "production"
  LOG_LEVEL: "info"
  ENABLE_DEBUG: "false"
```

## 🔒 Security Considerations

### Credential Management

- **Never store secrets in plain text** - Use environment variables for sensitive data
- **Repository-level secrets** - Configure secrets at the repository level for MCP server access
- **Secure authentication** - Uses GitHub CLI authentication (personal access tokens)
- **Audit logging** - All actions are logged with timestamps and repository details

### Browser Automation Security

- **Headless operation** - Runs without UI for security and performance
- **Session isolation** - Each repository configuration uses isolated browser contexts
- **Credential injection** - Authentication tokens are injected securely without disk storage
- **No persistent storage** - Browser sessions are cleaned up after each operation

## 🔧 Advanced Usage

### Repository Filtering

Apply configuration to specific repository subsets:

```bash
# Apply to all your own repositories
npm run configure -- --repos repos.yaml --mcp-config mcp-config.yaml --owner-only

# Apply to repositories with specific topics
npm run configure -- --repos repos.yaml --mcp-config mcp-config.yaml --topics "copilot,automation"

# Apply to repositories matching name patterns
npm run configure -- --repos repos.yaml --mcp-config mcp-config.yaml --pattern "*-service"

# Exclude specific repositories
npm run configure -- --repos repos.yaml --mcp-config mcp-config.yaml --exclude "myusername/old-project,myusername/archive"
```

### MCP Configuration Strategies

Different approaches for handling existing MCP configurations:

```bash
# Conservative: Skip repositories that already have MCP config
npm run configure -- --repos repos.yaml --mcp-config mcp-config.yaml --skip-existing

# Additive: Add new MCP servers, keep existing ones
npm run configure -- --repos repos.yaml --mcp-config mcp-config.yaml --merge

# Smart merge: Add new servers, update existing ones with same name
npm run configure -- --repos repos.yaml --mcp-config mcp-config.yaml --merge --overwrite-existing

# Complete replacement: Replace entire MCP configuration
npm run configure -- --repos repos.yaml --mcp-config mcp-config.yaml --force-overwrite
```

### Parallel Processing

Control concurrency for large repository sets:

```bash
# Process 3 repositories simultaneously (default)
npm run configure -- --repos repos.yaml --mcp-config mcp-config.yaml --concurrency 3

# Single repository at a time (safest)
npm run configure -- --repos repos.yaml --mcp-config mcp-config.yaml --concurrency 1

# Higher concurrency for faster processing (if you have many repos)
npm run configure -- --repos repos.yaml --mcp-config mcp-config.yaml --concurrency 5
```

### Error Recovery

Handle failures gracefully:

```bash
# Resume from last failed repository
npm run configure -- --repos repos.yaml --mcp-config mcp-config.yaml --resume

# Retry only failed repositories from previous run
npm run configure -- --retry-failed

# Generate detailed error report
npm run configure -- --error-report
```

## 📊 Monitoring and Reporting

### Operation Logs

All operations are logged to `operations.log` with:
- Timestamp and repository information
- MCP configuration changes made
- Success/failure status with error details
- Before/after state comparisons for auditing

### Progress Tracking

Monitor bulk operations in real-time:
- Progress bars for multi-repository operations
- Real-time status updates for each repository
- ETA calculations based on processing speed
- Immediate notifications of failures with suggested fixes

### Summary Reports

After each operation, generate summary reports showing:
- Total repositories processed
- MCP configurations added/updated/skipped
- Any secrets or variables configured
- Detailed error information for failed repositories

## ⚠️ Limitations and Known Issues

### Current Limitations

- **MCP Configuration**: Requires browser automation as GitHub doesn't provide API access for MCP settings
- **Personal Accounts Only**: Designed for individual GitHub accounts, not organization/enterprise features
- **Rate Limiting**: GitHub API rate limits may slow operations with many repositories
- **Browser Dependencies**: Requires Chrome/Chromium for web automation features

### Known Issues

- **Session Timeouts**: Very long operations may require re-authentication
- **Large Repository Sets**: Memory usage increases with repository count (process in batches if needed)
- **Network Connectivity**: Requires stable internet for browser automation components
- **MCP Field Changes**: If GitHub changes the MCP configuration interface, browser automation may need updates

### Workarounds

- Use multiple authentication tokens if you hit rate limits frequently
- Process repositories in smaller batches for very large repository sets
- Use `--resume` flag to continue after interruptions
- Keep browser automation updated if GitHub changes their interface

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup

```bash
# Clone and setup development environment
git clone https://github.com/your-org/bulk-github-copilot-agent-config
cd bulk-github-copilot-agent-config
npm install

# Run tests
npm test

# Run with development logging
npm run dev -- --config config.yaml --dry-run
```

### Testing

- Unit tests for configuration parsing and validation
- Integration tests with GitHub API mocking
- End-to-end tests with test repositories
- Security tests for credential handling

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🔗 Related Projects

- [GitHub CLI](https://cli.github.com/) - Official GitHub command line tool
- [Model Context Protocol](https://github.com/modelcontextprotocol) - Standard for AI context integration
- [Playwright](https://playwright.dev/) - Browser automation framework

## 📞 Support

- **Documentation**: See [docs/](docs/) for detailed guides
- **Issues**: Report bugs and feature requests on GitHub Issues
- **Discussions**: Join the community discussions for questions and tips
- **Security**: Report security issues to security@yourorg.com
