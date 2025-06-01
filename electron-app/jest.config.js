module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  moduleNameMapper: {
    // To handle __mocks__ for electron-store correctly if it was a JS mock
    // You might need to adjust this based on your specific mocking strategy
    '^electron-store$': '<rootDir>/__tests__/__mocks__/electron-store.js',
  },
  // Optional: if you have global setup/teardown for tests
  // globalSetup: './jest.global-setup.js',
  // globalTeardown: './jest.global-teardown.js',
  // Collect coverage from .ts files in specific directories
  collectCoverageFrom: ['main.ts', 'utils.ts', 'preload-settings.ts', 'renderer/settings.ts'],
  // Add a transform for .html files if settings.spec.ts needs to import HTML
  // For JSDOM tests, this might not be needed if HTML is read via fs
  transform: {
    '^.+\\.ts?$': 'ts-jest',
    // If you were testing React components with .tsx:
    // '^.+\\.tsx?$': 'ts-jest',
  },
  // Test files are .spec.ts or .test.ts
  testRegex: '(/__tests__/.*|(\\.|/)(test|spec))\\.[jt]s?$',
  moduleFileExtensions: ['ts', 'js', 'json', 'node'],
  testPathIgnorePatterns: [
    '/node_modules/',
    '/e2e/',
    '/__tests__/__mocks__/', // Ignore top-level mocks directory
    '/dist_ts/__tests__/__mocks__/', // Ignore compiled mocks in dist_ts
  ],
  // Automatically clear mock calls, instances and results before every test
  clearMocks: true,
};
