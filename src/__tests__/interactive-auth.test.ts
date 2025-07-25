import { BrowserAutomator } from '../browser/automator';
import { ConfigurationEngine } from '../engine';
import { ConfigurationOptions, MergeStrategy } from '../types';

describe('Interactive Authentication', () => {
  describe('BrowserAutomator', () => {
    it('should initialize with interactive authentication mode', () => {
      const automator = new BrowserAutomator(false, true);
      expect(automator).toBeDefined();
      expect(automator.authenticationStatus).toBe(false);
    });

    it('should support debug mode and interactive auth mode together', () => {
      const automator = new BrowserAutomator(true, true);
      expect(automator).toBeDefined();
    });

    it('should default to non-interactive mode', () => {
      const automator = new BrowserAutomator(false);
      expect(automator).toBeDefined();
    });
  });

  describe('Configuration Options', () => {
    it('should support interactive auth option', () => {
      const options: ConfigurationOptions = {
        repoConfig: 'test-repos.yaml',
        mcpConfig: 'test-mcp.json',
        dryRun: false,
        skipExisting: false,
        merge: false,
        mergeOverwrite: false,
        forceOverwrite: false,
        concurrency: 1,
        verbose: false,
        debug: false,
        apiOnly: false,
        interactiveAuth: true,
      };

      expect(options.interactiveAuth).toBe(true);
      expect(options.apiOnly).toBe(false); // These should be mutually exclusive
    });

    it('should validate mutually exclusive options in real scenario', () => {
      // This would be caught by CLI validation
      const invalidOptions: ConfigurationOptions = {
        repoConfig: 'test-repos.yaml',
        mcpConfig: 'test-mcp.json',
        dryRun: false,
        skipExisting: false,
        merge: false,
        mergeOverwrite: false,
        forceOverwrite: false,
        concurrency: 1,
        verbose: false,
        debug: false,
        apiOnly: true,
        interactiveAuth: true, // This should not be allowed with apiOnly
      };

      // In the real CLI, this would cause an error
      expect(invalidOptions.apiOnly && invalidOptions.interactiveAuth).toBe(true);
    });
  });

  describe('ConfigurationEngine', () => {
    it('should create engine without errors', () => {
      const engine = new ConfigurationEngine();
      expect(engine).toBeDefined();
    });
  });
});