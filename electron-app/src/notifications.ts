import { Notification } from 'electron';
import { store } from './store';
import { getCurrencySymbol, getDisplayAmount as utilGetDisplayAmount } from '../utils';
import { tray } from './tray';

export function showLoginSuccessNotification(): void {
  new Notification({
    title: 'Vibe Meter',
    body: 'Vibe synced! ✨',
  }).show();
  if (tray && process.platform === 'darwin') {
    tray.setTitle('Vibe synced! ✨');
    setTimeout(() => {
      import('./tray').then(({ updateTrayDisplay }) => updateTrayDisplay());
    }, 3000);
  } else if (tray) {
    import('./tray').then(({ updateTrayDisplay }) => updateTrayDisplay());
  }
}

export function checkLimitsAndNotify(): void {
  const currentSpendingUSD = store.get('currentSpendingUSD');
  if (typeof currentSpendingUSD !== 'number') return;

  const warningLimitUSD = store.get('warningLimitUSD', 0);
  const upperLimitUSD = store.get('upperLimitUSD', 0);
  const selectedCurrency = store.get('selectedCurrencyCode', 'USD');
  const symbol = getCurrencySymbol(selectedCurrency);
  const rates = store.get('cachedExchangeRates');

  const displaySpending = utilGetDisplayAmount(currentSpendingUSD, selectedCurrency, rates);

  if (upperLimitUSD > 0 && currentSpendingUSD >= upperLimitUSD) {
    if (!store.get('notifiedUpperLimit')) {
      new Notification({
        title: '🚨 Max Vibe Alert! 🚨',
        body: `Hold up! You've hit your max spend of ${symbol}${utilGetDisplayAmount(upperLimitUSD, selectedCurrency, rates)}. Current: ${symbol}${displaySpending}.`,
      }).show();
      store.set('notifiedUpperLimit', true);
      store.set('notifiedWarningLimit', true);
    }
  } else if (warningLimitUSD > 0 && currentSpendingUSD >= warningLimitUSD) {
    if (!store.get('notifiedWarningLimit')) {
      new Notification({
        title: '💸 Vibe Check! 💸',
        body: `Psst! You're nearing your vibe budget. Current: ${symbol}${displaySpending} (Warning: ${symbol}${utilGetDisplayAmount(warningLimitUSD, selectedCurrency, rates)}).`,
      }).show();
      store.set('notifiedWarningLimit', true);
    }
  } else {
    store.delete('notifiedUpperLimit');
    store.delete('notifiedWarningLimit');
  }
}