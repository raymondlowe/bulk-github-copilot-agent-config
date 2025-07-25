import { MCPConfig, MergeStrategy } from '../types';
import { Logger } from '../utils/logger';
import { GitHubCLI } from './cli';

export class GitHubAPIAutomator {
  private authToken: string | null = null;

  async initialize(): Promise<void> {
    try {
      this.authToken = await GitHubCLI.getAuthToken();
      Logger.info('GitHub API automator initialized');
    } catch (error) {
      throw new Error(`Failed to initialize GitHub API: ${error}`);
    }
  }

  private async makeRequest(url: string, options: RequestInit = {}): Promise<Response> {
    if (!this.authToken) {
      throw new Error('GitHub API not initialized');
    }

    const headers = {
      'Authorization': `token ${this.authToken}`,
      'Accept': 'application/vnd.github.v3+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'bulk-github-copilot-agent-config',
      ...options.headers
    };

    return fetch(url, {
      ...options,
      headers
    });
  }

  async readMCPConfig(repositoryName: string): Promise<MCPConfig | null> {
    const [owner, repo] = repositoryName.split('/');
    
    // Try various potential endpoints for MCP configuration
    const endpoints = [
      // Most likely endpoint patterns for Copilot settings
      `https://api.github.com/repos/${owner}/${repo}/copilot/mcp`,
      `https://api.github.com/repos/${owner}/${repo}/copilot/servers`,
      `https://api.github.com/repos/${owner}/${repo}/copilot/configuration`,
      `https://api.github.com/repos/${owner}/${repo}/settings/copilot`,
      `https://api.github.com/repos/${owner}/${repo}/settings/copilot/mcp`,
      `https://api.github.com/repos/${owner}/${repo}/settings/copilot/coding-agent`,
      `https://api.github.com/repos/${owner}/${repo}/settings/copilot/coding_agent`,
      
      // Preview API endpoints (common pattern for new features)
      `https://api.github.com/repos/${owner}/${repo}/copilot/mcp`,
      `https://api.github.com/repos/${owner}/${repo}/copilot/servers`,
      
      // With preview headers that GitHub sometimes uses
      `https://api.github.com/repos/${owner}/${repo}/settings/copilot`,
    ];

    const previewHeaders = [
      'application/vnd.github.v3+json',
      'application/vnd.github+json',
      'application/vnd.github.preview+json',
      'application/vnd.github.copilot-preview+json',
      'application/vnd.github.mcp-preview+json',
      'application/vnd.github.coding-agent-preview+json',
    ];

    for (const endpoint of endpoints) {
      for (const acceptHeader of previewHeaders) {
        try {
          Logger.info(`Trying endpoint: ${endpoint} with Accept: ${acceptHeader}`);
          
          const response = await this.makeRequest(endpoint, {
            method: 'GET',
            headers: {
              'Accept': acceptHeader
            }
          });

          Logger.info(`Response status: ${response.status} for ${endpoint}`);

          if (response.status === 200) {
            const data = await response.json();
            Logger.info(`Found MCP config data: ${JSON.stringify(data, null, 2)}`);
            
            // Try to parse the response as MCP config
            if (data && typeof data === 'object') {
              const responseData = data as any;
              if (responseData.mcpServers) {
                return responseData as MCPConfig;
              } else if (responseData.servers) {
                return { mcpServers: responseData.servers } as MCPConfig;
              } else if (responseData.mcp) {
                return responseData.mcp as MCPConfig;
              } else if (responseData.configuration) {
                return responseData.configuration as MCPConfig;
              } else {
                // Log the response structure for debugging
                Logger.info(`Unknown response structure: ${JSON.stringify(data, null, 2)}`);
              }
            }
          } else if (response.status === 404) {
            // Not found, continue to next endpoint
            continue;
          } else if (response.status === 403) {
            Logger.warn(`Access denied for ${endpoint}: ${response.status}`);
            const errorData = await response.text();
            Logger.warn(`Error details: ${errorData}`);
          } else {
            // Log other status codes for debugging
            const errorData = await response.text();
            Logger.info(`Endpoint ${endpoint} returned ${response.status}: ${errorData}`);
          }
        } catch (error) {
          Logger.warn(`Error trying endpoint ${endpoint}: ${error}`);
        }
      }
    }

    Logger.info(`No MCP configuration found via API for ${repositoryName}`);
    return null;
  }

  async updateMCPConfig(repositoryName: string, newConfig: MCPConfig): Promise<void> {
    const [owner, repo] = repositoryName.split('/');
    
    // Try various potential endpoints for updating MCP configuration
    const endpoints = [
      // Most likely endpoint patterns for Copilot settings
      `https://api.github.com/repos/${owner}/${repo}/copilot/mcp`,
      `https://api.github.com/repos/${owner}/${repo}/copilot/servers`,
      `https://api.github.com/repos/${owner}/${repo}/copilot/configuration`,
      `https://api.github.com/repos/${owner}/${repo}/settings/copilot`,
      `https://api.github.com/repos/${owner}/${repo}/settings/copilot/mcp`,
      `https://api.github.com/repos/${owner}/${repo}/settings/copilot/coding-agent`,
      `https://api.github.com/repos/${owner}/${repo}/settings/copilot/coding_agent`,
    ];

    const previewHeaders = [
      'application/vnd.github.v3+json',
      'application/vnd.github+json',
      'application/vnd.github.preview+json',
      'application/vnd.github.copilot-preview+json',
      'application/vnd.github.mcp-preview+json',
      'application/vnd.github.coding-agent-preview+json',
    ];

    // Try different payload formats
    const payloads = [
      newConfig,                           // Direct MCP config
      { mcpServers: newConfig.mcpServers }, // Wrapped in mcpServers
      { servers: newConfig.mcpServers },    // Wrapped in servers
      { mcp: newConfig },                   // Wrapped in mcp
      { configuration: newConfig },         // Wrapped in configuration
    ];

    for (const endpoint of endpoints) {
      for (const acceptHeader of previewHeaders) {
        for (const payload of payloads) {
          try {
            Logger.info(`Trying to update endpoint: ${endpoint} with Accept: ${acceptHeader}`);
            
            const response = await this.makeRequest(endpoint, {
              method: 'PUT',
              headers: {
                'Accept': acceptHeader,
                'Content-Type': 'application/json'
              },
              body: JSON.stringify(payload)
            });

            Logger.info(`Update response status: ${response.status} for ${endpoint}`);

            if (response.status === 200 || response.status === 201 || response.status === 204) {
              Logger.info(`Successfully updated MCP configuration for ${repositoryName} via ${endpoint}`);
              return;
            } else if (response.status === 404) {
              // Not found, continue to next endpoint
              continue;
            } else if (response.status === 403) {
              Logger.warn(`Access denied for ${endpoint}: ${response.status}`);
              const errorData = await response.text();
              Logger.warn(`Error details: ${errorData}`);
            } else {
              // Log other status codes for debugging
              const errorData = await response.text();
              Logger.info(`Update endpoint ${endpoint} returned ${response.status}: ${errorData}`);
            }
          } catch (error) {
            Logger.warn(`Error updating endpoint ${endpoint}: ${error}`);
          }

          // Also try PATCH method
          try {
            const response = await this.makeRequest(endpoint, {
              method: 'PATCH',
              headers: {
                'Accept': acceptHeader,
                'Content-Type': 'application/json'
              },
              body: JSON.stringify(payload)
            });

            if (response.status === 200 || response.status === 201 || response.status === 204) {
              Logger.info(`Successfully updated MCP configuration for ${repositoryName} via PATCH ${endpoint}`);
              return;
            }
          } catch (error) {
            // Continue to next endpoint
          }

          // Also try POST method
          try {
            const response = await this.makeRequest(endpoint, {
              method: 'POST',
              headers: {
                'Accept': acceptHeader,
                'Content-Type': 'application/json'
              },
              body: JSON.stringify(payload)
            });

            if (response.status === 200 || response.status === 201 || response.status === 204) {
              Logger.info(`Successfully updated MCP configuration for ${repositoryName} via POST ${endpoint}`);
              return;
            }
          } catch (error) {
            // Continue to next endpoint
          }
        }
      }
    }

    throw new Error(`Could not find working API endpoint to update MCP configuration for ${repositoryName}`);
  }

  async cleanup(): Promise<void> {
    Logger.info('GitHub API automator cleaned up');
  }

  mergeMCPConfig(existing: MCPConfig | null, newConfig: MCPConfig, strategy: MergeStrategy): MCPConfig {
    switch (strategy) {
      case MergeStrategy.SKIP:
        if (existing) {
          Logger.info('Skipping repository with existing MCP configuration');
          return existing;
        }
        return newConfig;

      case MergeStrategy.MERGE:
        if (!existing) {
          return newConfig;
        }
        // Merge new servers with existing ones, keeping existing ones intact
        const merged: MCPConfig = { 
          mcpServers: { ...existing.mcpServers }
        };
        for (const [serverName, serverConfig] of Object.entries(newConfig.mcpServers)) {
          if (!merged.mcpServers[serverName]) {
            merged.mcpServers[serverName] = serverConfig;
          }
        }
        return merged;

      case MergeStrategy.MERGE_OVERWRITE:
        if (!existing) {
          return newConfig;
        }
        // Merge new servers with existing ones, overwriting existing servers with same names
        return { 
          mcpServers: { ...existing.mcpServers, ...newConfig.mcpServers }
        };

      case MergeStrategy.FORCE_OVERWRITE:
        return newConfig;

      default:
        throw new Error(`Unknown merge strategy: ${strategy}`);
    }
  }
}
