"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const electron_1 = require("electron");
const path_1 = __importDefault(require("path"));
const fs_1 = __importDefault(require("fs"));
const keytar_1 = __importDefault(require("keytar"));
const store_1 = require("./src/store");
const windows_1 = require("./src/windows");
const api_1 = require("./src/api");
const notifications_1 = require("./src/notifications");
const auth_1 = require("./src/auth");
const tray_1 = require("./src/tray");
let refreshIntervalId = null;
function createWindow() {
    console.log('Application starting...');
}
electron_1.app.on('ready', async () => {
    createWindow();
    const iconPath = path_1.default.join(__dirname, '../assets/menubar.png');
    try {
        const tray = new electron_1.Tray(iconPath);
        (0, tray_1.setTray)(tray);
    }
    catch (e) {
        console.error('Failed to create Tray. Is the icon missing or path incorrect?', iconPath, e);
    }
    await (0, tray_1.updateTray)();
    const token = await keytar_1.default.getPassword('VibeMeter', 'WorkosCursorSessionToken');
    if (token) {
        (0, api_1.fetchData)();
    }
    else {
        (0, tray_1.updateTray)();
    }
    let refreshIntervalMinutes = store_1.store.get('refreshIntervalMinutes', 5);
    refreshIntervalId = setInterval(api_1.fetchData, refreshIntervalMinutes * 60 * 1000);
    if (store_1.store.get('launchAtLoginEnabled')) {
        electron_1.app.setLoginItemSettings({ openAtLogin: true });
    }
    else {
        electron_1.app.setLoginItemSettings({ openAtLogin: false });
        store_1.store.set('launchAtLoginEnabled', false);
    }
});
electron_1.app.on('window-all-closed', () => {
    // Standard macOS behavior, tray app should not quit.
});
electron_1.app.on('activate', () => {
    // Optional: re-create a window or show settings if no windows are open and dock icon is clicked.
});
electron_1.ipcMain.on('save-settings', (event, settings) => {
    console.log('Received settings to save:', settings);
    store_1.store.set('selectedCurrencyCode', settings.selectedCurrencyCode);
    store_1.store.set('warningLimitUSD', parseFloat(String(settings.warningLimitUSD)) || 0);
    store_1.store.set('upperLimitUSD', parseFloat(String(settings.upperLimitUSD)) || 0);
    const oldInterval = store_1.store.get('refreshIntervalMinutes', 5);
    const newInterval = parseInt(String(settings.refreshIntervalMinutes), 10) || 5;
    store_1.store.set('refreshIntervalMinutes', newInterval);
    if (refreshIntervalId && oldInterval !== newInterval) {
        console.log(`Refresh interval changed from ${oldInterval} to ${newInterval} minutes. Restarting timer.`);
        clearInterval(refreshIntervalId);
        refreshIntervalId = setInterval(api_1.fetchData, newInterval * 60 * 1000);
    }
    (0, api_1.fetchExchangeRatesIfNeeded)().then(() => {
        (0, tray_1.updateTray)();
        (0, notifications_1.checkLimitsAndNotify)();
    });
    if (windows_1.settingsWindow) {
        setTimeout(() => {
            if (windows_1.settingsWindow && !windows_1.settingsWindow.isDestroyed()) {
                windows_1.settingsWindow.close();
            }
        }, 3500);
    }
});
electron_1.ipcMain.handle('get-settings', async () => {
    return {
        selectedCurrencyCode: store_1.store.get('selectedCurrencyCode', 'USD'),
        warningLimitUSD: store_1.store.get('warningLimitUSD', 0),
        upperLimitUSD: store_1.store.get('upperLimitUSD', 0),
        refreshIntervalMinutes: store_1.store.get('refreshIntervalMinutes', 5),
    };
});
electron_1.app.on('will-quit', () => {
    if (refreshIntervalId) {
        clearInterval(refreshIntervalId);
    }
});
const rendererHtmlDir = path_1.default.join(__dirname, '../renderer');
if (!fs_1.default.existsSync(rendererHtmlDir)) {
    try {
        fs_1.default.mkdirSync(rendererHtmlDir, { recursive: true });
        console.log(`Created '${rendererHtmlDir}' directory.`);
    }
    catch (err) {
        console.error(`Error creating directory ${rendererHtmlDir}:`, err);
    }
}
// Helper function for E2E testing of launch at login
function setLaunchAtLoginForTest(enable) {
    store_1.store.set('launchAtLoginEnabled', enable);
    electron_1.app.setLoginItemSettings({
        openAtLogin: enable,
        openAsHidden: false, // Consistent with context menu behavior
    });
    console.log(`E2E: Set launchAtLoginEnabled to ${enable}`);
}
// Helper function for E2E testing of app quit
function quitAppForTest() {
    console.log('E2E: Quitting app...');
    electron_1.app.quit();
}
if (process.env.NODE_ENV === 'test') {
    const testExports = {
        checkLimitsAndNotify: notifications_1.checkLimitsAndNotify,
        logOut: auth_1.logOut,
        updateTray: tray_1.updateTray,
        fetchExchangeRatesIfNeeded: api_1.fetchExchangeRatesIfNeeded,
        buildContextMenu: tray_1.buildContextMenu,
        createLoginWindow: windows_1.createLoginWindow,
        fetchData: api_1.fetchData,
        createSettingsWindow: windows_1.createSettingsWindow,
        setLaunchAtLoginForTest,
        quitAppForTest, // Export the new function
    };
    module.exports = testExports;
}
//# sourceMappingURL=main.js.map