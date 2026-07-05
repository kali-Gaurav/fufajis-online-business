const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// Mock Firebase Admin
jest.mock('../src/services/firebaseAdmin', () => ({
  db: {},
}));

// Setup mock supabase client BEFORE requiring the service
const mockSingle = jest.fn();
const mockEq = jest.fn();
const queryBuilder = {
  eq: mockEq,
  single: mockSingle,
};
mockEq.mockReturnValue(queryBuilder);
const mockSelect = jest.fn().mockReturnValue(queryBuilder);
const mockUpdate = jest.fn().mockReturnValue(queryBuilder);
const mockInsert = jest.fn().mockReturnValue(queryBuilder);

const mockSupabase = {
  from: jest.fn().mockReturnValue({
    select: mockSelect,
    update: mockUpdate,
    insert: mockInsert,
  }),
};

jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(() => mockSupabase),
}));

// Now require the service which will use the mocked Supabase
process.env.OPERATIONAL_JWT_SECRET = 'test_secret_key';
const OperationalAuthService = require('../src/services/OperationalAuthService');

describe('OperationalAuthService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockSingle.mockReset();
  });

  describe('verifyCredentials', () => {
    it('should return null if user account is locked', async () => {
      // Mock user is locked out (locked_until is in the future)
      mockSingle.mockResolvedValue({
        data: {
          id: 'user-1',
          login_id: 'test@example.com',
          locked_until: new Date(Date.now() + 10 * 60000).toISOString(), // 10 mins from now
          pin_hash: 'some_hash',
        },
        error: null,
      });

      const result = await OperationalAuthService.verifyCredentials('test@example.com', '1234');
      
      expect(result).toBeNull();
    });

    it('should increment failed logins on bad PIN and lock account on 5th try', async () => {
      mockSingle.mockResolvedValueOnce({
        data: {
          id: 'user-1',
          login_id: 'test@example.com',
          locked_until: null,
          pin_hash: 'hashed_1234',
          failed_login_count: 4, // 4 failed attempts previously
        },
        error: null,
      });
      
      // Mock internal select query for incrementing failed logins
      mockSingle.mockResolvedValueOnce({
        data: { failed_login_count: 4 },
        error: null
      });

      jest.spyOn(bcrypt, 'compare').mockResolvedValue(false);

      const result = await OperationalAuthService.verifyCredentials('test@example.com', 'wrong_pin');
      
      expect(result).toBeNull();
      // Verify update was called to set locked_until and failed count = 5
      expect(mockSupabase.from).toHaveBeenCalledWith('staff');
      expect(mockUpdate).toHaveBeenCalledWith(expect.objectContaining({
        failed_login_count: 5,
        locked_until: expect.any(String), // Should be set
      }));
    });
  });

  describe('verifyToken and Blacklist', () => {
    it('should throw an error if the token is blacklisted', async () => {
      // Generate a valid token
      const validToken = jwt.sign({ sub: 'user-1' }, 'test_secret_key');
      
      // Mock blacklist check to return a row (meaning it is blacklisted)
      mockSingle.mockResolvedValue({
        data: { id: 'blacklisted-entry' },
        error: null,
      });

      await expect(OperationalAuthService.verifyToken(validToken))
        .rejects
        .toThrow('Invalid or expired token'); // Service wraps all errors into this message
    });

    it('should verify successfully if the token is NOT blacklisted', async () => {
      const validToken = jwt.sign({ sub: 'user-1' }, 'test_secret_key');
      
      // Mock blacklist check to return NO row (meaning it is NOT blacklisted)
      mockSingle.mockResolvedValue({
        data: null,
        error: null,
      });

      const decoded = await OperationalAuthService.verifyToken(validToken);
      expect(decoded.sub).toBe('user-1');
    });
  });
});
