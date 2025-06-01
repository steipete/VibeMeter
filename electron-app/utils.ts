export function getCurrencySymbol(currencyCode: string): string {
  const symbols: { [key: string]: string } = {
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

export function getDisplayAmount(
  amountUSD: number | string | undefined | null,
  targetCurrencyCode: string,
  rates?: { [key: string]: number } | null
): string {
  if (
    amountUSD === null ||
    amountUSD === undefined ||
    amountUSD === 'Error' ||
    amountUSD === 'Fetching...'
  ) {
    return String(amountUSD || 'N/A'); // Return 'Error', 'Fetching...', or 'N/A' for undefined/null
  }

  let numAmountUSD: number;
  if (typeof amountUSD === 'string') {
    numAmountUSD = parseFloat(amountUSD);
    if (isNaN(numAmountUSD)) {
      return 'Invalid Amount';
    }
  } else {
    numAmountUSD = amountUSD;
  }

  const upperTargetCurrencyCode = targetCurrencyCode.toUpperCase();

  if (upperTargetCurrencyCode === 'USD' || !rates) {
    return numAmountUSD.toFixed(2);
  }

  let foundRate: number | undefined = undefined;
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
    console.warn(
      `Invalid rate for ${targetCurrencyCode} (key: ${upperTargetCurrencyCode}), falling back to USD display.`
    );
    return numAmountUSD.toFixed(2);
  }

  const convertedAmount = numAmountUSD * foundRate;
  return convertedAmount.toFixed(2);
}
