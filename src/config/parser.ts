import * as yaml from 'js-yaml';
import * as fs from 'fs-extra';
import { RepoConfig, MCPConfig, SecretsConfig } from '../types';
import { Logger } from '../utils/logger';

export class ConfigParser {
  static async parseRepoConfig(filePath: string): Promise<RepoConfig> {
    try {
      const content = await fs.readFile(filePath, 'utf8');
      const config = yaml.load(content) as RepoConfig;
      
      this.validateRepoConfig(config);
      return config;
    } catch (error) {
      throw new Error(`Failed to parse repository config: ${error}`);
    }
  }

  static async parseMCPConfig(filePath: string): Promise<MCPConfig> {
    try {
      const content = await fs.readFile(filePath, 'utf8');
      let config: MCPConfig;
      
      // Determine format by file extension or content
      const isJsonFile = filePath.toLowerCase().endsWith('.json');
      const isYamlFile = filePath.toLowerCase().endsWith('.yaml') || filePath.toLowerCase().endsWith('.yml');
      
      if (isJsonFile) {
        // Parse as JSON
        config = JSON.parse(content) as MCPConfig;
      } else if (isYamlFile) {
        // Parse as YAML
        config = yaml.load(content) as MCPConfig;
      } else {
        // Auto-detect format - try JSON first since it's more common for MCP configs
        try {
          config = JSON.parse(content) as MCPConfig;
        } catch {
          // Fall back to YAML
          config = yaml.load(content) as MCPConfig;
        }
      }
      
      this.validateMCPConfig(config);
      return config;
    } catch (error) {
      throw new Error(`Failed to parse MCP config: ${error}`);
    }
  }

  static async parseSecretsConfig(filePath: string): Promise<SecretsConfig> {
    try {
      const content = await fs.readFile(filePath, 'utf8');
      const config = yaml.load(content) as SecretsConfig;
      
      this.validateSecretsConfig(config);
      return config;
    } catch (error) {
      throw new Error(`Failed to parse secrets config: ${error}`);
    }
  }

  private static validateRepoConfig(config: RepoConfig): void {
    if (!config.repositories && !config.all_accessible_repos) {
      throw new Error('Repository config must specify either "repositories" or "all_accessible_repos"');
    }

    if (config.repositories && config.all_accessible_repos) {
      throw new Error('Repository config cannot specify both "repositories" and "all_accessible_repos"');
    }

    if (config.repositories && !Array.isArray(config.repositories)) {
      throw new Error('Repository config "repositories" must be an array');
    }

    if (config.options?.concurrency && config.options.concurrency < 1) {
      throw new Error('Concurrency must be at least 1');
    }
  }

  private static validateMCPConfig(config: MCPConfig): void {
    if (!config || typeof config !== 'object') {
      throw new Error('MCP config must be an object');
    }

    if (!config.mcpServers || typeof config.mcpServers !== 'object') {
      throw new Error('MCP config must have an "mcpServers" object property');
    }

    for (const [serverName, serverConfig] of Object.entries(config.mcpServers)) {
      if (!serverConfig || typeof serverConfig !== 'object') {
        throw new Error(`MCP server "${serverName}" config must be an object`);
      }

      if (!serverConfig.type || !['http', 'local'].includes(serverConfig.type)) {
        throw new Error(`MCP server "${serverName}" must have a "type" property set to "http" or "local"`);
      }

      if (!Array.isArray(serverConfig.tools)) {
        throw new Error(`MCP server "${serverName}" must have a "tools" array property`);
      }

      if (serverConfig.type === 'http') {
        if (!serverConfig.url || typeof serverConfig.url !== 'string') {
          throw new Error(`HTTP MCP server "${serverName}" must have a "url" string property`);
        }
      }

      if (serverConfig.type === 'local') {
        if (!serverConfig.command || typeof serverConfig.command !== 'string') {
          throw new Error(`Local MCP server "${serverName}" must have a "command" string property`);
        }
      }
    }
  }

  private static validateSecretsConfig(config: SecretsConfig): void {
    if (config.secrets && typeof config.secrets !== 'object') {
      throw new Error('Secrets config "secrets" must be an object');
    }

    if (config.variables && typeof config.variables !== 'object') {
      throw new Error('Secrets config "variables" must be an object');
    }
  }

  static resolveEnvironmentVariables(value: string): string {
    // Replace {{ env.VARIABLE_NAME }} with actual environment variable values
    return value.replace(/\{\{\s*env\.(\w+)\s*\}\}/g, (_, varName) => {
      const envValue = process.env[varName];
      if (envValue === undefined) {
        Logger.warn(`Environment variable ${varName} is not set, using empty string as default`);
        return ''; // Use empty string as default value
      }
      return envValue;
    });
  }

  static processSecretsConfig(config: SecretsConfig): SecretsConfig {
    const processedConfig: SecretsConfig = {};

    if (config.secrets) {
      processedConfig.secrets = {};
      for (const [key, value] of Object.entries(config.secrets)) {
        processedConfig.secrets[key] = this.resolveEnvironmentVariables(value);
      }
    }

    if (config.variables) {
      processedConfig.variables = {};
      for (const [key, value] of Object.entries(config.variables)) {
        processedConfig.variables[key] = this.resolveEnvironmentVariables(value);
      }
    }

    return processedConfig;
  }
}