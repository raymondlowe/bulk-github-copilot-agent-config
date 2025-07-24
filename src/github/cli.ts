import { spawn, exec } from 'child_process';
import { promisify } from 'util';
import { Repository, RepoFilters } from '../types';
import { Logger } from '../utils/logger';

const execAsync = promisify(exec);

export class GitHubCLI {
  private static async checkAuthentication(): Promise<void> {
    try {
      const { stdout } = await execAsync('gh auth status');
      Logger.info('GitHub CLI authentication verified');
    } catch (error) {
      throw new Error('GitHub CLI not authenticated. Please run "gh auth login" first.');
    }
  }

  static async listUserRepositories(filters?: RepoFilters): Promise<Repository[]> {
    await this.checkAuthentication();
    
    try {
      let command = 'gh repo list --json name,owner,isPrivate,repositoryTopics,viewerCanAdminister';
      
      if (filters?.owner_only) {
        command += ' --source';
      }
      
      // Add limit to avoid too many repos at once
      command += ' --limit 1000';

      const { stdout } = await execAsync(command);
      const repos = JSON.parse(stdout);

      let filteredRepos = repos.map((repo: any) => ({
        name: repo.name,
        owner: repo.owner.login,
        fullName: `${repo.owner.login}/${repo.name}`,
        hasAdminAccess: repo.viewerCanAdminister,
        topics: repo.repositoryTopics?.map((t: any) => t.name) || []
      }));

      // Apply filters
      if (filters) {
        if (filters.topics && filters.topics.length > 0) {
          filteredRepos = filteredRepos.filter((repo: Repository) =>
            filters.topics!.some(topic => repo.topics.includes(topic))
          );
        }

        if (filters.exclude && filters.exclude.length > 0) {
          filteredRepos = filteredRepos.filter((repo: Repository) =>
            !filters.exclude!.includes(repo.fullName)
          );
        }

        if (filters.patterns && filters.patterns.length > 0) {
          filteredRepos = filteredRepos.filter((repo: Repository) =>
            filters.patterns!.some(pattern => {
              const regex = new RegExp(pattern.replace('*', '.*'));
              return regex.test(repo.fullName);
            })
          );
        }
      }

      // Filter to only repos with admin access
      filteredRepos = filteredRepos.filter((repo: Repository) => repo.hasAdminAccess);

      Logger.info(`Found ${filteredRepos.length} repositories with admin access`);
      return filteredRepos;
    } catch (error) {
      throw new Error(`Failed to list repositories: ${error}`);
    }
  }

  static async getRepositoriesFromList(repoList: string[]): Promise<Repository[]> {
    await this.checkAuthentication();
    
    const repositories: Repository[] = [];
    
    for (const repoName of repoList) {
      try {
        const { stdout } = await execAsync(
          `gh repo view ${repoName} --json name,owner,repositoryTopics,viewerCanAdminister`
        );
        const repo = JSON.parse(stdout);
        
        if (!repo.viewerCanAdminister) {
          Logger.warn(`Skipping ${repoName}: No admin access`);
          continue;
        }

        repositories.push({
          name: repo.name,
          owner: repo.owner.login,
          fullName: repoName,
          hasAdminAccess: repo.viewerCanAdminister,
          topics: repo.repositoryTopics?.map((t: any) => t.name) || []
        });
      } catch (error) {
        Logger.error(`Failed to get info for repository ${repoName}: ${error}`);
      }
    }

    return repositories;
  }

  static async setRepositorySecret(repoName: string, secretName: string, secretValue: string): Promise<void> {
    await this.checkAuthentication();
    
    try {
      await execAsync(`gh secret set ${secretName} --repo ${repoName} --body "${secretValue}"`);
      Logger.info(`Set secret ${secretName} for repository ${repoName}`);
    } catch (error) {
      throw new Error(`Failed to set secret ${secretName} for ${repoName}: ${error}`);
    }
  }

  static async setRepositoryVariable(repoName: string, variableName: string, variableValue: string): Promise<void> {
    await this.checkAuthentication();
    
    try {
      await execAsync(`gh variable set ${variableName} --repo ${repoName} --body "${variableValue}"`);
      Logger.info(`Set variable ${variableName} for repository ${repoName}`);
    } catch (error) {
      throw new Error(`Failed to set variable ${variableName} for ${repoName}: ${error}`);
    }
  }

  static async checkRepositoryAccess(repoName: string): Promise<boolean> {
    try {
      const { stdout } = await execAsync(`gh repo view ${repoName} --json viewerCanAdminister`);
      const repo = JSON.parse(stdout);
      return repo.viewerCanAdminister;
    } catch (error) {
      return false;
    }
  }
}