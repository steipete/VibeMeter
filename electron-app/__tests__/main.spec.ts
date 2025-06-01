import { app, Tray, Menu, Notification, MenuItemConstructorOptions, TitleOptions } from 'electron';
import Store from 'electron-store';
import keytar from 'keytar';
import axios from 'axios';

// Import the type for the functions exported for testing from main.ts
import { TestExports } from '../src/main';

// Mock electron-store before it's imported by main.ts
// The actual mock implementation is in __tests__/__mocks__/electron-store.js
jest.mock('electron-store');

// Mock keytar
jest.mock('keytar');
const mockKeytar = keytar as jest.Mocked<typeof keytar>;

// Mock axios
jest.mock('axios');
const mockAxios = axios as jest.Mocked<typeof axios>;

// Mock Electron modules
jest.mock('electron', () => ({
  app: {
    on: jest.fn(),
    whenReady: jest.fn().mockImplementation(() => Promise.resolve()),
    getPath: jest.fn((name: string) => {
      if (name === 'userData') return '/mock/userData';
      return '.';
    }),
    getName: jest.fn(() => 'VibeMeterTest'),
    getVersion: jest.fn(() => '1.0.0-test'),
    isPackaged: false,
    setLoginItemSettings: jest.fn(),
    quit: jest.fn(),
  },
  BrowserWindow: jest.fn().mockImplementation(() => ({
    loadFile: jest.fn(),
    on: jest.fn(),
    close: jest.fn(),
    focus: jest.fn(),
    webContents: {
      on: jest.fn(),
      send: jest.fn(),
      session: {
        cookies: {
          get: jest.fn(() => Promise.resolve([])),
          set: jest.fn(() => Promise.resolve()),
          remove: jest.fn(() => Promise.resolve()),
        },
        webRequest: {
          onCompleted: jest.fn(),
        },
      },
      loadURL: jest.fn(),
      getURL: jest.fn(() => 'https://authenticator.cursor.sh/'),
    },
    // Add any other methods/properties your code uses
    isDestroyed: jest.fn(() => false),
    show: jest.fn(),
    hide: jest.fn(),
    isFocused: jest.fn(() => true),
  })),
  ipcMain: {
    on: jest.fn(),
    handle: jest.fn(),
    removeHandler: jest.fn(),
  },
  Tray: jest.fn().mockImplementation((iconPath: string) => ({
    setToolTip: jest.fn(),
    setTitle: jest.fn(),
    setContextMenu: jest.fn(),
    on: jest.fn(),
    destroy: jest.fn(),
    isDestroyed: jest.fn(() => false),
    iconPath: iconPath,
    getTitle: jest.fn(() => ''),
  })),
  Menu: {
    buildFromTemplate: jest.fn((template: MenuItemConstructorOptions[]) => ({
      items: template,
      popup: jest.fn(),
      append: jest.fn(),
      getMenuItemById: jest.fn(),
      insert: jest.fn(),
      setApplicationMenu: jest.fn(),
      // Provide a getter for `items` that matches the Readonly<Electron.MenuItem[]> type expected by some Electron versions/types
      get length() {
        return this.items.length;
      }, // Example, might not be needed
      get itemsList() {
        return this.items;
      }, // Return the plain array for inspection
    })),
    setApplicationMenu: jest.fn(),
  },
  Notification: jest
    .fn()
    .mockImplementation((options: Electron.NotificationConstructorOptions) => ({
      show: jest.fn(),
      on: jest.fn(),
      options: options,
    })),
  dialog: {
    showErrorBox: jest.fn(),
    showMessageBox: jest.fn(() => Promise.resolve({ response: 0 })),
  },
  nativeTheme: {
    on: jest.fn(),
    shouldUseDarkColors: false,
  },
}));

// Define an interface for the shape of the mocked store instance
interface MockStoreInstanceType {
  get: jest.Mock<any, [key: string, defaultValue?: any]>;
  set: jest.Mock<any, [key: string | { [key: string]: any }, value?: any]>; // Matches Store.set signature
  delete: jest.Mock<any, [key: string]>;
  clear: jest.Mock<any, []>;
  // Add other store methods if they are part of your mock and used in tests
  // For example: has: jest.Mock<boolean, [key: string]>;
}

// Define a type for the mocked Tray instance based on our mock implementation
interface MockTrayInstanceType {
  setToolTip: jest.Mock<void, [string]>;
  setTitle: jest.Mock<void, [string, TitleOptions?]>;
  setContextMenu: jest.Mock<void, [Menu | null]>;
  // The mock 'on' is a simple jest.fn(). For type safety, we can specify common signatures if needed,
  // or keep it general if complex event typings aren't crucial for the tests.
  on: jest.Mock<Electron.Tray, [event: string, listener: (...args: any[]) => void]>;
  destroy: jest.Mock<void, []>;
  isDestroyed: jest.Mock<boolean, []>;
  iconPath: string; // This is a property, not a mock function, in our mock
  getTitle: jest.Mock<string, []>;
}

// Variable to hold the imported main module functions
let mainFunctions: TestExports;

describe('Main Process (main.ts)', () => {
  let mockStoreInstance: MockStoreInstanceType;
  let mockTrayInstance: MockTrayInstanceType | undefined;

  beforeEach(() => {
    jest.clearAllMocks();
    jest.useFakeTimers();

    jest.resetModules();
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    const mainModule = require('../dist_ts/main');
    mainFunctions = mainModule as TestExports;

    const storeMockConstructor = Store as any; // Use any for broader cast

    if (storeMockConstructor.mock.results.length > 0) {
      mockStoreInstance = storeMockConstructor.mock.results[0].value as MockStoreInstanceType;
    } else {
      console.warn('Store mock instance not found in mock.results. Creating one for the test.');
      mockStoreInstance = new (Store as any)() as MockStoreInstanceType;
    }

    if (!mockStoreInstance || typeof mockStoreInstance.get !== 'function') {
      console.error('mockStoreInstance is invalid after attempting to retrieve/create it.');
      mockStoreInstance = new (Store as any)() as MockStoreInstanceType;
      if (!mockStoreInstance || typeof mockStoreInstance.get !== 'function') {
        throw new Error('Failed to obtain a valid mock Store instance.');
      }
    }

    // Default mock implementations for store methods for each test
    mockStoreInstance.get.mockImplementation((key: string, defaultValue?: any) => {
      const mockDefaults: { [key: string]: any } = {
        selectedCurrencyCode: 'USD',
        warningLimitUSD: 0,
        upperLimitUSD: 0,
        refreshIntervalMinutes: 5,
        launchAtLoginEnabled: false,
        notifiedUpperLimit: false,
        notifiedWarningLimit: false,
        currentSpendingUSD: 0,
        cachedExchangeRates: null,
        lastExchangeRateFetchTimestamp: 0,
        userEmail: 'test@example.com',
        teamId: 123,
        teamName: 'Test Team',
      };
      return mockDefaults[key] !== undefined ? mockDefaults[key] : defaultValue;
    });
    mockStoreInstance.set.mockImplementation(() => {});
    mockStoreInstance.delete.mockImplementation(() => {});
    mockStoreInstance.clear = jest.fn();

    const TrayMock = Tray as jest.MockedClass<typeof Tray>;
    if (TrayMock.mock.instances.length > 0) {
      mockTrayInstance = TrayMock.mock.instances[0] as unknown as MockTrayInstanceType;
    }

    mockKeytar.getPassword.mockResolvedValue('mock-token');
    mockKeytar.setPassword.mockResolvedValue(undefined);
    mockKeytar.deletePassword.mockResolvedValue(true);

    mockAxios.get.mockResolvedValue({
      data: {},
      status: 200,
      statusText: 'OK',
      headers: {},
      config: {} as any,
    });
    mockAxios.post.mockResolvedValue({
      data: {},
      status: 200,
      statusText: 'OK',
      headers: {},
      config: {} as any,
    });

    if (mockTrayInstance) {
      mockTrayInstance.setToolTip.mockClear();
      mockTrayInstance.setTitle.mockClear();
      mockTrayInstance.setContextMenu.mockClear();
      mockTrayInstance.on.mockClear(); // Clear the general mock 'on'
    }

    (Notification as jest.MockedClass<typeof Notification>).mockClear();
    const notificationShowMock =
      (Notification as any).prototype.show ||
      (Notification as jest.MockedClass<typeof Notification>).mock.instances[0]?.show;
    if (notificationShowMock && typeof notificationShowMock.mockClear === 'function') {
      notificationShowMock.mockClear();
    }
  });

  afterEach(() => {
    if (jest.isMockFunction(setTimeout) || jest.isMockFunction(setInterval)) {
      jest.runOnlyPendingTimers();
    }
    jest.useRealTimers();
  });

  describe('checkLimitsAndNotify', () => {
    it('should not notify if currentSpendingUSD is not a number', () => {
      mockStoreInstance.get.mockImplementation((key: string) =>
        key === 'currentSpendingUSD' ? 'Error' : undefined
      );
      mainFunctions.checkLimitsAndNotify();
      expect(Notification).not.toHaveBeenCalled();
    });

    it('should notify for upper limit if exceeded and not already notified', () => {
      mockStoreInstance.get.mockImplementation(
        (key: string) =>
          (
            ({
              currentSpendingUSD: 150,
              upperLimitUSD: 100,
              warningLimitUSD: 50,
              notifiedUpperLimit: false,
              selectedCurrencyCode: 'USD',
            }) as any
          )[key]
      );
      mainFunctions.checkLimitsAndNotify();
      expect(Notification).toHaveBeenCalledTimes(1);
      expect(mockStoreInstance.set).toHaveBeenCalledWith('notifiedUpperLimit', true);
      expect(mockStoreInstance.set).toHaveBeenCalledWith('notifiedWarningLimit', true);
      const notificationArgs = (Notification as jest.MockedClass<typeof Notification>).mock
        .calls[0][0];
      expect(notificationArgs?.title).toContain('Max Vibe Alert');
      expect(notificationArgs?.body).toContain('$100.00');
      expect(notificationArgs?.body).toContain('$150.00');
    });

    it('should notify for warning limit if exceeded and not already notified (and not over upper)', () => {
      mockStoreInstance.get.mockImplementation((key: string) => {
        const values: { [id: string]: any } = {
          currentSpendingUSD: 75,
          upperLimitUSD: 100,
          warningLimitUSD: 50,
          notifiedWarningLimit: false,
          notifiedUpperLimit: false,
          selectedCurrencyCode: 'USD',
        };
        return values[key];
      });
      mainFunctions.checkLimitsAndNotify();
      expect(Notification).toHaveBeenCalledTimes(1);
      expect(mockStoreInstance.set).toHaveBeenCalledWith('notifiedWarningLimit', true);
      expect(mockStoreInstance.set).not.toHaveBeenCalledWith('notifiedUpperLimit', true);
      const notificationArgs = (Notification as jest.MockedClass<typeof Notification>).mock
        .calls[0][0];
      expect(notificationArgs?.title).toContain('Vibe Check');
      expect(notificationArgs?.body).toContain('$50.00');
      expect(notificationArgs?.body).toContain('$75.00');
    });

    it('should not notify if limits exceeded but already notified', () => {
      mockStoreInstance.get.mockImplementation((key: string) => {
        const values: { [id: string]: any } = {
          currentSpendingUSD: 150,
          upperLimitUSD: 100,
          warningLimitUSD: 50,
          notifiedUpperLimit: true,
          notifiedWarningLimit: true,
          selectedCurrencyCode: 'USD',
        };
        return values[key];
      });
      mainFunctions.checkLimitsAndNotify();
      expect(Notification).not.toHaveBeenCalled();
    });

    it('should clear notification flags if spending is below limits', () => {
      mockStoreInstance.get.mockImplementation((key: string) => {
        const values: { [id: string]: any } = {
          currentSpendingUSD: 40,
          upperLimitUSD: 100,
          warningLimitUSD: 50,
          notifiedUpperLimit: true,
          notifiedWarningLimit: true,
          selectedCurrencyCode: 'USD',
        };
        return values[key];
      });
      mainFunctions.checkLimitsAndNotify();
      expect(Notification).not.toHaveBeenCalled();
      expect(mockStoreInstance.set).toHaveBeenCalledWith('notifiedUpperLimit', false);
      expect(mockStoreInstance.set).toHaveBeenCalledWith('notifiedWarningLimit', false);
    });

    it('should display amounts in selected currency (EUR)', async () => {
      mockStoreInstance.get.mockImplementation((key: string) => {
        const values: { [id: string]: any } = {
          currentSpendingUSD: 150,
          upperLimitUSD: 100,
          warningLimitUSD: 50,
          notifiedUpperLimit: false,
          selectedCurrencyCode: 'EUR',
          cachedExchangeRates: { rates: { EUR: 0.9 } },
          lastExchangeRateFetchTimestamp: Date.now(),
        };
        return values[key];
      });
      mainFunctions.checkLimitsAndNotify();
      expect(Notification).toHaveBeenCalledTimes(1);
      const notificationArgs = (Notification as jest.MockedClass<typeof Notification>).mock
        .calls[0][0];
      expect(notificationArgs?.title).toContain('Max Vibe Alert');
      expect(notificationArgs?.body).toContain('€90.00');
      expect(notificationArgs?.body).toContain('€135.00');
    });
  });

  describe('logOut', () => {
    it('should delete password from keytar and clear relevant store items', async () => {
      await mainFunctions.logOut();
      expect(mockKeytar.deletePassword).toHaveBeenCalledWith(
        'VibeMeter',
        'WorkosCursorSessionToken'
      );
      expect(mockStoreInstance.delete).toHaveBeenCalledWith('userEmail');
      expect(mockStoreInstance.delete).toHaveBeenCalledWith('teamId');
      expect(mockStoreInstance.delete).toHaveBeenCalledWith('teamName');
      expect(mockStoreInstance.delete).toHaveBeenCalledWith('currentSpendingUSD');
      expect(mockStoreInstance.delete).toHaveBeenCalledWith('cachedExchangeRates');
      expect(mockStoreInstance.delete).toHaveBeenCalledWith('lastExchangeRateFetchTimestamp');
    });

    it('should call updateTray after logout actions', async () => {
      await mainFunctions.logOut();
      expect(Menu.buildFromTemplate).toHaveBeenCalled();
      if (mockTrayInstance) {
        expect(mockTrayInstance.setContextMenu).toHaveBeenCalled();
      }
    });
  });

  describe('fetchExchangeRatesIfNeeded', () => {
    beforeEach(() => {
      mockAxios.get.mockReset();
      mockStoreInstance.get.mockImplementation((key: string, defaultValue?: any) => {
        const mockDefaults: { [key: string]: any } = { selectedCurrencyCode: 'USD' };
        return mockDefaults[key] !== undefined ? mockDefaults[key] : defaultValue;
      });
      mockStoreInstance.set.mockClear();
    });

    it('should not fetch if selected currency is USD', async () => {
      mockStoreInstance.get.mockReturnValueOnce('USD');
      await mainFunctions.fetchExchangeRatesIfNeeded();
      expect(mockAxios.get).not.toHaveBeenCalled();
    });

    it('should fetch rates if currency is not USD and cache is old or missing', async () => {
      mockStoreInstance.get.mockImplementation((key: string) => {
        if (key === 'selectedCurrencyCode') return 'EUR';
        if (key === 'lastExchangeRateFetchTimestamp') return Date.now() - 25 * 60 * 60 * 1000;
        if (key === 'cachedExchangeRates') return null;
        return undefined;
      });
      mockAxios.get.mockResolvedValueOnce({ data: { rates: { EUR: 0.9 } } } as any);
      await mainFunctions.fetchExchangeRatesIfNeeded();
      expect(mockAxios.get).toHaveBeenCalledWith('https://api.exchangerate-api.com/v4/latest/USD');
      expect(mockStoreInstance.set).toHaveBeenCalledWith('cachedExchangeRates', {
        rates: { EUR: 0.9 },
      });
      expect(mockStoreInstance.set).toHaveBeenCalledWith(
        expect.stringContaining('lastExchangeRateFetchTimestamp'),
        expect.any(Number)
      );
    });

    it('should not fetch rates if cache is recent', async () => {
      mockStoreInstance.get.mockImplementation((key: string) => {
        if (key === 'selectedCurrencyCode') return 'EUR';
        if (key === 'lastExchangeRateFetchTimestamp') return Date.now() - 10 * 60 * 1000;
        if (key === 'cachedExchangeRates') return { rates: { EUR: 0.85 } };
        return undefined;
      });
      await mainFunctions.fetchExchangeRatesIfNeeded();
      expect(mockAxios.get).not.toHaveBeenCalled();
    });

    it('should handle API error gracefully', async () => {
      mockStoreInstance.get.mockImplementation((key: string) => {
        if (key === 'selectedCurrencyCode') return 'EUR';
        return undefined;
      });
      mockAxios.get.mockRejectedValueOnce(new Error('API Error'));
      await mainFunctions.fetchExchangeRatesIfNeeded();
      expect(mockStoreInstance.set).not.toHaveBeenCalledWith(
        'cachedExchangeRates',
        expect.anything()
      );
    });
  });

  describe('buildContextMenu', () => {
    it('should include Logged In As when user is logged in', async () => {
      mockStoreInstance.get.mockImplementation(
        key => (({ userEmail: 'user@example.com', teamName: 'Vibe Team' }) as any)[key]
      );
      mockKeytar.getPassword.mockResolvedValue('fake-token');
      await mainFunctions.buildContextMenu();
      const menuItems = (Menu.buildFromTemplate as jest.Mock).mock
        .calls[0][0] as MenuItemConstructorOptions[];
      expect(menuItems.find(item => item.label === 'Logged In As: user@example.com')).toBeDefined();
    });

    it('should include correct items when user is logged out', async () => {
      mockStoreInstance.get.mockImplementation(key =>
        key === 'userEmail' ? undefined : undefined
      );
      mockKeytar.getPassword.mockResolvedValue(null);
      await mainFunctions.buildContextMenu();
      const menuItems = (Menu.buildFromTemplate as jest.Mock).mock
        .calls[0][0] as MenuItemConstructorOptions[];
      expect(menuItems.find(item => item.label?.startsWith('Logged In As:'))).toBeUndefined();
      expect(menuItems.find(item => item.label === 'Refresh Now'))?.toBeDefined();
    });
  });

  describe('App Ready State', () => {
    it('should perform setup when app is ready', async () => {
      const whenReadyCallback =
        (app.whenReady as jest.Mock).mock.calls[0]?.[0] ||
        (app.whenReady as jest.Mock).mock.results[0]?.value;
      if (typeof whenReadyCallback === 'function') await whenReadyCallback();
      else if (whenReadyCallback && typeof whenReadyCallback.then === 'function') {
        const resolvedCallback = await whenReadyCallback;
        if (typeof resolvedCallback === 'function') await resolvedCallback();
      }
      expect(Tray).toHaveBeenCalled();
    });
  });
});

// Ensure any utility functions or types specific to testing main.ts are also exported or defined here if needed.

export {}; // Make this file a module
