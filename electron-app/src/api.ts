import axios, { AxiosResponse } from 'axios';
import keytar from 'keytar';
import { store } from './store';
import { updateTray } from './tray';
import { checkLimitsAndNotify } from './notifications';
import { logOut } from './auth';
import { TeamInfo, UserInfo, BillingResponse, ExchangeRateApiResponse } from './types';

export async function fetchData(): Promise<void> {
  console.log('Fetching data...');
  const token = await keytar.getPassword('VibeMeter', 'WorkosCursorSessionToken');
  if (!token) {
    console.log('Not logged in. Skipping data fetch.');
    store.delete('userEmail');
    store.delete('teamId');
    store.delete('teamName');
    store.set('currentSpendingUSD', 'Error');
    updateTray();
    return;
  }

  try {
    const teamResponse: AxiosResponse<TeamInfo[]> = await axios.get(
      'https://www.cursor.com/api/teams.get',
      {
        headers: { Cookie: `WorkosCursorSessionToken=${token}` },
      }
    );
    if (teamResponse.data && teamResponse.data.length > 0) {
      const team = teamResponse.data[0];
      store.set('teamId', team.id);
      store.set('teamName', team.name);
      console.log('Team info fetched:', team.name);
    } else {
      console.log('No team data found or empty response.');
      store.delete('teamId');
      store.set('teamName', 'N/A');
    }

    // Try /me endpoint first, fall back to /users.get
    let userResponse: AxiosResponse<UserInfo>;
    try {
      userResponse = await axios.get('https://www.cursor.com/api/me', {
        headers: { Cookie: `WorkosCursorSessionToken=${token}` },
      });
      console.log('User info fetched from /me endpoint');
    } catch (meError) {
      console.log('Failed to fetch from /me, trying /users.get');
      userResponse = await axios.get('https://www.cursor.com/api/users.get', {
        headers: { Cookie: `WorkosCursorSessionToken=${token}` },
      });
    }

    if (userResponse.data && userResponse.data.email) {
      store.set('userEmail', userResponse.data.email);
      console.log('User info fetched:', userResponse.data.email);
    } else {
      console.log('No user email found or empty response.');
      store.set('userEmail', 'Error');
    }

    const teamId = store.get('teamId');
    if (teamId) {
      const currentDate = new Date();
      const currentMonth = currentDate.getMonth() + 1;
      const currentYear = currentDate.getFullYear();

      try {
        const billingParams = {
          teamId: teamId,
          month: currentMonth,
          year: currentYear,
          includeUsageEvents: false,
        };
        const billingResponse: AxiosResponse<BillingResponse> = await axios.post(
          'https://www.cursor.com/api/dashboard/get-monthly-invoice',
          billingParams,
          {
            headers: {
              Cookie: `WorkosCursorSessionToken=${token}`,
              'Content-Type': 'application/json',
            },
          }
        );

        if (
          billingResponse.data &&
          billingResponse.data.items &&
          Array.isArray(billingResponse.data.items)
        ) {
          let totalCents = 0;
          billingResponse.data.items.forEach(item => {
            if (item && typeof item.cents === 'number') {
              totalCents += item.cents;
            }
          });
          const totalUSD = totalCents / 100;
          store.set('currentSpendingUSD', totalUSD);
          console.log('Billing info fetched:', totalUSD);
        } else {
          console.log(
            'Could not fetch billing data or items array is missing/invalid.',
            billingResponse.data
          );
          store.set('currentSpendingUSD', 'Error');
        }
      } catch (billingError: any) {
        console.error('Error fetching billing data:', billingError.message);
        if (billingError.response) {
          console.error('Billing API Response Status:', billingError.response.status);
          console.error('Billing API Response Data:', billingError.response.data);
        }
        store.set('currentSpendingUSD', 'Error');
      }
    } else {
      console.log('Skipping billing data fetch because teamId is not available.');
      store.set('currentSpendingUSD', 'Error');
    }
  } catch (error: any) {
    console.error('Error fetching data:', error.message);
    if (error.response && error.response.status === 401) {
      console.log('Unauthorized. Token might be invalid or expired.');
      await logOut();
      updateTray();
    } else {
      store.set('currentSpendingUSD', 'Error');
    }
  }
  await fetchExchangeRatesIfNeeded();
  updateTray();
  checkLimitsAndNotify();
}

export async function fetchExchangeRatesIfNeeded(): Promise<void> {
  const selectedCurrency = store.get('selectedCurrencyCode', 'USD');
  if (selectedCurrency === 'USD') {
    store.delete('cachedExchangeRates');
    store.delete('lastExchangeRateFetchTimestamp');
    return;
  }

  const lastFetchTimestamp = store.get('lastExchangeRateFetchTimestamp', 0);
  const oneDay = 24 * 60 * 60 * 1000;

  if (Date.now() - lastFetchTimestamp > oneDay) {
    console.log(`Fetching exchange rates for ${selectedCurrency}...`);
    try {
      const response: AxiosResponse<ExchangeRateApiResponse> = await axios.get(
        `https://api.exchangerate-api.com/v4/latest/USD`
      );
      if (response.data && response.data.rates) {
        store.set('cachedExchangeRates', response.data.rates);
        store.set('lastExchangeRateFetchTimestamp', Date.now());
        console.log('Exchange rates fetched and cached.');
      } else {
        console.error('Failed to fetch exchange rates: Invalid response format');
      }
    } catch (error: any) {
      console.error('Error fetching exchange rates:', error.message);
    }
  }
}