"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.tray = void 0;
exports.setTray = setTray;
exports.updateTrayDisplay = updateTrayDisplay;
exports.buildContextMenu = buildContextMenu;
exports.updateTray = updateTray;
const electron_1 = require("electron");
const keytar_1 = __importDefault(require("keytar"));
const store_1 = require("./store");
const utils_1 = require("../utils");
const windows_1 = require("./windows");
const api_1 = require("./api");
const auth_1 = require("./auth");
const electron_2 = require("electron");
exports.tray = null;
function setTray(newTray) {
    exports.tray = newTray;
}
function updateTrayDisplay() {
    if (!exports.tray)
        return;
    const userEmail = store_1.store.get('userEmail');
    const isLoggedIn = !!userEmail && userEmail !== 'Error';
    let tooltipText = 'Login Required';
    let trayTitleText = 'Vibe Meter';
    if (!isLoggedIn) {
        tooltipText = 'Login Required - Click Refresh';
        trayTitleText = '⚠️';
    }
    else {
        const currentSpendingUSD = store_1.store.get('currentSpendingUSD');
        const warningLimitUSD = store_1.store.get('warningLimitUSD', 0);
        const selectedCurrency = store_1.store.get('selectedCurrencyCode', 'USD');
        const symbol = (0, utils_1.getCurrencySymbol)(selectedCurrency);
        const rates = store_1.store.get('cachedExchangeRates');
        if (currentSpendingUSD === 'Error') {
            tooltipText = 'Error fetching data. Try refreshing.';
            trayTitleText = '❌';
        }
        else if (typeof currentSpendingUSD === 'number') {
            const displaySpending = (0, utils_1.getDisplayAmount)(currentSpendingUSD, selectedCurrency, rates);
            const displayWarning = (0, utils_1.getDisplayAmount)(warningLimitUSD, selectedCurrency, rates);
            tooltipText = `${symbol}${displaySpending} / ${symbol}${displayWarning}`;
            trayTitleText = `${symbol}${displaySpending}`;
        }
        else {
            tooltipText = 'Fetching data...';
            trayTitleText = '⏳';
        }
    }
    exports.tray.setToolTip(tooltipText);
    if (process.platform === 'darwin') {
        exports.tray.setTitle(trayTitleText);
    }
}
async function buildContextMenu() {
    const token = await keytar_1.default.getPassword('VibeMeter', 'WorkosCursorSessionToken');
    const isLoggedIn = !!token;
    const currentSpendingUSD = store_1.store.get('currentSpendingUSD', 'Error');
    const selectedCurrency = store_1.store.get('selectedCurrencyCode', 'USD');
    const exchangeRates = store_1.store.get('cachedExchangeRates', {});
    const currencySymbol = (0, utils_1.getCurrencySymbol)(selectedCurrency);
    let displaySpending;
    if (currentSpendingUSD === 'Fetching...') {
        displaySpending = 'Fetching...';
    }
    else if (currentSpendingUSD === 'Error' || typeof currentSpendingUSD !== 'number') {
        displaySpending = 'N/A';
    }
    else {
        displaySpending = `${currencySymbol}${(0, utils_1.getDisplayAmount)(currentSpendingUSD, selectedCurrency, exchangeRates)}`;
    }
    const warningLimit = store_1.store.get('warningLimitUSD', 0);
    const displayWarning = `${currencySymbol}${(0, utils_1.getDisplayAmount)(warningLimit, selectedCurrency, exchangeRates)}`;
    const upperLimit = store_1.store.get('upperLimitUSD', 0);
    const displayUpper = `${currencySymbol}${(0, utils_1.getDisplayAmount)(upperLimit, selectedCurrency, exchangeRates)}`;
    const contextMenuItems = [];
    if (isLoggedIn) {
        const userEmail = store_1.store.get('userEmail', 'Logged In');
        const teamName = store_1.store.get('teamName', 'Your Team');
        contextMenuItems.push({ label: `Logged In As: ${userEmail}`, enabled: false });
        contextMenuItems.push({ label: `Current Spending: ${displaySpending}`, enabled: false });
        contextMenuItems.push({ label: `Warning at: ${displayWarning}`, enabled: false });
        contextMenuItems.push({ label: `Max: ${displayUpper}`, enabled: false });
        contextMenuItems.push({ label: `Vibing with: ${teamName}`, enabled: false });
        contextMenuItems.push({ type: 'separator' });
    }
    else {
        contextMenuItems.push({ label: 'Not Logged In', enabled: false });
        contextMenuItems.push({ label: 'Log In', click: windows_1.createLoginWindow });
        contextMenuItems.push({ type: 'separator' });
    }
    contextMenuItems.push({
        label: 'Refresh Now',
        click: async () => {
            if (!isLoggedIn) {
                (0, windows_1.createLoginWindow)();
            }
            else {
                await (0, api_1.fetchData)();
            }
        },
    });
    const teamId = store_1.store.get('teamId');
    const lastFetchTime = store_1.store.get('lastExchangeRateFetchTimestamp');
    const rates = store_1.store.get('cachedExchangeRates');
    if (isLoggedIn && !teamId && currentSpendingUSD !== 'Fetching...') {
        contextMenuItems.push({
            label: "Hmm, can't find your team vibe right now. 😕 Try a refresh?",
            enabled: false,
        });
    }
    if (selectedCurrency !== 'USD' &&
        (!rates || Object.keys(rates).length === 0 || !lastFetchTime) &&
        currentSpendingUSD !== 'Fetching...') {
        contextMenuItems.push({ label: 'Rates MIA! Showing USD for now. ✨', enabled: false });
    }
    contextMenuItems.push({ label: 'Settings...', click: windows_1.createSettingsWindow });
    if (isLoggedIn) {
        contextMenuItems.push({ label: 'Log Out', click: auth_1.logOut });
    }
    contextMenuItems.push({ type: 'separator' });
    contextMenuItems.push({
        label: 'Launch at Login',
        type: 'checkbox',
        checked: store_1.store.get('launchAtLoginEnabled', false),
        click: menuItem => {
            const enable = menuItem.checked;
            store_1.store.set('launchAtLoginEnabled', enable);
            electron_2.app.setLoginItemSettings({
                openAtLogin: enable,
                openAsHidden: false,
            });
        },
    });
    contextMenuItems.push({ label: 'Quit Vibe Meter', click: () => electron_2.app.quit() });
    return electron_1.Menu.buildFromTemplate(contextMenuItems);
}
async function updateTray() {
    if (!exports.tray)
        return;
    const menu = await buildContextMenu();
    exports.tray.setContextMenu(menu);
    updateTrayDisplay();
}
//# sourceMappingURL=tray.js.map