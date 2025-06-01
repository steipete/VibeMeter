"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getCurrencySymbol = getCurrencySymbol;
exports.getDisplayAmount = getDisplayAmount;
function getCurrencySymbol(currencyCode) {
    const symbols = {
        USD: '$',
        EUR: '€',
        GBP: '£',
        JPY: '¥',
        CAD: 'C$',
        AUD: 'A$',
        // Add more as needed
    };
    return symbols[currencyCode.toUpperCase()] || currencyCode; // Fallback to code if symbol not found
}
function getDisplayAmount(amountUSD, targetCurrencyCode, rates) {
    if (amountUSD === null ||
        amountUSD === undefined ||
        amountUSD === 'Error' ||
        amountUSD === 'Fetching...') {
        return String(amountUSD || 'N/A'); // Return 'Error', 'Fetching...', or 'N/A' for undefined/null
    }
    let numAmountUSD;
    if (typeof amountUSD === 'string') {
        numAmountUSD = parseFloat(amountUSD);
        if (isNaN(numAmountUSD)) {
            return 'Invalid Amount';
        }
    }
    else {
        numAmountUSD = amountUSD;
    }
    const upperTargetCurrencyCode = targetCurrencyCode.toUpperCase();
    if (upperTargetCurrencyCode === 'USD' || !rates) {
        return numAmountUSD.toFixed(2);
    }
    let foundRate = undefined;
    for (const key in rates) {
        if (Object.prototype.hasOwnProperty.call(rates, key)) {
            if (key.toUpperCase() === upperTargetCurrencyCode) {
                foundRate = rates[key];
                break;
            }
        }
    }
    if (foundRate === undefined) {
        // Fallback to USD if target currency not found in rates (case-insensitively)
        return numAmountUSD.toFixed(2);
    }
    if (typeof foundRate !== 'number' || isNaN(foundRate)) {
        console.warn(`Invalid rate for ${targetCurrencyCode} (key: ${upperTargetCurrencyCode}), falling back to USD display.`);
        return numAmountUSD.toFixed(2);
    }
    const convertedAmount = numAmountUSD * foundRate;
    return convertedAmount.toFixed(2);
}
//# sourceMappingURL=utils.js.map