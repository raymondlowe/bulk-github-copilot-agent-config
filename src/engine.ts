import { ConfigParser } from './config/parser';
import { GitHubCLI } from './github/cli';
import { GitHubAPIAutomator } from './github/api';
import { BrowserAutomator } from './browser/automator';
import { Logger } from './utils/logger';
import {
  ConfigurationOptions,
  Repository,
  MCPConfig,
  SecretsConfig,
  OperationResult,
  OperationSummary,
  MergeStrategy
} from './types';
import ora from 'ora';
import chalk from 'chalk';

export class ConfigurationEngine {
  private githubCLI: GitHubCLI;
  private apiAutomator: GitHubAPIAutomator;
  private browserAutomator: BrowserAutomator;
  private spinner: any;

  constructor() {
    this.githubCLI = new GitHubCLI();
    this.apiAutomator = new GitHubAPIAutomator();
    // BrowserAutomator will be initialized with debug mode in configure method
    this.browserAutomator = new BrowserAutomator();
  }

  async configure(options: ConfigurationOptions): Promise<OperationSummary> {
    const startTime = Date.now();
    this.spinner = ora('Starting configuration process...').start();

    try {
      // Set logging level
      if (options.verbose) {
        Logger.setLevel('debug');
      }

      Logger.info('Starting bulk GitHub Copilot agent configuration', options);

      // Parse configuration files
      this.spinner.text = 'Parsing configuration files...';
      const repoConfig = await ConfigParser.parseRepoConfig(options.repoConfig);
      const mcpConfig = await ConfigParser.parseMCPConfig(options.mcpConfig);
      
      let secretsConfig: SecretsConfig | undefined;
      if (options.secretsConfig) {
        secretsConfig = await ConfigParser.parseSecretsConfig(options.secretsConfig);
        secretsConfig = ConfigParser.processSecretsConfig(secretsConfig);
      }

      // Determine merge strategy
      const mergeStrategy = this.determineMergeStrategy(options);
      Logger.info(`Using merge strategy: ${mergeStrategy}`);

      // Discover repositories
      this.spinner.text = 'Discovering repositories...';
      const repositories = await this.discoverRepositories(repoConfig);
      
      if (repositories.length === 0) {
        this.spinner.fail('No repositories found matching the criteria');
        return this.createSummary([], startTime);
      }

      this.spinner.succeed(`Found ${repositories.length} repositories to configure`);

      if (options.dryRun) {
        console.log(chalk.yellow('\n🔍 DRY RUN MODE - No changes will be applied\n'));
        await this.displayDryRunPreview(repositories, mcpConfig, secretsConfig, mergeStrategy);
        return this.createSummary([], startTime);
      }

      // Initialize API automator first (faster and less resource intensive)
      await this.apiAutomator.initialize();
      
      // Only initialize browser automation if not in API-only mode
      if (!options.apiOnly) {
        this.browserAutomator = new BrowserAutomator(options.debug, options.interactiveAuth);
        await this.browserAutomator.initialize();
        await this.browserAutomator.authenticateWithGitHub();
      }

      // Process repositories
      const results = await this.processRepositories(
        repositories,
        mcpConfig,
        secretsConfig,
        mergeStrategy,
        options.concurrency,
        options.apiOnly,
        options.interactiveAuth
      );

      // Cleanup
      await this.apiAutomator.cleanup();
      await this.browserAutomator.cleanup();

      // Generate summary
      const summary = this.createSummary(results, startTime);
      this.displaySummary(summary);

      return summary;

    } catch (error) {
      this.spinner?.fail('Configuration failed');
      Logger.error('Configuration engine failed', { error: (error as Error).toString() });
      throw error;
    }
  }

  private determineMergeStrategy(options: ConfigurationOptions): MergeStrategy {
    if (options.forceOverwrite) {
      return MergeStrategy.FORCE_OVERWRITE;
    }
    if (options.merge && options.mergeOverwrite) {
      return MergeStrategy.MERGE_OVERWRITE;
    }
    if (options.merge) {
      return MergeStrategy.MERGE;
    }
    if (options.skipExisting) {
      return MergeStrategy.SKIP;
    }
    // Default to skip existing for safety
    return MergeStrategy.SKIP;
  }

  private async discoverRepositories(repoConfig: any): Promise<Repository[]> {
    if (repoConfig.repositories) {
      return await GitHubCLI.getRepositoriesFromList(repoConfig.repositories);
    } else if (repoConfig.all_accessible_repos) {
      return await GitHubCLI.listUserRepositories(repoConfig.filters);
    } else {
      throw new Error('Invalid repository configuration');
    }
  }

  private async displayDryRunPreview(
    repositories: Repository[],
    mcpConfig: MCPConfig,
    secretsConfig: SecretsConfig | undefined,
    mergeStrategy: MergeStrategy
  ): Promise<void> {
    console.log(chalk.cyan('📋 Configuration Preview\n'));
    
    console.log(chalk.white(`Repositories to configure (${repositories.length}):`));
    repositories.forEach(repo => {
      console.log(`  • ${repo.fullName}`);
    });

    console.log(chalk.white('\nMCP servers to configure:'));
    Object.entries(mcpConfig.mcpServers).forEach(([name, config]) => {
      console.log(`  • ${name} (type: ${config.type})`);
    });

    if (secretsConfig?.secrets) {
      console.log(chalk.white('\nSecrets to configure:'));
      Object.keys(secretsConfig.secrets).forEach(name => {
        console.log(`  • ${name}`);
      });
    }

    if (secretsConfig?.variables) {
      console.log(chalk.white('\nVariables to configure:'));
      Object.entries(secretsConfig.variables).forEach(([name, value]) => {
        console.log(`  • ${name}: ${value}`);
      });
    }

    console.log(chalk.white(`\nMerge strategy: ${mergeStrategy}`));
    console.log(chalk.yellow('\nRun without --dry-run to apply these changes.'));
  }

  private async processRepositories(
    repositories: Repository[],
    mcpConfig: MCPConfig,
    secretsConfig: SecretsConfig | undefined,
    mergeStrategy: MergeStrategy,
    concurrency: number,
    apiOnly: boolean,
    interactiveAuth: boolean
  ): Promise<OperationResult[]> {
    const results: OperationResult[] = [];
    const total = repositories.length;
    let processed = 0;

    this.spinner.text = `Processing repositories (0/${total})...`;

    // Process repositories in batches based on concurrency setting
    for (let i = 0; i < repositories.length; i += concurrency) {
      const batch = repositories.slice(i, i + concurrency);
      const batchPromises = batch.map(repo => ({ repo, promise: this.processRepository(repo, mcpConfig, secretsConfig, mergeStrategy, apiOnly, interactiveAuth) }));
      
      const batchResults = await Promise.allSettled(batchPromises.map(item => item.promise));
      
      for (let j = 0; j < batchResults.length; j++) {
        const result = batchResults[j];
        const repo = batch[j];
        processed++;
        this.spinner.text = `Processing repositories (${processed}/${total})...`;
        
        if (result.status === 'fulfilled') {
          results.push(result.value);
        } else {
          Logger.error(`Repository processing failed for ${repo.fullName}: ${result.reason}`);
          results.push({
            repository: repo.fullName, // Use the actual repository name
            success: false,
            changes: {},
            error: result.reason.toString(),
            duration: 0
          });
        }
      }
    }

    this.spinner.succeed(`Processed ${processed} repositories`);
    return results;
  }

  private async processRepository(
    repository: Repository,
    mcpConfig: MCPConfig,
    secretsConfig: SecretsConfig | undefined,
    mergeStrategy: MergeStrategy,
    apiOnly: boolean,
    interactiveAuth: boolean
  ): Promise<OperationResult> {
    const startTime = Date.now();
    const result: OperationResult = {
      repository: repository.fullName,
      success: false,
      changes: {},
      duration: 0
    };

    try {
      Logger.info(`Processing repository: ${repository.fullName}`);

      // Configure MCP settings - try API first, fallback to browser automation
      let mcpResult;
      try {
        Logger.info(`Attempting API-based MCP configuration for ${repository.fullName}`);
        
        // Try to read existing config via API
        const existingConfig = await this.apiAutomator.readMCPConfig(repository.fullName);
        
        // Apply merge strategy
        const finalConfig = this.apiAutomator.mergeMCPConfig(existingConfig, mcpConfig, mergeStrategy);
        
        // Skip update if configuration would be identical
        if (existingConfig && JSON.stringify(existingConfig) === JSON.stringify(finalConfig)) {
          Logger.info(`No changes needed for ${repository.fullName} (API)`);
          mcpResult = {
            before: existingConfig,
            after: finalConfig,
            strategy: mergeStrategy
          };
        } else {
          // Try to update via API
          await this.apiAutomator.updateMCPConfig(repository.fullName, finalConfig);
          mcpResult = {
            before: existingConfig,
            after: finalConfig,
            strategy: mergeStrategy
          };
          Logger.info(`Successfully configured MCP via API for ${repository.fullName}`);
        }
      } catch (apiError) {
        Logger.warn(`API configuration failed for ${repository.fullName}: ${apiError}`);
        
        if (apiOnly) {
          throw new Error(`API-only mode enabled but API configuration failed: ${apiError}`);
        }
        
        Logger.info(`Falling back to browser automation for ${repository.fullName}`);
        
        // Ensure browser automation is initialized and authenticated for fallback
        // This handles edge cases where initial authentication may have failed or expired
        if (!this.browserAutomator.authenticationStatus) {
          if (interactiveAuth) {
            console.log(chalk.yellow(`\n🔄 Repository ${repository.fullName} requires interactive authentication`));
            
            // Re-initialize browser automation with interactive auth
            await this.browserAutomator.cleanup();
            this.browserAutomator = new BrowserAutomator(false, true); // Not debug mode, but interactive auth
            await this.browserAutomator.initialize();
            await this.browserAutomator.authenticateWithGitHub();
          } else {
            throw new Error(`Browser authentication required but not available for ${repository.fullName}`);
          }
        }
        
        // Fallback to browser automation
        mcpResult = await this.browserAutomator.configureRepository(
          repository.fullName,
          mcpConfig,
          mergeStrategy
        );
      }
      
      result.changes.mcpConfig = mcpResult;

      // Configure secrets and variables if provided
      if (secretsConfig) {
        if (secretsConfig.secrets) {
          const secretsAdded: string[] = [];
          for (const [name, value] of Object.entries(secretsConfig.secrets)) {
            await GitHubCLI.setRepositorySecret(repository.fullName, name, value);
            secretsAdded.push(name);
          }
          result.changes.secrets = { added: secretsAdded, updated: [] };
        }

        if (secretsConfig.variables) {
          const variablesAdded: string[] = [];
          for (const [name, value] of Object.entries(secretsConfig.variables)) {
            await GitHubCLI.setRepositoryVariable(repository.fullName, name, value);
            variablesAdded.push(name);
          }
          result.changes.variables = { added: variablesAdded, updated: [] };
        }
      }

      result.success = true;
      Logger.info(`Successfully configured repository: ${repository.fullName}`);

    } catch (error) {
      result.error = (error as Error).toString();
      Logger.error(`Failed to configure repository ${repository.fullName}: ${error}`);
    }

    result.duration = Date.now() - startTime;
    return result;
  }

  private createSummary(results: OperationResult[], startTime: number): OperationSummary {
    const successful = results.filter(r => r.success).length;
    const failed = results.filter(r => !r.success).length;
    
    return {
      totalRepositories: results.length,
      successful,
      failed,
      skipped: 0, // We don't track skipped separately in this implementation
      errors: results.filter(r => !r.success).map(r => ({
        repository: r.repository,
        error: r.error || 'Unknown error',
        type: 'config' as const
      })),
      duration: Date.now() - startTime,
      timestamp: new Date().toISOString()
    };
  }

  private displaySummary(summary: OperationSummary): void {
    console.log(chalk.cyan('\n📊 Operation Summary\n'));
    
    console.log(`Total repositories: ${summary.totalRepositories}`);
    console.log(chalk.green(`✅ Successful: ${summary.successful}`));
    console.log(chalk.red(`❌ Failed: ${summary.failed}`));
    console.log(`⏱️  Duration: ${Math.round(summary.duration / 1000)}s`);

    if (summary.errors.length > 0) {
      console.log(chalk.red('\n❌ Errors:'));
      summary.errors.forEach(error => {
        console.log(`  • ${error.repository}: ${error.error}`);
      });
    }

    Logger.info('Operation completed', summary);
  }
}