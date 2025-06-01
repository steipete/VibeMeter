"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.fetchData = fetchData;
exports.fetchExchangeRatesIfNeeded = fetchExchangeRatesIfNeeded;
const axios_1 = __importDefault(require("axios"));
const keytar_1 = __importDefault(require("keytar"));
const store_1 = require("./store");
const tray_1 = require("./tray");
const notifications_1 = require("./notifications");
const auth_1 = require("./auth");
async function fetchData() {
    console.log('Fetching data...');
    const token = await keytar_1.default.getPassword('VibeMeter', 'WorkosCursorSessionToken');
    if (!token) {
        console.log('Not logged in. Skipping data fetch.');
        store_1.store.delete('userEmail');
        store_1.store.delete('teamId');
        store_1.store.delete('teamName');
        store_1.store.set('currentSpendingUSD', 'Error');
        (0, tray_1.updateTray)();
        return;
    }
    try {
        const teamResponse = await axios_1.default.get('https://www.cursor.com/api/teams.get', {
            headers: { Cookie: `WorkosCursorSessionToken=${token}` },
        });
        if (teamResponse.data && teamResponse.data.length > 0) {
            const team = teamResponse.data[0];
            store_1.store.set('teamId', team.id);
            store_1.store.set('teamName', team.name);
            console.log('Team info fetched:', team.name);
        }
        else {
            console.log('No team data found or empty response.');
            store_1.store.delete('teamId');
            store_1.store.set('teamName', 'N/A');
        }
        // Try /me endpoint first, fall back to /users.get
        let userResponse;
        try {
            userResponse = await axios_1.default.get('https://www.cursor.com/api/me', {
                headers: { Cookie: `WorkosCursorSessionToken=${token}` },
            });
            console.log('User info fetched from /me endpoint');
        }
        catch (meError) {
            console.log('Failed to fetch from /me, trying /users.get');
            userResponse = await axios_1.default.get('https://www.cursor.com/api/users.get', {
                headers: { Cookie: `WorkosCursorSessionToken=${token}` },
            });
        }
        if (userResponse.data && userResponse.data.email) {
            store_1.store.set('userEmail', userResponse.data.email);
            console.log('User info fetched:', userResponse.data.email);
        }
        else {
            console.log('No user email found or empty response.');
            store_1.store.set('userEmail', 'Error');
        }
        const teamId = store_1.store.get('teamId');
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
                const billingResponse = await axios_1.default.post('https://www.cursor.com/api/dashboard/get-monthly-invoice', billingParams, {
                    headers: {
                        Cookie: `WorkosCursorSessionToken=${token}`,
                        'Content-Type': 'application/json',
                    },
                });
                if (billingResponse.data &&
                    billingResponse.data.items &&
                    Array.isArray(billingResponse.data.items)) {
                    let totalCents = 0;
                    billingResponse.data.items.forEach(item => {
                        if (item && typeof item.cents === 'number') {
                            totalCents += item.cents;
                        }
                    });
                    const totalUSD = totalCents / 100;
                    store_1.store.set('currentSpendingUSD', totalUSD);
                    console.log('Billing info fetched:', totalUSD);
                }
                else {
                    console.log('Could not fetch billing data or items array is missing/invalid.', billingResponse.data);
                    store_1.store.set('currentSpendingUSD', 'Error');
                }
            }
            catch (billingError) {
                console.error('Error fetching billing data:', billingError.message);
                if (billingError.response) {
                    console.error('Billing API Response Status:', billingError.response.status);
                    console.error('Billing API Response Data:', billingError.response.data);
                }
                store_1.store.set('currentSpendingUSD', 'Error');
            }
        }
        else {
            console.log('Skipping billing data fetch because teamId is not available.');
            store_1.store.set('currentSpendingUSD', 'Error');
        }
    }
    catch (error) {
        console.error('Error fetching data:', error.message);
        if (error.response && error.response.status === 401) {
            console.log('Unauthorized. Token might be invalid or expired.');
            await (0, auth_1.logOut)();
            (0, tray_1.updateTray)();
        }
        else {
            store_1.store.set('currentSpendingUSD', 'Error');
        }
    }
    await fetchExchangeRatesIfNeeded();
    (0, tray_1.updateTray)();
    (0, notifications_1.checkLimitsAndNotify)();
}
async function fetchExchangeRatesIfNeeded() {
    const selectedCurrency = store_1.store.get('selectedCurrencyCode', 'USD');
    if (selectedCurrency === 'USD') {
        store_1.store.delete('cachedExchangeRates');
        store_1.store.delete('lastExchangeRateFetchTimestamp');
        return;
    }
    const lastFetchTimestamp = store_1.store.get('lastExchangeRateFetchTimestamp', 0);
    const oneDay = 24 * 60 * 60 * 1000;
    if (Date.now() - lastFetchTimestamp > oneDay) {
        console.log(`Fetching exchange rates for ${selectedCurrency}...`);
        try {
            const response = await axios_1.default.get(`https://api.exchangerate-api.com/v4/latest/USD`);
            if (response.data && response.data.rates) {
                store_1.store.set('cachedExchangeRates', response.data.rates);
                store_1.store.set('lastExchangeRateFetchTimestamp', Date.now());
                console.log('Exchange rates fetched and cached.');
            }
            else {
                console.error('Failed to fetch exchange rates: Invalid response format');
            }
        }
        catch (error) {
            console.error('Error fetching exchange rates:', error.message);
        }
    }
}
//# sourceMappingURL=api.js.map