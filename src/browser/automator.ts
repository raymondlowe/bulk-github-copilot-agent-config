import { Browser, BrowserContext, Page, chromium } from 'playwright';
import { MCPConfig, MergeStrategy } from '../types';
import { Logger } from '../utils/logger';

export class BrowserAutomator {
  private browser: Browser | null = null;
  private context: BrowserContext | null = null;

  async initialize(): Promise<void> {
    try {
      this.browser = await chromium.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox']
      });
      
      this.context = await this.browser.newContext({
        userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
      });
      
      Logger.info('Browser automation initialized');
    } catch (error) {
      throw new Error(`Failed to initialize browser: ${error}`);
    }
  }

  async cleanup(): Promise<void> {
    try {
      if (this.context) {
        await this.context.close();
        this.context = null;
      }
      if (this.browser) {
        await this.browser.close();
        this.browser = null;
      }
      Logger.info('Browser automation cleaned up');
    } catch (error) {
      Logger.error(`Failed to cleanup browser: ${error}`);
    }
  }

  async authenticateWithGitHub(): Promise<void> {
    if (!this.context) {
      throw new Error('Browser not initialized');
    }

    try {
      const page = await this.context.newPage();
      
      // Try to access GitHub and check if we're already authenticated
      await page.goto('https://github.com/settings');
      
      // Wait a moment for potential redirects
      await page.waitForTimeout(2000);
      
      const currentUrl = page.url();
      if (currentUrl.includes('/login')) {
        throw new Error('Not authenticated with GitHub. Please ensure GitHub CLI is authenticated and try again.');
      }
      
      Logger.info('GitHub authentication verified via browser');
      await page.close();
    } catch (error) {
      throw new Error(`GitHub authentication failed: ${error}`);
    }
  }

  async readMCPConfig(repositoryName: string): Promise<MCPConfig | null> {
    if (!this.context) {
      throw new Error('Browser not initialized');
    }

    const page = await this.context.newPage();
    
    try {
      const url = `https://github.com/${repositoryName}/settings/copilot`;
      await page.goto(url, { waitUntil: 'networkidle' });

      // Wait for the page to load
      await page.waitForTimeout(2000);

      // Check if we have access to the settings
      const accessDenied = await page.locator("text=You don't have permission").isVisible().catch(() => false);
      if (accessDenied) {
        throw new Error(`No access to repository settings for ${repositoryName}`);
      }

      // Look for the MCP configuration textarea or field
      // Note: This is a best-guess implementation since GitHub's Copilot settings page structure may vary
      const mcpConfigElement = await page.locator('textarea[name*="mcp"], textarea[id*="mcp"], textarea[placeholder*="MCP"]').first();
      
      if (await mcpConfigElement.isVisible().catch(() => false)) {
        const configText = await mcpConfigElement.inputValue();
        if (configText.trim()) {
          try {
            return JSON.parse(configText) as MCPConfig;
          } catch {
            // If it's not JSON, treat it as YAML-like configuration
            Logger.warn(`MCP config for ${repositoryName} is not valid JSON, treating as raw text`);
            return null;
          }
        }
      }

      Logger.info(`No existing MCP configuration found for ${repositoryName}`);
      return null;
    } catch (error) {
      Logger.error(`Failed to read MCP config for ${repositoryName}: ${error}`);
      throw error;
    } finally {
      await page.close();
    }
  }

  async updateMCPConfig(repositoryName: string, newConfig: MCPConfig): Promise<void> {
    if (!this.context) {
      throw new Error('Browser not initialized');
    }

    const page = await this.context.newPage();
    
    try {
      const url = `https://github.com/${repositoryName}/settings/copilot`;
      await page.goto(url, { waitUntil: 'networkidle' });

      // Wait for the page to load
      await page.waitForTimeout(2000);

      // Check if we have access to the settings
      const accessDenied = await page.locator("text=You don't have permission").isVisible().catch(() => false);
      if (accessDenied) {
        throw new Error(`No access to repository settings for ${repositoryName}`);
      }

      // Look for the MCP configuration textarea or field
      const mcpConfigElement = await page.locator('textarea[name*="mcp"], textarea[id*="mcp"], textarea[placeholder*="MCP"]').first();
      
      if (await mcpConfigElement.isVisible().catch(() => false)) {
        // Clear existing content and input new configuration
        await mcpConfigElement.fill('');
        await mcpConfigElement.fill(JSON.stringify(newConfig, null, 2));
        
        // Look for and click save button
        const saveButton = await page.locator('button:has-text("Save"), input[type="submit"][value*="Save"], button[type="submit"]').first();
        
        if (await saveButton.isVisible().catch(() => false)) {
          await saveButton.click();
          
          // Wait for save to complete
          await page.waitForTimeout(2000);
          
          // Check for success message or error
          const errorElement = await page.locator('.flash-error, .error, [role="alert"]').first();
          if (await errorElement.isVisible().catch(() => false)) {
            const errorText = await errorElement.textContent();
            throw new Error(`Failed to save MCP config: ${errorText}`);
          }
          
          Logger.info(`Successfully updated MCP configuration for ${repositoryName}`);
        } else {
          throw new Error('Could not find save button for MCP configuration');
        }
      } else {
        throw new Error('Could not find MCP configuration field');
      }
    } catch (error) {
      Logger.error(`Failed to update MCP config for ${repositoryName}: ${error}`);
      throw error;
    } finally {
      await page.close();
    }
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
        const merged = { ...existing };
        for (const [serverName, serverConfig] of Object.entries(newConfig)) {
          if (!merged[serverName]) {
            merged[serverName] = serverConfig;
          }
        }
        return merged;

      case MergeStrategy.MERGE_OVERWRITE:
        if (!existing) {
          return newConfig;
        }
        // Merge new servers with existing ones, overwriting existing servers with same names
        return { ...existing, ...newConfig };

      case MergeStrategy.FORCE_OVERWRITE:
        return newConfig;

      default:
        throw new Error(`Unknown merge strategy: ${strategy}`);
    }
  }

  async configureRepository(repositoryName: string, newConfig: MCPConfig, strategy: MergeStrategy): Promise<{
    before: MCPConfig | null;
    after: MCPConfig;
    strategy: string;
  }> {
    Logger.info(`Configuring MCP for repository ${repositoryName} with strategy: ${strategy}`);
    
    // Read existing configuration
    const existingConfig = await this.readMCPConfig(repositoryName);
    
    // Apply merge strategy
    const finalConfig = this.mergeMCPConfig(existingConfig, newConfig, strategy);
    
    // Skip update if configuration would be identical
    if (existingConfig && JSON.stringify(existingConfig) === JSON.stringify(finalConfig)) {
      Logger.info(`No changes needed for ${repositoryName}`);
      return {
        before: existingConfig,
        after: finalConfig,
        strategy
      };
    }

    // Update the configuration
    await this.updateMCPConfig(repositoryName, finalConfig);
    
    return {
      before: existingConfig,
      after: finalConfig,
      strategy
    };
  }
}