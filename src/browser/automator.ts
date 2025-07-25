import { Browser, BrowserContext, Page, chromium } from 'playwright';
import { MCPConfig, MergeStrategy } from '../types';
import { Logger } from '../utils/logger';
import { GitHubCLI } from '../github/cli';
import * as fs from 'fs';

export class BrowserAutomator {
  private browser: Browser | null = null;
  private context: BrowserContext | null = null;
  private authToken: string | null = null;
  private debugMode: boolean = false;

  constructor(debugMode: boolean = false) {
    this.debugMode = debugMode;
  }

  async initialize(): Promise<void> {
    try {
      this.browser = await chromium.launch({
        headless: !this.debugMode,
        slowMo: this.debugMode ? 1000 : 0,
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

  private async setPageAuthentication(page: Page): Promise<void> {
    if (this.authToken) {
      await page.setExtraHTTPHeaders({
        'Authorization': `token ${this.authToken}`,
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'bulk-github-copilot-agent-config'
      });
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
      // Get GitHub authentication token from CLI
      this.authToken = await GitHubCLI.getAuthToken();
      
      const page = await this.context.newPage();
      await this.setPageAuthentication(page);
      
      // Try to authenticate by accessing a GitHub API endpoint first
      const response = await page.goto('https://api.github.com/user');
      if (response && response.status() === 200) {
        Logger.info('GitHub API authentication successful');
        
        // Close the API test page
        await page.close();
        
        // Test repository access by trying to access a settings page
        // We'll rely on the authentication headers for subsequent requests
        Logger.info('GitHub authentication verified - will use token-based authentication');
      } else {
        throw new Error(`GitHub API authentication failed with status: ${response?.status()}`);
      }
      
    } catch (error) {
      throw new Error(`GitHub authentication failed: ${error}`);
    }
  }

  async readMCPConfig(repositoryName: string): Promise<MCPConfig | null> {
    if (!this.context) {
      throw new Error('Browser not initialized');
    }

    const page = await this.context.newPage();
    await this.setPageAuthentication(page);
    
    try {
      const url = `https://github.com/${repositoryName}/settings/copilot/coding_agent`;
      Logger.info(`Navigating to: ${url}`);
      await page.goto(url, { waitUntil: 'networkidle' });

      // Wait for the page to load
      await page.waitForTimeout(2000);

      if (this.debugMode) {
        // Save screenshot for debugging
        await page.screenshot({ path: `debug-${repositoryName.replace('/', '-')}-page.png`, fullPage: true });
        
        // Save page HTML for debugging
        const html = await page.content();
        fs.writeFileSync(`debug-${repositoryName.replace('/', '-')}-page.html`, html);
        
        // Log all form elements and potential config fields
        const formElements = await page.locator('form, textarea, [contenteditable], .cm-content, .CodeMirror, input').all();
        Logger.info(`Found ${formElements.length} form elements`);
        
        for (let i = 0; i < formElements.length; i++) {
          const element = formElements[i];
          try {
            const tagName = await element.evaluate(el => el.tagName);
            const className = await element.evaluate(el => el.className || '');
            const id = await element.evaluate(el => el.id || '');
            const text = await element.textContent();
            Logger.info(`Element ${i}: ${tagName} class="${className}" id="${id}" text="${text?.substring(0, 100)}"`);
          } catch (e) {
            Logger.info(`Element ${i}: Failed to inspect - ${e}`);
          }
        }
        
        // Look for any elements that might contain "mcp" or "copilot"
        const mcpElements = await page.locator('*').filter({ hasText: /mcp|copilot|configuration|agent/i }).all();
        Logger.info(`Found ${mcpElements.length} elements mentioning MCP/Copilot/configuration/agent`);
        
        for (let i = 0; i < mcpElements.length && i < 20; i++) {
          const element = mcpElements[i];
          try {
            const tagName = await element.evaluate(el => el.tagName);
            const className = await element.evaluate(el => el.className || '');
            const text = await element.textContent();
            Logger.info(`MCP Element ${i}: ${tagName} class="${className}" text="${text?.substring(0, 200)}"`);
          } catch (e) {
            Logger.info(`MCP Element ${i}: Failed to inspect - ${e}`);
          }
        }
      }

      // Check if we have access to the settings
      const accessDenied = await page.locator("text=You don't have permission").isVisible().catch(() => false);
      if (accessDenied) {
        throw new Error(`No access to repository settings for ${repositoryName}`);
      }

      // Look for the MCP configuration field - try multiple selectors
      const selectors = [
        '.cm-content[contenteditable="true"]',
        '.CodeMirror-code',
        'textarea[name*="mcp"]',
        'textarea[id*="mcp"]',
        '[data-testid*="mcp"]',
        '.form-control[name*="config"]',
        'textarea.form-control',
        '[contenteditable="true"]'
      ];

      let mcpConfigElement = null;
      let foundSelector = '';
      
      for (const selector of selectors) {
        try {
          const element = page.locator(selector).first();
          if (await element.isVisible().catch(() => false)) {
            mcpConfigElement = element;
            foundSelector = selector;
            Logger.info(`Found MCP config element with selector: ${selector}`);
            break;
          }
        } catch (e) {
          // Continue trying other selectors
        }
      }
      
      if (mcpConfigElement) {
        const configText = await mcpConfigElement.textContent();
        Logger.info(`Found config text using selector ${foundSelector}: ${configText?.substring(0, 200)}`);
        
        if (configText && configText.trim()) {
          try {
            // Extract JSON from the text content, handling potential whitespace
            const cleanedText = configText.trim();
            return JSON.parse(cleanedText) as MCPConfig;
          } catch {
            // If it's not JSON, this indicates an unexpected configuration format
            Logger.warn(`MCP config for ${repositoryName} is not valid JSON: ${configText}`);
            throw new Error(`MCP config for ${repositoryName} is not valid JSON`);
          }
        }
      }

      if (this.debugMode) {
        Logger.info('Pausing for manual inspection - press any key in the browser to continue');
        await page.waitForTimeout(30000); // Wait 30 seconds for manual inspection
      }

      Logger.info(`No existing MCP configuration found for ${repositoryName}`);
      return null;
    } catch (error) {
      Logger.error(`Failed to read MCP config for ${repositoryName}: ${error}`);
      throw error;
    } finally {
      if (!this.debugMode) {
        await page.close();
      }
    }
  }

  async updateMCPConfig(repositoryName: string, newConfig: MCPConfig): Promise<void> {
    if (!this.context) {
      throw new Error('Browser not initialized');
    }

    const page = await this.context.newPage();
    await this.setPageAuthentication(page);
    
    try {
      const url = `https://github.com/${repositoryName}/settings/copilot/coding_agent`;
      Logger.info(`Navigating to: ${url}`);
      await page.goto(url, { waitUntil: 'networkidle' });

      // Wait for the page to load
      await page.waitForTimeout(2000);

      if (this.debugMode) {
        // Save screenshot for debugging
        await page.screenshot({ path: `debug-${repositoryName.replace('/', '-')}-update.png`, fullPage: true });
      }

      // Check if we have access to the settings
      const accessDenied = await page.locator("text=You don't have permission").isVisible().catch(() => false);
      if (accessDenied) {
        throw new Error(`No access to repository settings for ${repositoryName}`);
      }

      // Look for the MCP configuration field - try multiple selectors
      const selectors = [
        '.cm-content[contenteditable="true"]',
        '.CodeMirror-code',
        'textarea[name*="mcp"]',
        'textarea[id*="mcp"]',
        '[data-testid*="mcp"]',
        '.form-control[name*="config"]',
        'textarea.form-control',
        '[contenteditable="true"]'
      ];

      let mcpConfigElement = null;
      let foundSelector = '';
      
      for (const selector of selectors) {
        try {
          const element = page.locator(selector).first();
          if (await element.isVisible().catch(() => false)) {
            mcpConfigElement = element;
            foundSelector = selector;
            Logger.info(`Found MCP config element for update with selector: ${selector}`);
            break;
          }
        } catch (e) {
          // Continue trying other selectors
        }
      }
      
      if (mcpConfigElement) {
        // Clear existing content and input new configuration
        await mcpConfigElement.click();
        await page.keyboard.press('Control+a');
        await page.keyboard.type(JSON.stringify(newConfig, null, 2));
        
        if (this.debugMode) {
          Logger.info('Pausing after entering config - press any key in the browser to continue');
          await page.waitForTimeout(10000);
        }
        
        // Look for and click the save button - try multiple selectors
        const saveSelectors = [
          'button:has-text("Save MCP configuration")',
          'button:has-text("Save")',
          'button.prc-Button-ButtonBase-c50BI:has-text("Save")',
          'button[type="submit"]',
          'input[type="submit"]',
          'button.btn-primary'
        ];
        
        let saveButton = null;
        for (const selector of saveSelectors) {
          try {
            const button = page.locator(selector).first();
            if (await button.isVisible().catch(() => false)) {
              saveButton = button;
              Logger.info(`Found save button with selector: ${selector}`);
              break;
            }
          } catch (e) {
            // Continue trying other selectors
          }
        }
        
        if (saveButton) {
          await saveButton.click();
          
          // Wait for save to complete
          await page.waitForTimeout(3000);
          
          // Check for success message or error
          const errorElement = await page.locator('.flash-error, .error, [role="alert"], .alert-error').first();
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
      if (!this.debugMode) {
        await page.close();
      }
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