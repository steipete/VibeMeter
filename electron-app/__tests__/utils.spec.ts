import { getCurrencySymbol, getDisplayAmount } from '../utils'; // Will resolve to utils.ts

describe('Utility Functions', () => {
  describe('getCurrencySymbol', () => {
    it('should return $ for USD', () => {
      expect(getCurrencySymbol('USD')).toBe('$');
    });

    it('should return € for EUR', () => {
      expect(getCurrencySymbol('EUR')).toBe('€');
    });

    it('should return £ for GBP', () => {
      expect(getCurrencySymbol('GBP')).toBe('£');
    });

    it('should return ¥ for JPY', () => {
      expect(getCurrencySymbol('JPY')).toBe('¥');
    });

    it('should return C$ for CAD', () => {
      expect(getCurrencySymbol('CAD')).toBe('C$');
    });

    it('should return A$ for AUD', () => {
      expect(getCurrencySymbol('AUD')).toBe('A$');
    });

    it('should return the code itself if symbol not found', () => {
      expect(getCurrencySymbol('XYZ')).toBe('XYZ');
    });

    it('should handle lowercase codes', () => {
      expect(getCurrencySymbol('usd')).toBe('$');
    });
  });

  describe('getDisplayAmount', () => {
    const rates = {
      EUR: 0.9,
      GBP: 0.8,
      JPY: 110,
    };

    it('should return N/A for null amount', () => {
      expect(getDisplayAmount(null, 'USD', rates)).toBe('N/A');
    });

    it('should return N/A for undefined amount', () => {
      expect(getDisplayAmount(undefined, 'USD', rates)).toBe('N/A');
    });

    it('should return Error string as is', () => {
      expect(getDisplayAmount('Error', 'USD', rates)).toBe('Error');
    });

    it('should return Fetching... string as is', () => {
      expect(getDisplayAmount('Fetching...', 'USD', rates)).toBe('Fetching...');
    });

    it('should return Invalid Amount for non-numeric string amount', () => {
      expect(getDisplayAmount('abc', 'USD', rates)).toBe('Invalid Amount');
    });

    it('should convert amount in USD to 2 decimal places if target is USD', () => {
      expect(getDisplayAmount(123.456, 'USD', rates)).toBe('123.46');
      expect(getDisplayAmount('123.456', 'USD', rates)).toBe('123.46');
    });

    it('should convert amount to target currency using rates', () => {
      expect(getDisplayAmount(100, 'EUR', rates)).toBe('90.00'); // 100 * 0.9
      expect(getDisplayAmount('100', 'EUR', rates)).toBe('90.00');
      expect(getDisplayAmount(100, 'GBP', rates)).toBe('80.00'); // 100 * 0.8
      expect(getDisplayAmount(100, 'JPY', rates)).toBe('11000.00'); // 100 * 110
    });

    it('should return USD amount if rates object is null or undefined', () => {
      expect(getDisplayAmount(100, 'EUR', null)).toBe('100.00');
      expect(getDisplayAmount(100, 'EUR', undefined)).toBe('100.00');
    });

    it('should return USD amount if target currency not in rates', () => {
      expect(getDisplayAmount(100, 'XYZ', rates)).toBe('100.00');
    });

    it('should handle rates with different casing for currency code', () => {
      const mixedCaseRates = { eUr: 0.9 };
      expect(getDisplayAmount(100, 'EUR', mixedCaseRates)).toBe('90.00');
    });

    it('should handle target currency code with different casing', () => {
      expect(getDisplayAmount(100, 'eur', rates)).toBe('90.00');
    });

    it('should return USD amount if rate for target currency is not a number', () => {
      const invalidRates: any = { EUR: 'not-a-number' };
      expect(getDisplayAmount(100, 'EUR', invalidRates)).toBe('100.00');
    });
  });
});

export {}; // Make this a module if needed, though Jest usually handles it
