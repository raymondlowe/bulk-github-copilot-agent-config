# Bulk GitHub Copilot Agent Configurator

A powerful automation tool that combines GitHub CLI (`gh`) with intelligent browser automation to manage GitHub Copilot agent configurations across multiple repositories at scale.

## 🎯 Purpose

Managing GitHub Copilot agent settings across dozens or hundreds of repositories manually is time-consuming and error-prone. This tool automates the bulk configuration of:

- **MCP (Model Context Protocol) servers** - Configure external tools and context sources
- **Repository secrets and keys** - Manage API keys and sensitive configuration
- **Firewall rules and IP allowlists** - Configure network security settings
- **Access permissions and security policies** - Standardize security configurations

## ✨ Key Features

- **Hybrid Automation**: Leverages GitHub CLI for API-accessible settings and browser automation for web-only configurations
- **Secure Credential Management**: Safe handling of sensitive data with audit trails
- **Bulk Operations**: Process 60+ repositories efficiently with parallel execution
- **Configuration as Code**: Define all settings in version-controlled configuration files
- **Comprehensive Logging**: Full audit trail of all changes with rollback capability
- **Error Resilience**: Robust error handling with retry logic and detailed reporting

## 🚀 Quick Start

### Prerequisites

- **GitHub CLI** (`gh`) installed and authenticated
- **Node.js** 18+ for browser automation components
- **Repository admin access** for target repositories
- **Organization permissions** for firewall and security settings

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

1. **Create a configuration file** (`config.yaml`):

```yaml
repositories:
  - "org/repo1"
  - "org/repo2"
  - "org/repo3"

mcp_servers:
  github:
    enabled: true
    config:
      token_source: "env:GITHUB_TOKEN"
  
  playwright:
    enabled: true
    config:
      headless: true

secrets:
  API_KEY: "{{ env.API_KEY }}"
  DATABASE_URL: "{{ env.DATABASE_URL }}"

firewall:
  ip_allowlist:
    - "192.168.1.0/24"
    - "10.0.0.0/8"
```

2. **Run the configurator**:

```bash
# Dry run to preview changes
npm run configure -- --config config.yaml --dry-run

# Apply configuration
npm run configure -- --config config.yaml --apply
```

## 📋 Configuration Options

### MCP Server Configuration

Configure Model Context Protocol servers for enhanced Copilot capabilities:

```yaml
mcp_servers:
  github:
    enabled: true
    config:
      token_source: "env:GITHUB_TOKEN"
      repositories: ["*"]  # or specific repos
  
  playwright:
    enabled: true
    config:
      headless: true
      timeout: 30000
  
  custom_server:
    enabled: true
    config:
      endpoint: "https://api.example.com"
      auth_header: "Bearer {{ secrets.CUSTOM_API_KEY }}"
```

### Repository Secrets Management

Bulk manage repository and organization secrets:

```yaml
secrets:
  repository_level:
    API_KEY: "{{ env.API_KEY }}"
    DATABASE_URL: "{{ env.DATABASE_URL }}"
  
  organization_level:
    SHARED_SECRET: "{{ vault.shared_secret }}"
    
variables:
  BUILD_ENVIRONMENT: "production"
  LOG_LEVEL: "info"
```

### Security Configuration

Configure firewall rules and access controls:

```yaml
security:
  ip_allowlist:
    enabled: true
    addresses:
      - "192.168.1.0/24"
      - "10.0.0.0/8"
  
  required_status_checks:
    enabled: true
    checks:
      - "ci/build"
      - "security/scan"
  
  branch_protection:
    main:
      require_pr_reviews: true
      dismiss_stale_reviews: true
      require_code_owner_reviews: true
```

## 🔒 Security Considerations

### Credential Management

- **Never store secrets in plain text** - Use environment variables or external secret managers
- **Principle of least privilege** - Grant minimum necessary permissions
- **Audit logging** - All actions are logged with timestamps and user attribution
- **Secure communication** - All API calls use HTTPS with proper authentication

### Browser Automation Security

- **Headless operation** - Runs without UI for security and performance
- **Session isolation** - Each repository configuration uses isolated browser contexts
- **Credential injection** - Passwords and tokens are injected securely without disk storage
- **Screenshot capture** - Optional screenshots for audit purposes (PII-scrubbed)

## 🔧 Advanced Usage

### Selective Configuration

Apply configuration to specific repository subsets:

```bash
# Filter by organization
npm run configure -- --org myorg --apply

# Filter by topic tags
npm run configure -- --topic copilot-enabled --apply

# Filter by name pattern
npm run configure -- --pattern "*-service" --apply
```

### Parallel Execution

Control concurrency for large-scale operations:

```bash
# Process 5 repositories in parallel
npm run configure -- --concurrency 5 --apply

# Enable rate limiting for API calls
npm run configure -- --rate-limit 100 --apply
```

### Error Recovery

Handle failures gracefully:

```bash
# Resume from last failed repository
npm run configure -- --resume --apply

# Retry specific repositories
npm run configure -- --retry-failed --apply

# Generate detailed error report
npm run configure -- --error-report
```

## 📊 Monitoring and Reporting

### Audit Logs

All operations are logged to `audit.json` with:
- Timestamp and user information
- Repository and configuration changes
- Success/failure status with error details
- Before/after state comparisons

### Progress Tracking

Monitor bulk operations in real-time:
- Progress bars for multi-repository operations
- Real-time status updates
- ETA calculations
- Failure notifications with retry suggestions

### Compliance Reporting

Generate compliance reports for:
- Security configuration adherence
- MCP server deployment status
- Secret rotation compliance
- Access control audit results

## ⚠️ Limitations and Known Issues

### Current Limitations

- **MCP Configuration**: Requires browser automation as GitHub doesn't provide API access
- **Rate Limiting**: GitHub API rate limits may slow bulk operations (workaround: authentication tokens)
- **Browser Dependencies**: Requires Chrome/Chromium for web automation features
- **Organization Permissions**: Some settings require enterprise-level permissions

### Known Issues

- **Session Timeouts**: Long-running operations may require re-authentication
- **Large Repository Sets**: Memory usage increases with repository count (recommend batching)
- **Network Connectivity**: Requires stable internet for browser automation components

### Workarounds

- Use multiple authentication tokens to increase rate limits
- Process repositories in batches for large operations
- Implement retry logic for transient failures
- Cache repository metadata to reduce API calls

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
