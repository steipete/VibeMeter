import { app, Tray, ipcMain, IpcMainInvokeEvent, Menu } from 'electron';
import path from 'path';
import fs from 'fs';
import keytar from 'keytar';
import { store } from './store';
import { RendererSettings } from './types';
import { createLoginWindow, createSettingsWindow, settingsWindow } from './windows';
import { fetchData, fetchExchangeRatesIfNeeded } from './api';
import { checkLimitsAndNotify } from './notifications';
import { logOut } from './auth';
import { setTray, updateTray, buildContextMenu } from './tray';

let refreshIntervalId: NodeJS.Timeout | null = null;

function createWindow(): void {
  console.log('Application starting...');
}

app.on('ready', async () => {
  createWindow();
  const iconPath = path.join(__dirname, '../../assets/menubar.png');
  try {
    const tray = new Tray(iconPath);
    setTray(tray);
  } catch (e: any) {
    console.error('Failed to create Tray. Is the icon missing or path incorrect?', iconPath, e);
  }

  await updateTray();

  const token = await keytar.getPassword('VibeMeter', 'WorkosCursorSessionToken');
  if (token) {
    fetchData();
  } else {
    updateTray();
  }

  let refreshIntervalMinutes = store.get('refreshIntervalMinutes', 5);
  refreshIntervalId = setInterval(fetchData, refreshIntervalMinutes * 60 * 1000);

  if (store.get('launchAtLoginEnabled')) {
    app.setLoginItemSettings({ openAtLogin: true });
  } else {
    app.setLoginItemSettings({ openAtLogin: false });
    store.set('launchAtLoginEnabled', false);
  }
});

app.on('window-all-closed', () => {
  // Standard macOS behavior, tray app should not quit.
});

app.on('activate', () => {
  // Optional: re-create a window or show settings if no windows are open and dock icon is clicked.
});

ipcMain.on('save-settings', (event: IpcMainInvokeEvent, settings: RendererSettings) => {
  console.log('Received settings to save:', settings);
  store.set('selectedCurrencyCode', settings.selectedCurrencyCode);
  store.set('warningLimitUSD', parseFloat(String(settings.warningLimitUSD)) || 0);
  store.set('upperLimitUSD', parseFloat(String(settings.upperLimitUSD)) || 0);

  const oldInterval = store.get('refreshIntervalMinutes', 5);
  const newInterval = parseInt(String(settings.refreshIntervalMinutes), 10) || 5;
  store.set('refreshIntervalMinutes', newInterval);

  if (refreshIntervalId && oldInterval !== newInterval) {
    console.log(
      `Refresh interval changed from ${oldInterval} to ${newInterval} minutes. Restarting timer.`
    );
    clearInterval(refreshIntervalId);
    refreshIntervalId = setInterval(fetchData, newInterval * 60 * 1000);
  }

  fetchExchangeRatesIfNeeded().then(() => {
    updateTray();
    checkLimitsAndNotify();
  });

  if (settingsWindow) {
    setTimeout(() => {
      if (settingsWindow && !settingsWindow.isDestroyed()) {
        settingsWindow.close();
      }
    }, 3500);
  }
});

ipcMain.handle('get-settings', async (): Promise<RendererSettings> => {
  return {
    selectedCurrencyCode: store.get('selectedCurrencyCode', 'USD'),
    warningLimitUSD: store.get('warningLimitUSD', 0),
    upperLimitUSD: store.get('upperLimitUSD', 0),
    refreshIntervalMinutes: store.get('refreshIntervalMinutes', 5),
  };
});

app.on('will-quit', () => {
  if (refreshIntervalId) {
    clearInterval(refreshIntervalId);
  }
});

const rendererHtmlDir = path.join(__dirname, '../../renderer');
if (!fs.existsSync(rendererHtmlDir)) {
  try {
    fs.mkdirSync(rendererHtmlDir, { recursive: true });
    console.log(`Created '${rendererHtmlDir}' directory.`);
  } catch (err) {
    console.error(`Error creating directory ${rendererHtmlDir}:`, err);
  }
}

export interface TestExports {
  checkLimitsAndNotify: () => void;
  logOut: () => Promise<void>;
  updateTray: () => Promise<void>;
  fetchExchangeRatesIfNeeded: () => Promise<void>;
  buildContextMenu: () => Promise<Menu>;
  createLoginWindow: () => void;
  fetchData: () => Promise<void>;
  createSettingsWindow: () => void;
}

if (process.env.NODE_ENV === 'test') {
  const testExports: TestExports = {
    checkLimitsAndNotify,
    logOut,
    updateTray,
    fetchExchangeRatesIfNeeded,
    buildContextMenu,
    createLoginWindow,
    fetchData,
    createSettingsWindow,
  };
  module.exports = testExports;
}