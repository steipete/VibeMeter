export interface AppSettings {
  selectedCurrencyCode: string;
  warningLimitUSD: number;
  upperLimitUSD: number;
  refreshIntervalMinutes: number;
  launchAtLoginEnabled: boolean;
  teamId?: number;
  teamName?: string;
  userEmail?: string;
  currentSpendingUSD?: number | 'Error' | 'Fetching...';
  cachedExchangeRates?: { [key: string]: number };
  lastExchangeRateFetchTimestamp?: number;
  notifiedUpperLimit?: boolean;
  notifiedWarningLimit?: boolean;
}

export interface RendererSettings {
  selectedCurrencyCode: string;
  warningLimitUSD: number;
  upperLimitUSD: number;
  refreshIntervalMinutes: number;
}

export interface TeamInfo {
  id: number;
  name: string;
}

export interface UserInfo {
  email: string;
}

export interface BillingItem {
  cents: number;
}

export interface BillingResponse {
  items: BillingItem[];
}

export interface ExchangeRateApiResponse {
  rates: { [key: string]: number };
}
