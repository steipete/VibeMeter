"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.default = {
    getPassword: jest.fn(() => Promise.resolve('mock-token')),
    setPassword: jest.fn(() => Promise.resolve()),
    deletePassword: jest.fn(() => Promise.resolve(true)),
};
//# sourceMappingURL=keytar.js.map