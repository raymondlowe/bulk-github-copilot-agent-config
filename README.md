# Bulk GitHub Copilot Agent Configurator

A TypeScript-based automation tool that combines GitHub CLI (`gh`) with browser automation to manage GitHub Copilot agent MCP configurations across your personal repositories.

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
- **TypeScript Implementation**: Full type safety and modern JavaScript features

## 🚀 Quick Start

### Prerequisites

- **GitHub CLI** (`gh`) installed and authenticated with your personal account
- **Node.js** 18+ for the TypeScript/JavaScript runtime
- **Repository admin access** for target repositories (your own repos or repos you collaborate on)
- **Chromium browser** for browser automation (automatically installed via Playwright)

**Note**: In some restricted environments (like CI/CD systems), browser automation may not work. In these cases, you can still use the tool for:
- Configuration validation (`validate` command)
- Repository discovery (`list-repos` command) 
- GitHub authentication checking (`check-auth` command)
- Dry-run previews for configuration planning

### Installation

```bash
# Clone the repository
git clone https://github.com/raymondlowe/bulk-github-copilot-agent-config
cd bulk-github-copilot-agent-config

# Install dependencies
npm install

# Build the TypeScript code
npm run build

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

# Processing options
options:
  skip_existing: true  # Skip repos with existing MCP config
  concurrency: 1       # Process one repo at a time for safety
  verbose: true        # Enable detailed logging
```

2. **Create an MCP configuration file** (`mcp-config.yaml`):

```yaml
# This is the content that will be inserted into the MCP configuration field
# in GitHub Copilot Agent settings

github:
  enabled: true
  config:
    token_source: "env:GITHUB_TOKEN"
    repositories: ["*"]  # Allow access to all repositories
    
playwright:
  enabled: true
  config:
    headless: true
    timeout: 30000

# File system access for local development
filesystem:
  enabled: true
  config:
    root_path: "/workspace"
    readonly: false
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
# Validate configuration files first
npm run configure -- validate --repos repos.yaml --mcp-config mcp-config.yaml --secrets secrets.yaml

# Check GitHub authentication
npm run configure -- check-auth

# List repositories that would be configured
npm run configure -- list-repos --repos repos.yaml

# Dry run to preview changes
npm run configure -- configure --repos repos.yaml --mcp-config mcp-config.yaml --dry-run

# Apply MCP configuration only
npm run configure -- configure --repos repos.yaml --mcp-config mcp-config.yaml

# Apply MCP config and secrets/variables
npm run configure -- configure --repos repos.yaml --mcp-config mcp-config.yaml --secrets secrets.yaml
```

## 📋 Configuration Options

### Available Commands

The tool provides several commands for different operations:

```bash
# Main configuration command
npm run configure -- configure [options]

# Validate configuration files without applying changes
npm run configure -- validate --repos <file> --mcp-config <file> [--secrets <file>]

# Check GitHub CLI authentication status
npm run configure -- check-auth

# List repositories that would be configured
npm run configure -- list-repos --repos <file>
```

### MCP Configuration Handling

Control how existing MCP configurations are handled:

```bash
# Don't overwrite existing MCP configs (skip repos that already have MCP config)
npm run configure -- configure --repos repos.yaml --mcp-config mcp-config.yaml --skip-existing

# Merge new MCP servers with existing ones (keep existing, add new)
npm run configure -- configure --repos repos.yaml --mcp-config mcp-config.yaml --merge

# Merge with overwrite option (replace existing servers if they have the same name)
npm run configure -- configure --repos repos.yaml --mcp-config mcp-config.yaml --merge --overwrite-existing

# Force overwrite all MCP configuration (replace entirely)
npm run configure -- configure --repos repos.yaml --mcp-config mcp-config.yaml --force-overwrite
```

### Command Line Options

The `configure` command supports these options:

- `--repos <file>` - Repository configuration file (required)
- `--mcp-config <file>` - MCP server configuration file (required)  
- `--secrets <file>` - Optional secrets and variables configuration file
- `--dry-run` - Preview changes without applying them
- `--skip-existing` - Skip repositories with existing MCP configuration
- `--merge` - Merge new MCP servers with existing ones
- `--overwrite-existing` - When merging, overwrite existing servers with same names
- `--force-overwrite` - Replace entire MCP configuration
- `--concurrency <number>` - Number of repositories to process in parallel (default: 3)
- `--verbose` - Enable verbose logging
- `--resume` - Resume from last failed repository (planned feature)
- `--retry-failed` - Retry only failed repositories from previous run (planned feature)

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
  
# Option 4: Pattern matching (planned feature)
# repositories:
#   patterns:
#     - "myusername/*-service"  # All repos ending with -service
#     - "myusername/app-*"      # All repos starting with app-

# Processing options
options:
  skip_existing: true  # Skip repos with existing MCP config
  concurrency: 1       # Process repos one at a time for safety
  verbose: true        # Enable detailed logging
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

## 🔧 Implementation Details

### Architecture

The tool is built with a modular TypeScript architecture:

- **Configuration Engine** (`src/engine.ts`) - Main orchestrator coordinating all operations
- **GitHub CLI Integration** (`src/github/cli.ts`) - Repository discovery, secrets, and variables management
- **Browser Automation** (`src/browser/automator.ts`) - MCP configuration via Playwright
- **Configuration Parser** (`src/config/parser.ts`) - YAML parsing and validation
- **CLI Interface** (`src/cli.ts`) - Command-line interface using Commander.js
- **Type Definitions** (`src/types/index.ts`) - TypeScript interfaces for type safety

### Technology Stack

- **Runtime**: Node.js 18+
- **Language**: TypeScript for type safety and modern JavaScript features
- **CLI Framework**: Commander.js for robust command-line interface
- **Browser Automation**: Playwright for reliable web automation
- **Configuration**: js-yaml for YAML file parsing
- **Logging**: Winston for structured logging
- **UI**: Chalk and Ora for colorful CLI output with progress indicators

#### Why Playwright over Puppeteer?

We chose **Playwright** over Puppeteer for several key reasons:

- **Better Cross-Browser Support**: Playwright supports Chromium, Firefox, and Safari out of the box, providing more flexibility for future requirements
- **Improved Reliability**: Playwright has better handling of modern web applications with features like auto-waiting for elements and improved network handling
- **Active Development**: Playwright is actively maintained by Microsoft with frequent updates and improvements
- **Enhanced Developer Experience**: Better debugging tools, more comprehensive API, and improved error messages
- **Automatic Browser Management**: Playwright automatically downloads and manages browser binaries, reducing setup complexity
- **Better CI/CD Integration**: More reliable in containerized and headless environments common in automation scenarios

While Puppeteer is excellent for Chrome/Chromium-specific use cases, Playwright's broader compatibility and enhanced reliability make it the better choice for a tool that needs to work consistently across different environments and potentially support multiple browsers in the future.

### Development

```bash
# Development mode with TypeScript compilation
npm run dev -- configure --repos examples/basic-repos.yaml --mcp-config examples/basic-mcp-config.yaml --dry-run

# Build TypeScript to JavaScript
npm run build

# Run linting
npm run lint

# Run tests (when available)
npm test
```

## 📊 Monitoring and Reporting

### Operation Logs

All operations are logged to `operations.log` with structured JSON format:
- Timestamp and repository information
- MCP configuration changes made
- Success/failure status with error details
- Before/after state comparisons for auditing

### Progress Tracking

Monitor bulk operations with real-time feedback:
- Spinner progress indicators for current operations
- Colored output showing success/failure status
- Detailed error messages with suggested fixes
- Summary reports after completion

### Example Output

```bash
🚀 GitHub Copilot Agent Bulk Configurator

✅ Found 5 repositories to configure

🔍 DRY RUN MODE - No changes will be applied

📋 Configuration Preview

Repositories to configure (5):
  • myusername/repo1
  • myusername/repo2
  • myusername/repo3
  • myusername/repo4
  • myusername/repo5

MCP servers to configure:
  • github (enabled: true)
  • playwright (enabled: true)
  • filesystem (enabled: true)

Merge strategy: skip

Run without --dry-run to apply these changes.
```

## ⚠️ Current Limitations

### Implementation Status

**✅ Completed Features:**
- Complete TypeScript implementation with type safety
- Configuration file parsing and validation
- GitHub CLI integration for repository management
- Browser automation framework for MCP configuration
- Full CLI interface with multiple commands
- Comprehensive error handling and logging
- Dry-run mode for safe operations

**⚠️ Known Limitations:**
- **MCP Configuration**: Browser automation may need updates if GitHub changes their Copilot settings interface
- **Pattern Matching**: Repository pattern matching is planned but not yet implemented
- **Resume/Retry**: Resume and retry functionality is planned but not yet implemented
- **Rate Limiting**: No built-in rate limiting for GitHub API calls
- **Session Persistence**: Browser sessions don't persist across runs

**🔄 Planned Enhancements:**
- Repository pattern matching support (`myusername/*-service`)
- Resume from failed operations
- Retry failed repositories from previous runs
- Enhanced error recovery mechanisms
- Performance optimizations for large repository sets

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup

```bash
# Clone and setup development environment
git clone https://github.com/raymondlowe/bulk-github-copilot-agent-config
cd bulk-github-copilot-agent-config
npm install

# Build the project
npm run build

# Run development mode
npm run dev -- configure --help

# Run validation tests
npm run configure -- validate --repos examples/basic-repos.yaml --mcp-config examples/basic-mcp-config.yaml
```

### Code Structure

```
src/
├── cli.ts              # Command-line interface
├── engine.ts           # Main orchestration engine
├── index.ts            # Public API exports
├── types/
│   └── index.ts        # TypeScript type definitions
├── config/
│   └── parser.ts       # Configuration file parsing
├── github/
│   └── cli.ts          # GitHub CLI integration
├── browser/
│   └── automator.ts    # Browser automation for MCP
└── utils/
    └── logger.ts       # Logging utilities
```

### Testing Approach

Currently the tool can be tested using:
- Configuration validation with example files
- Dry-run mode to preview operations without applying changes
- Authentication checks to verify GitHub CLI setup
- Repository listing to verify discovery logic

Future testing enhancements will include:
- Unit tests for configuration parsing and validation
- Integration tests with GitHub API mocking
- End-to-end tests with test repositories

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
