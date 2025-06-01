export default {
  getPassword: jest.fn(() => Promise.resolve('mock-token')),
  setPassword: jest.fn(() => Promise.resolve()),
  deletePassword: jest.fn(() => Promise.resolve(true)),
};
