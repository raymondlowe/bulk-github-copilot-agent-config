import { BrowserAutomator } from '../browser/automator';
import { MCPConfig, MergeStrategy } from '../types';

describe('MCP Config Merge Logic', () => {
  let automator: BrowserAutomator;

  beforeEach(() => {
    automator = new BrowserAutomator();
  });

  const existingConfig: MCPConfig = {
    mcpServers: {
      'existing-server': {
        type: 'http',
        url: 'https://existing.example.com',
        headers: {
          'Authorization': 'Bearer existing-token'
        },
        tools: ['tool1', 'tool2']
      }
    }
  };

  const newConfig: MCPConfig = {
    mcpServers: {
      'new-server': {
        type: 'local',
        command: 'npx',
        args: ['new-server'],
        env: {
          'NEW_API_KEY': 'new-value'
        },
        tools: ['tool3', 'tool4']
      },
      'existing-server': {
        type: 'http',
        url: 'https://updated.example.com',
        headers: {
          'Authorization': 'Bearer updated-token'
        },
        tools: ['tool1', 'tool2', 'tool5']
      }
    }
  };

  test('SKIP strategy returns existing config when present', () => {
    const result = automator.mergeMCPConfig(existingConfig, newConfig, MergeStrategy.SKIP);
    expect(result).toEqual(existingConfig);
  });

  test('SKIP strategy returns new config when no existing config', () => {
    const result = automator.mergeMCPConfig(null, newConfig, MergeStrategy.SKIP);
    expect(result).toEqual(newConfig);
  });

  test('MERGE strategy preserves existing servers and adds new ones', () => {
    const result = automator.mergeMCPConfig(existingConfig, newConfig, MergeStrategy.MERGE);
    
    expect(result.mcpServers['existing-server']).toEqual(existingConfig.mcpServers['existing-server']);
    expect(result.mcpServers['new-server']).toEqual(newConfig.mcpServers['new-server']);
  });

  test('MERGE_OVERWRITE strategy overwrites existing servers with same name', () => {
    const result = automator.mergeMCPConfig(existingConfig, newConfig, MergeStrategy.MERGE_OVERWRITE);
    
    expect(result.mcpServers['existing-server']).toEqual(newConfig.mcpServers['existing-server']);
    expect(result.mcpServers['new-server']).toEqual(newConfig.mcpServers['new-server']);
  });

  test('FORCE_OVERWRITE strategy completely replaces config', () => {
    const result = automator.mergeMCPConfig(existingConfig, newConfig, MergeStrategy.FORCE_OVERWRITE);
    expect(result).toEqual(newConfig);
  });

  test('handles null existing config gracefully', () => {
    const result = automator.mergeMCPConfig(null, newConfig, MergeStrategy.MERGE);
    expect(result).toEqual(newConfig);
  });
});