// Configuration interfaces and types
export interface RepoConfig {
  repositories?: string[];
  all_accessible_repos?: boolean;
  filters?: RepoFilters;
  options?: ProcessingOptions;
}

export interface RepoFilters {
  owner_only?: boolean;
  topics?: string[];
  exclude?: string[];
  patterns?: string[];
}

export interface ProcessingOptions {
  skip_existing?: boolean;
  concurrency?: number;
  verbose?: boolean;
}

export interface MCPConfig {
  mcpServers: {
    [serverName: string]: MCPServerConfig;
  };
}

export interface MCPServerConfig {
  type: 'http' | 'local';
  // HTTP server configuration
  url?: string;
  headers?: Record<string, string>;
  // Local server configuration  
  command?: string;
  args?: string[];
  env?: Record<string, string>;
  // Common properties
  tools: string[];
}

export interface SecretsConfig {
  secrets?: Record<string, string>;
  variables?: Record<string, string>;
}

export interface Repository {
  name: string;
  owner: string;
  fullName: string;
  hasAdminAccess: boolean;
  topics: string[];
}

export interface ConfigurationOptions {
  repoConfig: string;
  mcpConfig: string;
  secretsConfig?: string;
  dryRun: boolean;
  skipExisting: boolean;
  merge: boolean;
  mergeOverwrite: boolean;
  forceOverwrite: boolean;
  concurrency: number;
  verbose: boolean;
  debug: boolean;
  apiOnly: boolean;
  resume?: boolean;
  retryFailed?: boolean;
}

export interface OperationResult {
  repository: string;
  success: boolean;
  changes: {
    mcpConfig?: {
      before: MCPConfig | null;
      after: MCPConfig;
      strategy: string;
    };
    secrets?: {
      added: string[];
      updated: string[];
    };
    variables?: {
      added: string[];
      updated: string[];
    };
  };
  error?: string;
  duration: number;
}

export interface OperationSummary {
  totalRepositories: number;
  successful: number;
  failed: number;
  skipped: number;
  errors: RepositoryError[];
  duration: number;
  timestamp: string;
}

export interface RepositoryError {
  repository: string;
  error: string;
  type: 'permission' | 'config' | 'network' | 'fatal';
}

export enum MergeStrategy {
  SKIP = 'skip',
  MERGE = 'merge',
  MERGE_OVERWRITE = 'merge-overwrite',
  FORCE_OVERWRITE = 'force-overwrite'
}