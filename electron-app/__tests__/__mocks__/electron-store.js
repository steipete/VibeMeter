// __tests__/__mocks__/electron-store.js

const Store = jest.fn().mockImplementation(() => {
  const storeData = {};

  return {
    get: jest.fn((key, defaultValue) => {
      return Object.prototype.hasOwnProperty.call(storeData, key) ? storeData[key] : defaultValue;
    }),
    set: jest.fn((key, value) => {
      storeData[key] = value;
    }),
    delete: jest.fn(key => {
      delete storeData[key];
    }),
    clear: jest.fn(() => {
      for (const key in storeData) {
        delete storeData[key];
      }
    }),
    // You can add other methods if your code uses them, like has(), path, etc.
    // For now, keeping it to the ones used by main.js in checkLimitsAndNotify
    _storeData: storeData, // Expose for test inspection if necessary
  };
});

module.exports = Store;
