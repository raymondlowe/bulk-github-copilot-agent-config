# Example Configuration Files

This directory contains example configuration files for various use cases of the Bulk GitHub Copilot Agent Configurator.

## Basic Configuration

See [`basic-config.yaml`](./basic-config.yaml) for a simple configuration that sets up:
- GitHub and Playwright MCP servers
- Basic repository secrets
- Standard security settings

## Enterprise Configuration

See [`enterprise-config.yaml`](./enterprise-config.yaml) for an enterprise setup that includes:
- Multiple MCP servers with custom configurations
- Organization-level secrets and policies
- Advanced security and compliance settings
- Firewall and IP allowlist configurations

## Development Configuration

See [`dev-config.yaml`](./dev-config.yaml) for development environments:
- Development-specific MCP servers
- Test repository configurations
- Relaxed security for development workflows

## Production Configuration

See [`production-config.yaml`](./production-config.yaml) for production deployments:
- Production-hardened security settings
- Compliance-focused configurations
- Enhanced audit and monitoring

## Configuration Validation

You can validate any configuration file using:

```bash
npm run validate-config -- path/to/your/config.yaml
```

## Environment Variables

All configurations support environment variable substitution using the `{{ env.VARIABLE_NAME }}` syntax. Common environment variables include:

- `GITHUB_TOKEN`: GitHub personal access token
- `GITHUB_ORG`: Default organization name
- `API_KEY`: Generic API key for custom integrations
- `VAULT_ADDR`: HashiCorp Vault address
- `LOG_LEVEL`: Logging verbosity level