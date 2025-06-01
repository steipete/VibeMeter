const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './e2e',
  timeout: 30000,
  fullyParallel: false, // Electron apps typically shouldn't run in parallel
  workers: 1, // Single worker for Electron tests

  use: {
    // Electron-specific settings
    trace: 'on-first-retry',
    video: 'retain-on-failure',
  },

  projects: [
    {
      name: 'electron',
      testMatch: '**/*.spec.js',
    },
  ],

  reporter: [['html', { open: 'never' }], ['list']],
});
