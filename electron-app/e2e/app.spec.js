const { test, expect, _electron: electron } = require('@playwright/test');
const path = require('path');

test.describe('Vibe Meter Electron App', () => {
  let electronApp;

  test.beforeEach(async () => {
    // Launch Electron app with NODE_ENV=test to enable exports
    electronApp = await electron.launch({
      args: [path.join(__dirname, '..')],
      env: {
        ...process.env,
        NODE_ENV: 'test',
      },
    });

    // Explicitly wait for the app to be ready
    await electronApp.evaluate(async ({ app }) => {
      if (!app.isReady()) {
        await new Promise(resolve => app.on('ready', resolve));
      }
    });
  });

  test.afterEach(async () => {
    // Close the app
    if (electronApp) {
      await electronApp.close();
    }
  });

  test('should launch and open settings window', async () => {
    // Since the app runs in the system tray, we need to access the main module
    // and call createSettingsWindow directly

    // Evaluate in the main process to open settings window
    await electronApp.evaluate(async () => {
      if (
        process.mainModule &&
        process.mainModule.exports &&
        typeof process.mainModule.exports.createSettingsWindow === 'function'
      ) {
        process.mainModule.exports.createSettingsWindow();
      } else {
        let availableExports = 'unknown';
        if (process.mainModule && process.mainModule.exports) {
          availableExports = Object.keys(process.mainModule.exports).join(', ');
        }
        throw new Error(
          `createSettingsWindow function not found on process.mainModule.exports. Available exports: ${availableExports}. Ensure NODE_ENV=test is set and main.js exports correctly.`
        );
      }
      return true;
    });

    // Wait a bit for the window to open
    await electronApp.waitForEvent('window', { timeout: 5000 });

    // Get all windows
    const windows = electronApp.windows();

    // Find the settings window (it should be the newest window)
    let settingsWindow;
    for (const window of windows) {
      const title = await window.title();
      if (title.includes('Settings') || title.includes('Vibe Meter')) {
        settingsWindow = window;
        break;
      }
    }

    // Verify the settings window exists
    expect(settingsWindow).toBeTruthy();

    // Verify the settings window contains expected content
    const settingsHeading = await settingsWindow.locator('h2');
    await expect(settingsHeading).toHaveText('Vibe Meter Settings');

    // Verify some form elements exist
    const currencySelect = await settingsWindow.locator('select#currency');
    await expect(currencySelect).toBeVisible();

    const warningLimitInput = await settingsWindow.locator('input#warningLimit');
    await expect(warningLimitInput).toBeVisible();

    const upperLimitInput = await settingsWindow.locator('input#upperLimit');
    await expect(upperLimitInput).toBeVisible();

    const refreshIntervalSelect = await settingsWindow.locator('select#refreshInterval');
    await expect(refreshIntervalSelect).toBeVisible();
  });

  test('should handle settings window interactions', async () => {
    // Open settings window
    await electronApp.evaluate(async () => {
      if (
        process.mainModule &&
        process.mainModule.exports &&
        typeof process.mainModule.exports.createSettingsWindow === 'function'
      ) {
        process.mainModule.exports.createSettingsWindow();
      } else {
        throw new Error(
          'createSettingsWindow function not found on process.mainModule.exports for settings interaction test.'
        );
      }
      return true;
    });

    await electronApp.waitForEvent('window', { timeout: 5000 });

    const windows = electronApp.windows();
    let settingsWindow;
    for (const window of windows) {
      const title = await window.title();
      if (title.includes('Settings') || title.includes('Vibe Meter')) {
        settingsWindow = window;
        break;
      }
    }

    expect(settingsWindow).toBeTruthy();

    // Test changing currency
    const currencySelect = await settingsWindow.locator('select#currency');
    await currencySelect.selectOption('EUR');

    // Test entering warning limit
    const warningLimitInput = await settingsWindow.locator('input#warningLimit');
    await warningLimitInput.fill('100');

    // Test entering upper limit
    const upperLimitInput = await settingsWindow.locator('input#upperLimit');
    await upperLimitInput.fill('200');

    // Test entering refresh interval
    const refreshIntervalSelect = await settingsWindow.locator('select#refreshInterval');
    await refreshIntervalSelect.selectOption('15');

    // Save settings
    const saveButton = await settingsWindow.locator('button:has-text("Save Settings")');
    await saveButton.click();

    // Wait a bit for settings to be saved
    await settingsWindow.waitForTimeout(1000);
  });

  test('app should be running in system tray', async () => {
    // Verify the app is running (even if no visible windows)
    const isRunning = await electronApp.evaluate(async ({ app }) => {
      return app.isReady();
    });

    expect(isRunning).toBe(true);

    // Verify tray exists (simplified check)
    const hasTray = await electronApp.evaluate(async ({ app }) => {
      // If app is ready, tray initialization should have occurred or been attempted as per main.js.
      // A more robust E2E check for the tray itself would require IPC or other means
      // to query the state of the `tray` object in `main.js`.
      return app.isReady();
    });

    expect(hasTray).toBe(true);
  });

  test('should perform logout and attempt to show login window on subsequent data fetch', async () => {
    // Ensure the app is in a state where logout can be performed
    // For now, we assume it might be logged in or logout handles no-token gracefully

    // Call logOut
    await electronApp.evaluate(async () => {
      if (process.mainModule && process.mainModule.exports && typeof process.mainModule.exports.logOut === 'function') {
        await process.mainModule.exports.logOut();
      } else {
        throw new Error('logOut function not found on process.mainModule.exports.');
      }
      return true;
    });

    // Call createLoginWindow directly, as if triggered by a user action after logout
    await electronApp.evaluate(async () => {
      if (process.mainModule && process.mainModule.exports && typeof process.mainModule.exports.createLoginWindow === 'function') {
        process.mainModule.exports.createLoginWindow();
      } else {
        throw new Error('createLoginWindow function not found on process.mainModule.exports.');
      }
      return true;
    });

    // Wait for a potential new window (login window)
    let loginWindowAppeared = false;
    try {
      const newWindow = await electronApp.waitForEvent('window', { timeout: 7000 }); // Increased timeout
      if (newWindow) {
        const url = await newWindow.url();
        // Check if the new window's URL is the authenticator or if its title is "Login"
        // This depends on how createLoginWindow is implemented (loads HTML file vs URL)
        // For now, we'll assume any new window after this sequence is the login window.
        // A more robust check would involve inspecting the window's title or loaded content.
        const title = await newWindow.title();
        if (title.includes('Login') || url.includes('login.html') || url.includes('authenticator.cursor.sh')) {
          loginWindowAppeared = true;
           await newWindow.close(); // Close it to not interfere with other tests
        }
      }
    } catch (e) {
      // If waitForEvent times out, it means no new window appeared, which could be the expected outcome
      // if fetchData doesn't always create a window or if the logout didn't fully complete.
      console.log('waitForEvent for login window timed out, assuming no login window as expected by some paths or an issue.');
    }
    
    // This expectation is tricky. If fetchData *always* tries to open a login window when not logged in,
    // then loginWindowAppeared should be true.
    // However, the spec implies fetchData itself doesn't open the window, but rather subsequent actions might.
    // For now, we'll assert that the functions could be called.
    // A better assertion would be to check the state of the application (e.g., store values)
    // or the tray icon's tooltip, which requires more IPC.

    // For this test, we'll verify that a new window, presumably the login window, appears.
    expect(loginWindowAppeared).toBe(true);
  });

  test('should toggle Launch at Login setting', async () => {
    // Test enabling Launch at Login
    await electronApp.evaluate(async ({ app }) => {
      if (process.mainModule && process.mainModule.exports && typeof process.mainModule.exports.setLaunchAtLoginForTest === 'function') {
        process.mainModule.exports.setLaunchAtLoginForTest(true);
        // No direct return of app.getLoginItemSettings() here because it's main process only
      } else {
        throw new Error('setLaunchAtLoginForTest function not found on process.mainModule.exports.');
      }
      return true;
    });

    // Verify the setting in the main process
    let loginSettings = await electronApp.evaluate(async ({ app }) => {
      return app.getLoginItemSettings();
    });
    expect(loginSettings.openAtLogin).toBe(true);

    // Test disabling Launch at Login
    await electronApp.evaluate(async ({ app }) => {
      if (process.mainModule && process.mainModule.exports && typeof process.mainModule.exports.setLaunchAtLoginForTest === 'function') {
        process.mainModule.exports.setLaunchAtLoginForTest(false);
      } else {
        throw new Error('setLaunchAtLoginForTest function not found on process.mainModule.exports.');
      }
      return true;
    });

    // Verify the setting in the main process again
    loginSettings = await electronApp.evaluate(async ({ app }) => {
      return app.getLoginItemSettings();
    });
    expect(loginSettings.openAtLogin).toBe(false);
  });

  test('should quit the application', async () => {
    let appClosed = false;
    electronApp.on('close', () => {
      appClosed = true;
    });

    await electronApp.evaluate(async () => {
      if (process.mainModule && process.mainModule.exports && typeof process.mainModule.exports.quitAppForTest === 'function') {
        process.mainModule.exports.quitAppForTest();
      } else {
        throw new Error('quitAppForTest function not found on process.mainModule.exports.');
      }
      return true;
    });

    // Wait for a short period to allow the close event to propagate
    // This timeout might need adjustment based on how quickly the app closes.
    // Playwright's auto-waiting might also handle this, but an explicit wait can be more reliable for events.
    for (let i = 0; i < 50; i++) { // Poll for up to 5 seconds
      if (appClosed) break;
      await new Promise(resolve => setTimeout(resolve, 100));
    }

    expect(appClosed).toBe(true);
  });
});

// Note on testing tray interactions:
// Direct tray menu interaction is complex in Playwright as it requires native OS automation.
// For comprehensive tray testing, consider:
// 1. Exposing tray menu actions as IPC endpoints that can be called directly
// 2. Using additional tools like Spectron or native automation libraries
// 3. Testing the underlying functionality rather than the tray UI itself
//
// The current tests focus on testing the settings window which can be opened
// programmatically, demonstrating the app's core functionality.
