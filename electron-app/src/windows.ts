import { BrowserWindow, Cookie, dialog } from 'electron';
import path from 'path';
import keytar from 'keytar';
import { store } from './store';
import { fetchData } from './api';
import { showLoginSuccessNotification } from './notifications';
import { RendererSettings } from './types';

export let loginWindow: BrowserWindow | null = null;
export let settingsWindow: BrowserWindow | null = null;

async function checkForSessionCookie(session: any, url?: string): Promise<void> {
  try {
    const cookies: Cookie[] = await session.cookies.get({
      domain: 'cursor.com',
      name: 'WorkosCursorSessionToken',
    });
    
    if (cookies.length > 0) {
      const token: string = cookies[0].value;
      console.log('WorkosCursorSessionToken found:', token.substring(0, 20) + '...');
      
      try {
        await keytar.setPassword('VibeMeter', 'WorkosCursorSessionToken', token);
        console.log('Token stored securely.');
        store.set('userEmail', 'Fetching...');
        
        if (loginWindow) {
          loginWindow.close();
        }
        
        // Call /me endpoint and billing endpoint
        await fetchData();
        showLoginSuccessNotification();
      } catch (keytarError) {
        console.error('Failed to store session token with keytar:', keytarError);
        dialog.showErrorBox(
          'Login Storage Failed',
          'Could not securely store your session credentials.'
        );
      }
    }
  } catch (cookieError) {
    console.error('Error accessing session token:', cookieError);
  }
}

export function createLoginWindow(): void {
  if (loginWindow) {
    loginWindow.focus();
    return;
  }
  loginWindow = new BrowserWindow({
    width: 800,
    height: 600,
    webPreferences: {
      webviewTag: true,
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
    },
  });

  loginWindow.loadFile(path.join(__dirname, '../../renderer/login.html'));

  loginWindow.on('closed', () => {
    loginWindow = null;
  });

  const session = loginWindow.webContents.session;

  // Monitor URL changes during login
  loginWindow.webContents.on('did-navigate', async (event, url) => {
    console.log('Navigation detected:', url);
    await checkForSessionCookie(session, url);
  });

  loginWindow.webContents.on('did-navigate-in-page', async (event, url) => {
    console.log('In-page navigation detected:', url);
    await checkForSessionCookie(session, url);
  });

  // Also keep the original callback detection as backup
  session.webRequest.onCompleted(
    { urls: ['https://www.cursor.com/api/auth/callback*'] },
    async () => {
      console.log('Login callback detected via webRequest');
      await checkForSessionCookie(session);
    }
  );
}

export function createSettingsWindow(): void {
  if (settingsWindow) {
    settingsWindow.focus();
    return;
  }
  settingsWindow = new BrowserWindow({
    width: 900,
    height: 800,
    minWidth: 600,
    minHeight: 700,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
      preload: path.join(__dirname, '../preload-settings.js'),
    },
  });

  settingsWindow.loadFile(path.join(__dirname, '../../renderer/settings.html'));

  settingsWindow.on('closed', () => {
    settingsWindow = null;
  });

  settingsWindow.webContents.on('did-finish-load', () => {
    sendCurrentSettingsToRenderer();
  });
}

export function sendCurrentSettingsToRenderer(): void {
  if (settingsWindow) {
    const settings: RendererSettings = {
      selectedCurrencyCode: store.get('selectedCurrencyCode', 'USD'),
      warningLimitUSD: store.get('warningLimitUSD', 0),
      upperLimitUSD: store.get('upperLimitUSD', 0),
      refreshIntervalMinutes: store.get('refreshIntervalMinutes', 5),
    };
    settingsWindow.webContents.send('load-settings', settings);
  }
}
