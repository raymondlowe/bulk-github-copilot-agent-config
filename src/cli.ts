#!/usr/bin/env node

import { Command } from 'commander';
import { ConfigurationEngine } from './engine';
import { ConfigurationOptions } from './types';
import { Logger } from './utils/logger';
import chalk from 'chalk';
import * as fs from 'fs-extra';

const program = new Command();

program
  .name('copilot-config')
  .description('Bulk configuration tool for GitHub Copilot agent MCP settings')
  .version('1.0.0');

program
  .command('configure')
  .description('Configure GitHub Copilot agents across repositories')
  .requiredOption('--repos <file>', 'Repository configuration file (repos.yaml)')
  .requiredOption('--mcp-config <file>', 'MCP configuration file (mcp-config.yaml)')
  .option('--secrets <file>', 'Optional secrets configuration file (secrets.yaml)')
  .option('--dry-run', 'Preview changes without applying them', false)
  .option('--skip-existing', 'Skip repositories with existing MCP configuration', false)
  .option('--merge', 'Merge new MCP servers with existing ones', false)
  .option('--overwrite-existing', 'When merging, overwrite existing servers with same names', false)
  .option('--force-overwrite', 'Replace entire MCP configuration', false)
  .option('--concurrency <number>', 'Number of repositories to process in parallel', '3')
  .option('--verbose', 'Enable verbose logging', false)
  .option('--resume', 'Resume from last failed repository', false)
  .option('--retry-failed', 'Retry only failed repositories from previous run', false)
  .action(async (options) => {
    try {
      // Validate required files exist
      if (!await fs.pathExists(options.repos)) {
        console.error(chalk.red(`❌ Repository config file not found: ${options.repos}`));
        process.exit(1);
      }

      if (!await fs.pathExists(options.mcpConfig)) {
        console.error(chalk.red(`❌ MCP config file not found: ${options.mcpConfig}`));
        process.exit(1);
      }

      if (options.secrets && !await fs.pathExists(options.secrets)) {
        console.error(chalk.red(`❌ Secrets config file not found: ${options.secrets}`));
        process.exit(1);
      }

      // Validate mutually exclusive options
      if (options.forceOverwrite && (options.merge || options.skipExisting)) {
        console.error(chalk.red('❌ --force-overwrite cannot be used with --merge or --skip-existing'));
        process.exit(1);
      }

      if (options.overwriteExisting && !options.merge) {
        console.error(chalk.red('❌ --overwrite-existing requires --merge'));
        process.exit(1);
      }

      // Parse concurrency
      const concurrency = parseInt(options.concurrency, 10);
      if (isNaN(concurrency) || concurrency < 1) {
        console.error(chalk.red('❌ Concurrency must be a positive number'));
        process.exit(1);
      }

      // Show banner
      console.log(chalk.cyan('🚀 GitHub Copilot Agent Bulk Configurator\n'));

      const configOptions: ConfigurationOptions = {
        repoConfig: options.repos,
        mcpConfig: options.mcpConfig,
        secretsConfig: options.secrets,
        dryRun: options.dryRun,
        skipExisting: options.skipExisting,
        merge: options.merge,
        mergeOverwrite: options.overwriteExisting,
        forceOverwrite: options.forceOverwrite,
        concurrency,
        verbose: options.verbose,
        resume: options.resume,
        retryFailed: options.retryFailed
      };

      const engine = new ConfigurationEngine();
      const summary = await engine.configure(configOptions);

      if (summary.failed > 0) {
        process.exit(1);
      }

    } catch (error) {
      console.error(chalk.red(`❌ Configuration failed: ${error}`));
      Logger.error('CLI command failed', { error: (error as Error).toString() });
      process.exit(1);
    }
  });

program
  .command('validate')
  .description('Validate configuration files without applying changes')
  .requiredOption('--repos <file>', 'Repository configuration file (repos.yaml)')
  .requiredOption('--mcp-config <file>', 'MCP configuration file (mcp-config.yaml)')
  .option('--secrets <file>', 'Optional secrets configuration file (secrets.yaml)')
  .action(async (options) => {
    try {
      const { ConfigParser } = await import('./config/parser');
      
      console.log(chalk.cyan('🔍 Validating configuration files...\n'));

      // Validate repository config
      console.log('Validating repository configuration...');
      const repoConfig = await ConfigParser.parseRepoConfig(options.repos);
      console.log(chalk.green('✅ Repository configuration is valid'));

      // Validate MCP config
      console.log('Validating MCP configuration...');
      const mcpConfig = await ConfigParser.parseMCPConfig(options.mcpConfig);
      console.log(chalk.green('✅ MCP configuration is valid'));
      console.log(`   Found ${Object.keys(mcpConfig).length} MCP servers`);

      // Validate secrets config if provided
      if (options.secrets) {
        console.log('Validating secrets configuration...');
        const secretsConfig = await ConfigParser.parseSecretsConfig(options.secrets);
        console.log(chalk.green('✅ Secrets configuration is valid'));
        
        const secretCount = secretsConfig.secrets ? Object.keys(secretsConfig.secrets).length : 0;
        const variableCount = secretsConfig.variables ? Object.keys(secretsConfig.variables).length : 0;
        console.log(`   Found ${secretCount} secrets and ${variableCount} variables`);
      }

      console.log(chalk.green('\n✅ All configuration files are valid!'));

    } catch (error) {
      console.error(chalk.red(`❌ Validation failed: ${error}`));
      process.exit(1);
    }
  });

program
  .command('check-auth')
  .description('Check GitHub CLI authentication status')
  .action(async () => {
    try {
      const { GitHubCLI } = await import('./github/cli');
      
      console.log(chalk.cyan('🔑 Checking GitHub authentication...\n'));
      
      // This will throw an error if not authenticated
      await GitHubCLI.listUserRepositories();
      
      console.log(chalk.green('✅ GitHub CLI is properly authenticated'));
      console.log('You can proceed with configuration operations.');
      
    } catch (error) {
      console.error(chalk.red(`❌ Authentication check failed: ${error}`));
      console.log(chalk.yellow('\nTo authenticate with GitHub CLI, run:'));
      console.log(chalk.cyan('gh auth login'));
      process.exit(1);
    }
  });

program
  .command('list-repos')
  .description('List repositories that would be configured')
  .requiredOption('--repos <file>', 'Repository configuration file (repos.yaml)')
  .action(async (options) => {
    try {
      const { ConfigParser } = await import('./config/parser');
      const { GitHubCLI } = await import('./github/cli');
      
      console.log(chalk.cyan('📋 Discovering repositories...\n'));

      const repoConfig = await ConfigParser.parseRepoConfig(options.repos);
      
      let repositories;
      if (repoConfig.repositories) {
        repositories = await GitHubCLI.getRepositoriesFromList(repoConfig.repositories);
      } else if (repoConfig.all_accessible_repos) {
        repositories = await GitHubCLI.listUserRepositories(repoConfig.filters);
      } else {
        throw new Error('Invalid repository configuration');
      }

      console.log(`Found ${repositories.length} repositories:\n`);
      
      repositories.forEach(repo => {
        console.log(`📁 ${repo.fullName}`);
        if (repo.topics.length > 0) {
          console.log(`   Topics: ${repo.topics.join(', ')}`);
        }
        console.log(`   Admin access: ${repo.hasAdminAccess ? '✅' : '❌'}`);
        console.log('');
      });

      const adminRepos = repositories.filter(r => r.hasAdminAccess);
      console.log(chalk.green(`✅ ${adminRepos.length} repositories have admin access and can be configured`));
      
      if (adminRepos.length < repositories.length) {
        const noAccessRepos = repositories.filter(r => !r.hasAdminAccess);
        console.log(chalk.yellow(`⚠️  ${noAccessRepos.length} repositories will be skipped (no admin access)`));
      }

    } catch (error) {
      console.error(chalk.red(`❌ Failed to list repositories: ${error}`));
      process.exit(1);
    }
  });

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  console.error(chalk.red('❌ Unhandled promise rejection:'), reason);
  Logger.error('Unhandled promise rejection', { reason, promise });
  process.exit(1);
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error(chalk.red('❌ Uncaught exception:'), error);
  Logger.error('Uncaught exception', { error: error.toString(), stack: error.stack });
  process.exit(1);
});

program.parse();