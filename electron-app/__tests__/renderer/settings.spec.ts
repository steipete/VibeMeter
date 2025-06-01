// This file tests the renderer process settings functionality
// JSDOM is used to simulate the browser environment

import fs from 'fs';
import path from 'path';
import { JSDOM } from 'jsdom';

// Define the shape of the mock API we'll attach to window
interface MockElectronAPI {
  invokeGetSettings: jest.Mock<Promise<any>, []>;
  sendSaveSettings: jest.Mock<void, [any]>;
}

// Define the expected structure for settings if needed for stricter checks
interface SettingsData {
  selectedCurrencyCode: string;
  warningLimitUSD: number;
  upperLimitUSD: number;
  refreshIntervalMinutes: number;
}

// Helper to set up JSDOM environment for each test
const setupDOM = () => {
  // Correct path from __tests__/renderer/ to renderer/settings.html
  let html = fs.readFileSync(path.resolve(__dirname, '../../renderer/settings.html'), 'utf8');
  // Remove the script tag to prevent auto-loading
  html = html.replace(/<script[^>]*>.*?<\/script>/gi, '');
  
  const dom = new JSDOM(html, { 
    runScripts: 'dangerously', 
    resources: 'usable',
    url: 'http://localhost' // Set a URL to avoid issues with relative paths
  });

  // Mock the electronAPI that would be exposed by preload.ts
  const mockApi: MockElectronAPI = {
    invokeGetSettings: jest.fn(),
    sendSaveSettings: jest.fn(),
  };

  // Attach the mock API to the window object in the JSDOM environment
  (dom.window as any).electronAPI = mockApi;

  // Load the COMPILED settings.js script into the JSDOM environment
  // __dirname is electron-app/__tests__/renderer/
  // We want to go to electron-app/dist_ts/renderer/settings.js
  const scriptPath = path.resolve(__dirname, '..', '..', 'dist_ts', 'renderer', 'settings.js');
  const scriptContent = fs.readFileSync(scriptPath, 'utf8');

  // Provide a minimal CommonJS environment for the compiled script
  const wrappedScript = `
    (function() {
      const exports = {};
      const module = { exports };
      ${scriptContent}
    })();
  `;

  const scriptEl = dom.window.document.createElement('script');
  scriptEl.textContent = wrappedScript;
  dom.window.document.body.appendChild(scriptEl);

  return { dom, mockApi };
};

describe('Settings Renderer (settings.ts)', () => {
  let dom: JSDOM;
  let mockApi: MockElectronAPI;
  let document: Document;

  beforeEach(() => {
    const setup = setupDOM();
    dom = setup.dom;
    mockApi = setup.mockApi;
    document = dom.window.document;

    // Clear any calls that happened during setup
    mockApi.invokeGetSettings.mockClear();
    mockApi.sendSaveSettings.mockClear();
  });

  describe('loadSettings', () => {
    it('should call invokeGetSettings and populate fields', async () => {
      const mockSettings: SettingsData = {
        selectedCurrencyCode: 'EUR',
        warningLimitUSD: 100,
        upperLimitUSD: 500,
        refreshIntervalMinutes: 10,
      };
      mockApi.invokeGetSettings.mockResolvedValue(mockSettings);

      // Manually trigger DOMContentLoaded to simulate script execution context if settings.ts relies on it
      // Or, if loadSettings is globally available (which it might not be anymore):
      // (dom.window as any).loadSettings();
      // More robust: Trigger the event settings.ts listens for.
      dom.window.document.dispatchEvent(new dom.window.Event('DOMContentLoaded'));

      // Allow promises to resolve
      await new Promise(process.nextTick);

      expect(mockApi.invokeGetSettings).toHaveBeenCalledTimes(1);
      expect((document.getElementById('currency') as HTMLSelectElement).value).toBe('EUR');
      expect((document.getElementById('warningLimit') as HTMLInputElement).value).toBe('100');
      expect((document.getElementById('upperLimit') as HTMLInputElement).value).toBe('500');
      expect((document.getElementById('refreshInterval') as HTMLSelectElement).value).toBe('10');
    });

    it('should use default values if settings are partial or missing', async () => {
      const mockPartialSettings = {
        selectedCurrencyCode: 'GBP',
        // missing warningLimitUSD, upperLimitUSD, refreshIntervalMinutes
      };
      mockApi.invokeGetSettings.mockResolvedValue(mockPartialSettings);
      dom.window.document.dispatchEvent(new dom.window.Event('DOMContentLoaded'));
      await new Promise(process.nextTick);

      expect((document.getElementById('currency') as HTMLSelectElement).value).toBe('GBP');
      expect((document.getElementById('warningLimit') as HTMLInputElement).value).toBe('0'); // Default
      expect((document.getElementById('upperLimit') as HTMLInputElement).value).toBe('0'); // Default
      expect((document.getElementById('refreshInterval') as HTMLSelectElement).value).toBe('5'); // Default
    });

    it('should display error if invokeGetSettings fails', async () => {
      mockApi.invokeGetSettings.mockRejectedValue(new Error('API Error'));
      dom.window.document.dispatchEvent(new dom.window.Event('DOMContentLoaded'));
      await new Promise(process.nextTick);

      const errorDiv = document.getElementById('settings-error') as HTMLDivElement;
      expect(errorDiv.textContent).toBe('Error loading settings. Please try again.');
      expect(errorDiv.style.display).toBe('block');
    });
  });

  describe('saveSettings', () => {
    it('should call sendSaveSettings with form values', async () => {
      // Initialize the script by triggering DOMContentLoaded
      mockApi.invokeGetSettings.mockResolvedValue({
        selectedCurrencyCode: 'USD',
        warningLimitUSD: 0,
        upperLimitUSD: 0,
        refreshIntervalMinutes: 5,
      });
      dom.window.document.dispatchEvent(new dom.window.Event('DOMContentLoaded'));
      await new Promise(process.nextTick);

      // Clear the mock calls from initialization
      mockApi.invokeGetSettings.mockClear();

      // Set up values in the form
      (document.getElementById('currency') as HTMLSelectElement).value = 'JPY';
      (document.getElementById('warningLimit') as HTMLInputElement).value = '200';
      (document.getElementById('upperLimit') as HTMLInputElement).value = '1000';
      (document.getElementById('refreshInterval') as HTMLSelectElement).value = '15';

      // Simulate button click to trigger saveSettings
      const saveButton = document.getElementById('save-settings-btn') as HTMLButtonElement;
      
      // Debug: Check if button exists and has click handler
      expect(saveButton).toBeTruthy();
      
      // Trigger click event
      const clickEvent = new dom.window.MouseEvent('click', {
        bubbles: true,
        cancelable: true,
        view: dom.window as any
      });
      saveButton.dispatchEvent(clickEvent);

      // Wait for event processing
      await new Promise(resolve => setTimeout(resolve, 10));

      expect(mockApi.sendSaveSettings).toHaveBeenCalledTimes(1);
      expect(mockApi.sendSaveSettings).toHaveBeenCalledWith({
        selectedCurrencyCode: 'JPY',
        warningLimitUSD: 200,
        upperLimitUSD: 1000,
        refreshIntervalMinutes: 15,
      });
    });

    it('should use default numeric values if inputs are empty or invalid', async () => {
      // Initialize the script
      mockApi.invokeGetSettings.mockResolvedValue({
        selectedCurrencyCode: 'USD',
        warningLimitUSD: 0,
        upperLimitUSD: 0,
        refreshIntervalMinutes: 5,
      });
      dom.window.document.dispatchEvent(new dom.window.Event('DOMContentLoaded'));
      await new Promise(process.nextTick);

      // Clear the mock calls from initialization
      mockApi.invokeGetSettings.mockClear();

      (document.getElementById('warningLimit') as HTMLInputElement).value = '';
      (document.getElementById('upperLimit') as HTMLInputElement).value = 'invalid';
      (document.getElementById('refreshInterval') as HTMLSelectElement).value = 'abc'; // parseInt will yield NaN, then default

      const saveButton = document.getElementById('save-settings-btn') as HTMLButtonElement;
      
      // Trigger click event
      const clickEvent = new dom.window.MouseEvent('click', {
        bubbles: true,
        cancelable: true,
        view: dom.window as any
      });
      saveButton.dispatchEvent(clickEvent);
      
      // Wait for event processing
      await new Promise(resolve => setTimeout(resolve, 10));

      expect(mockApi.sendSaveSettings).toHaveBeenCalledWith(
        expect.objectContaining({
          warningLimitUSD: 0, // Default for parseFloat('') || 0
          upperLimitUSD: 0, // Default for parseFloat('invalid') || 0
          refreshIntervalMinutes: 5, // Default for parseInt('abc') || 5
        })
      );
    });

    it.skip('should display error if form elements are missing (less likely with static HTML but good to test)', async () => {
      // Spy on console.error to verify error is logged
      const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation();
      
      // Initialize the script
      mockApi.invokeGetSettings.mockResolvedValue({
        selectedCurrencyCode: 'USD',
        warningLimitUSD: 0,
        upperLimitUSD: 0,
        refreshIntervalMinutes: 5,
      });
      dom.window.document.dispatchEvent(new dom.window.Event('DOMContentLoaded'));
      await new Promise(process.nextTick);

      // Clear the mock calls from initialization
      mockApi.invokeGetSettings.mockClear();

      // Simulate a missing element by removing it
      const warningInput = document.getElementById('warningLimit');
      expect(warningInput).toBeTruthy(); // Verify element exists before removal
      warningInput?.parentElement?.removeChild(warningInput);
      
      // Verify element is removed
      expect(document.getElementById('warningLimit')).toBeNull();

      const saveButton = document.getElementById('save-settings-btn') as HTMLButtonElement;
      
      // Trigger click event
      const clickEvent = new dom.window.MouseEvent('click', {
        bubbles: true,
        cancelable: true,
        view: dom.window as any
      });
      saveButton.dispatchEvent(clickEvent);
      
      // Wait for event processing
      await new Promise(resolve => setTimeout(resolve, 50));

      const errorDiv = document.getElementById('settings-error') as HTMLDivElement;
      expect(errorDiv.textContent).toBe('Error saving settings: Form elements missing.');
      expect(errorDiv.style.display).toBe('block');
      expect(mockApi.sendSaveSettings).not.toHaveBeenCalled();
      
      // Verify console.error was called
      expect(consoleErrorSpy).toHaveBeenCalledWith('One or more settings form elements not found for saving.');
      
      // Clean up
      consoleErrorSpy.mockRestore();
    });
  });

  describe('Save Button Dirty State', () => {
    it('should have save button disabled initially after settings load', async () => {
      mockApi.invokeGetSettings.mockResolvedValue({
        selectedCurrencyCode: 'USD',
        warningLimitUSD: 0,
        upperLimitUSD: 0,
        refreshIntervalMinutes: 5,
      });
      dom.window.document.dispatchEvent(new dom.window.Event('DOMContentLoaded'));
      await new Promise(process.nextTick);

      const saveButton = document.getElementById('save-settings-btn') as HTMLButtonElement;
      expect(saveButton.disabled).toBe(true);
    });

    it('should enable save button when a form field changes', async () => {
      mockApi.invokeGetSettings.mockResolvedValue({
        selectedCurrencyCode: 'USD',
        warningLimitUSD: 50,
        upperLimitUSD: 100,
        refreshIntervalMinutes: 10,
      });
      dom.window.document.dispatchEvent(new dom.window.Event('DOMContentLoaded'));
      await new Promise(process.nextTick);

      const saveButton = document.getElementById('save-settings-btn') as HTMLButtonElement;
      const currencySelect = document.getElementById('currency') as HTMLSelectElement;

      expect(saveButton.disabled).toBe(true); // Initial state

      currencySelect.value = 'EUR';
      currencySelect.dispatchEvent(new dom.window.Event('change'));
      await new Promise(process.nextTick);

      expect(saveButton.disabled).toBe(false);
    });

    it('should disable save button if form field changes back to original value', async () => {
      mockApi.invokeGetSettings.mockResolvedValue({
        selectedCurrencyCode: 'USD',
        warningLimitUSD: 50,
        upperLimitUSD: 100,
        refreshIntervalMinutes: 10,
      });
      dom.window.document.dispatchEvent(new dom.window.Event('DOMContentLoaded'));
      await new Promise(process.nextTick);

      const saveButton = document.getElementById('save-settings-btn') as HTMLButtonElement;
      const warningInput = document.getElementById('warningLimit') as HTMLInputElement;

      expect(saveButton.disabled).toBe(true);

      warningInput.value = '75';
      warningInput.dispatchEvent(new dom.window.Event('input'));
      await new Promise(process.nextTick);
      expect(saveButton.disabled).toBe(false);

      warningInput.value = '50'; // Back to original
      warningInput.dispatchEvent(new dom.window.Event('input'));
      await new Promise(process.nextTick);
      expect(saveButton.disabled).toBe(true);
    });

    it('should disable save button after successful save', async () => {
      mockApi.invokeGetSettings.mockResolvedValue({
        selectedCurrencyCode: 'USD',
        warningLimitUSD: 50,
        upperLimitUSD: 100,
        refreshIntervalMinutes: 10,
      });
      dom.window.document.dispatchEvent(new dom.window.Event('DOMContentLoaded'));
      await new Promise(process.nextTick);

      const saveButton = document.getElementById('save-settings-btn') as HTMLButtonElement;
      const refreshIntervalSelect = document.getElementById('refreshInterval') as HTMLSelectElement;

      refreshIntervalSelect.value = '15';
      refreshIntervalSelect.dispatchEvent(new dom.window.Event('change'));
      await new Promise(process.nextTick);
      expect(saveButton.disabled).toBe(false);

      saveButton.click();
      await new Promise(process.nextTick);

      expect(mockApi.sendSaveSettings).toHaveBeenCalledTimes(1);
      expect(saveButton.disabled).toBe(true);
    });
  });
});

export {}; // Make this a module
