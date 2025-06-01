"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.showLoginSuccessNotification = showLoginSuccessNotification;
exports.checkLimitsAndNotify = checkLimitsAndNotify;
const electron_1 = require("electron");
const store_1 = require("./store");
const utils_1 = require("../utils");
const tray_1 = require("./tray");
function showLoginSuccessNotification() {
    new electron_1.Notification({
        title: 'Vibe Meter',
        body: 'Vibe synced! ✨',
    }).show();
    if (tray_1.tray && process.platform === 'darwin') {
        tray_1.tray.setTitle('Vibe synced! ✨');
        setTimeout(() => {
            Promise.resolve().then(() => __importStar(require('./tray'))).then(({ updateTrayDisplay }) => updateTrayDisplay());
        }, 3000);
    }
    else if (tray_1.tray) {
        Promise.resolve().then(() => __importStar(require('./tray'))).then(({ updateTrayDisplay }) => updateTrayDisplay());
    }
}
function checkLimitsAndNotify() {
    const currentSpendingUSD = store_1.store.get('currentSpendingUSD');
    if (typeof currentSpendingUSD !== 'number')
        return;
    const warningLimitUSD = store_1.store.get('warningLimitUSD', 0);
    const upperLimitUSD = store_1.store.get('upperLimitUSD', 0);
    const selectedCurrency = store_1.store.get('selectedCurrencyCode', 'USD');
    const symbol = (0, utils_1.getCurrencySymbol)(selectedCurrency);
    const rates = store_1.store.get('cachedExchangeRates');
    const displaySpending = (0, utils_1.getDisplayAmount)(currentSpendingUSD, selectedCurrency, rates);
    if (upperLimitUSD > 0 && currentSpendingUSD >= upperLimitUSD) {
        if (!store_1.store.get('notifiedUpperLimit')) {
            new electron_1.Notification({
                title: '🚨 Max Vibe Alert! 🚨',
                body: `Hold up! You've hit your max spend of ${symbol}${(0, utils_1.getDisplayAmount)(upperLimitUSD, selectedCurrency, rates)}. Current: ${symbol}${displaySpending}.`,
            }).show();
            store_1.store.set('notifiedUpperLimit', true);
            store_1.store.set('notifiedWarningLimit', true);
        }
    }
    else if (warningLimitUSD > 0 && currentSpendingUSD >= warningLimitUSD) {
        if (!store_1.store.get('notifiedWarningLimit')) {
            new electron_1.Notification({
                title: '💸 Vibe Check! 💸',
                body: `Psst! You're nearing your vibe budget. Current: ${symbol}${displaySpending} (Warning: ${symbol}${(0, utils_1.getDisplayAmount)(warningLimitUSD, selectedCurrency, rates)}).`,
            }).show();
            store_1.store.set('notifiedWarningLimit', true);
        }
    }
    else {
        store_1.store.delete('notifiedUpperLimit');
        store_1.store.delete('notifiedWarningLimit');
    }
}
//# sourceMappingURL=notifications.js.map