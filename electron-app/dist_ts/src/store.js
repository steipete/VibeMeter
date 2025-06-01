"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.store = exports.schema = void 0;
const electron_store_1 = __importDefault(require("electron-store"));
exports.schema = {
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
exports.store = new electron_store_1.default({ schema: exports.schema });
//# sourceMappingURL=store.js.map