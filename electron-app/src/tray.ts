import { Tray, Menu } from 'electron';
import keytar from 'keytar';
import { store } from './store';
import { getCurrencySymbol, getDisplayAmount as utilGetDisplayAmount } from '../utils';
import { createLoginWindow, createSettingsWindow } from './windows';
import { fetchData } from './api';
import { logOut } from './auth';
import { app } from 'electron';

export let tray: Tray | null = null;

export function setTray(newTray: Tray): void {
  tray = newTray;
}

export function updateTrayDisplay(): void {
  if (!tray) return;

  const userEmail = store.get('userEmail');
  const isLoggedIn = !!userEmail && userEmail !== 'Error';
  let tooltipText = 'Login Required';
  let trayTitleText = 'Vibe Meter';

  if (!isLoggedIn) {
    tooltipText = 'Login Required - Click Refresh';
    trayTitleText = '⚠️';
  } else {
    const currentSpendingUSD = store.get('currentSpendingUSD');
    const warningLimitUSD = store.get('warningLimitUSD', 0);
    const selectedCurrency = store.get('selectedCurrencyCode', 'USD');
    const symbol = getCurrencySymbol(selectedCurrency);
    const rates = store.get('cachedExchangeRates');

    if (currentSpendingUSD === 'Error') {
      tooltipText = 'Error fetching data. Try refreshing.';
      trayTitleText = '❌';
    } else if (typeof currentSpendingUSD === 'number') {
      const displaySpending = utilGetDisplayAmount(currentSpendingUSD, selectedCurrency, rates);
      const displayWarning = utilGetDisplayAmount(warningLimitUSD, selectedCurrency, rates);
      tooltipText = `${symbol}${displaySpending} / ${symbol}${displayWarning}`;
      trayTitleText = `${symbol}${displaySpending}`;
    } else {
      tooltipText = 'Fetching data...';
      trayTitleText = '⏳';
    }
  }

  tray.setToolTip(tooltipText);
  if (process.platform === 'darwin') {
    tray.setTitle(trayTitleText);
  }
}

export async function buildContextMenu(): Promise<Menu> {
  const token = await keytar.getPassword('VibeMeter', 'WorkosCursorSessionToken');
  const isLoggedIn = !!token;

  const currentSpendingUSD = store.get('currentSpendingUSD', 'Error');
  const selectedCurrency = store.get('selectedCurrencyCode', 'USD');
  const exchangeRates = store.get('cachedExchangeRates', {});
  const currencySymbol = getCurrencySymbol(selectedCurrency);

  let displaySpending: string;
  if (currentSpendingUSD === 'Fetching...') {
    displaySpending = 'Fetching...';
  } else if (currentSpendingUSD === 'Error' || typeof currentSpendingUSD !== 'number') {
    displaySpending = 'N/A';
  } else {
    displaySpending = `${currencySymbol}${utilGetDisplayAmount(
      currentSpendingUSD,
      selectedCurrency,
      exchangeRates
    )}`;
  }

  const warningLimit = store.get('warningLimitUSD', 0);
  const displayWarning = `${currencySymbol}${utilGetDisplayAmount(
    warningLimit,
    selectedCurrency,
    exchangeRates
  )}`;
  const upperLimit = store.get('upperLimitUSD', 0);
  const displayUpper = `${currencySymbol}${utilGetDisplayAmount(
    upperLimit,
    selectedCurrency,
    exchangeRates
  )}`;

  const contextMenuItems: Electron.MenuItemConstructorOptions[] = [];

  if (isLoggedIn) {
    const userEmail = store.get('userEmail', 'Logged In');
    const teamName = store.get('teamName', 'Your Team');
    contextMenuItems.push({ label: `Logged In As: ${userEmail}`, enabled: false });
    contextMenuItems.push({ label: `Current Spending: ${displaySpending}`, enabled: false });
    contextMenuItems.push({ label: `Warning at: ${displayWarning}`, enabled: false });
    contextMenuItems.push({ label: `Max: ${displayUpper}`, enabled: false });
    contextMenuItems.push({ label: `Vibing with: ${teamName}`, enabled: false });
    contextMenuItems.push({ type: 'separator' });
  } else {
    contextMenuItems.push({ label: 'Not Logged In', enabled: false });
    contextMenuItems.push({ label: 'Log In', click: createLoginWindow });
    contextMenuItems.push({ type: 'separator' });
  }

  contextMenuItems.push({
    label: 'Refresh Now',
    click: async () => {
      if (!isLoggedIn) {
        createLoginWindow();
      } else {
        await fetchData();
      }
    },
  });

  const teamId = store.get('teamId');
  const lastFetchTime = store.get('lastExchangeRateFetchTimestamp');
  const rates = store.get('cachedExchangeRates');

  if (isLoggedIn && !teamId && currentSpendingUSD !== 'Fetching...') {
    contextMenuItems.push({
      label: "Hmm, can't find your team vibe right now. 😕 Try a refresh?",
      enabled: false,
    });
  }
  if (
    selectedCurrency !== 'USD' &&
    (!rates || Object.keys(rates).length === 0 || !lastFetchTime) &&
    currentSpendingUSD !== 'Fetching...'
  ) {
    contextMenuItems.push({ label: 'Rates MIA! Showing USD for now. ✨', enabled: false });
  }

  contextMenuItems.push({ label: 'Settings...', click: createSettingsWindow });

  if (isLoggedIn) {
    contextMenuItems.push({ label: 'Log Out', click: logOut });
  }

  contextMenuItems.push({ type: 'separator' });
  contextMenuItems.push({
    label: 'Launch at Login',
    type: 'checkbox',
    checked: store.get('launchAtLoginEnabled', false),
    click: menuItem => {
      const enable = menuItem.checked;
      store.set('launchAtLoginEnabled', enable);
      app.setLoginItemSettings({
        openAtLogin: enable,
        openAsHidden: false,
      });
    },
  });
  contextMenuItems.push({ label: 'Quit Vibe Meter', click: () => app.quit() });

  return Menu.buildFromTemplate(contextMenuItems);
}

export async function updateTray(): Promise<void> {
  if (!tray) return;
  const menu = await buildContextMenu();
  tray.setContextMenu(menu);
  updateTrayDisplay();
}