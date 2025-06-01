import Store from 'electron-store';
import { AppSettings } from './types';

export const schema: Store.Schema<AppSettings> = {
  selectedCurrencyCode: { type: 'string', default: 'USD' },
  warningLimitUSD: { type: 'number', default: 0 },
  upperLimitUSD: { type: 'number', default: 0 },
  refreshIntervalMinutes: { type: 'number', default: 5 },
  launchAtLoginEnabled: { type: 'boolean', default: false },
  teamId: { type: 'number' },
  teamName: { type: 'string' },
  userEmail: { type: 'string' },
  cachedExchangeRates: { type: 'object' },
  lastExchangeRateFetchTimestamp: { type: 'number' },
  notifiedUpperLimit: { type: 'boolean' },
  notifiedWarningLimit: { type: 'boolean' },
};

export const store = new Store<AppSettings>({ schema });
