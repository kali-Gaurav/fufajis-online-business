const request = require('supertest');
const express = require('express');

// Create a basic express app to test the router in isolation
const app = express();
app.use(express.json());

// Mock the OperationalAuthService and Supabase
jest.mock('../src/services/OperationalAuthService', () => ({
  verifyCredentials: jest.fn(),
  generateAccessToken: jest.fn(),
  generateRefreshToken: jest.fn(),
  verifyToken: jest.fn(),
  revokeToken: jest.fn(),
}));

jest.mock('@supabase/supabase-js', () => ({
  createClient: jest.fn(() => ({
    from: jest.fn().mockReturnThis(),
    insert: jest.fn().mockResolvedValue({}),
    select: jest.fn().mockReturnThis(),
    eq: jest.fn().mockReturnThis(),
    single: jest.fn(),
  })),
}));

const authOperational = require('../src/routes/auth_operational_login');
app.use('/auth', authOperational);

const OperationalAuthService = require('../src/services/OperationalAuthService');

describe('Auth Operational Routes', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('POST /auth/operational-login', () => {
    it('should return 400 if login_id or pin is missing', async () => {
      const res = await request(app).post('/auth/operational-login').send({});
      expect(res.status).toBe(400);
      expect(res.body.success).toBe(false);
      expect(res.body.error).toBe('missing_credentials');
    });

    it('should return 401 for invalid credentials', async () => {
      OperationalAuthService.verifyCredentials.mockResolvedValue(null);

      const res = await request(app)
        .post('/auth/operational-login')
        .send({ login_id: 'owner@test.com', pin: 'wrong' });

      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
      expect(res.body.error).toBe('invalid_credentials');
    });

    it('should return 200 and tokens on successful login', async () => {
      OperationalAuthService.verifyCredentials.mockResolvedValue({
        id: 'user-123',
        name: 'Test Owner',
        role: 'owner',
      });
      OperationalAuthService.generateAccessToken.mockReturnValue('access_token_123');
      OperationalAuthService.generateRefreshToken.mockReturnValue('refresh_token_123');

      const res = await request(app)
        .post('/auth/operational-login')
        .send({ login_id: 'owner@test.com', pin: 'correct' });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.token).toBe('access_token_123');
      expect(res.body.refreshToken).toBe('refresh_token_123');
      expect(res.body.user.role).toBe('owner');
      expect(res.body.permissions).toContain('view_all_orders');
    });
  });

  describe('POST /auth/operational-logout', () => {
    it('should return 401 if token is missing', async () => {
      const res = await request(app).post('/auth/operational-logout').send({});
      expect(res.status).toBe(401);
      expect(res.body.success).toBe(false);
      expect(res.body.error).toBe('unauthenticated');
    });

    it('should revoke token and return 200', async () => {
      OperationalAuthService.verifyToken.mockResolvedValue({ sub: 'user-123' });

      const res = await request(app)
        .post('/auth/operational-logout')
        .set('Authorization', 'Bearer access_token_123')
        .send({ revokeAll: false });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(OperationalAuthService.revokeToken).toHaveBeenCalledWith(
        'user-123',
        'access_token_123',
        'logout'
      );
    });
  });
});
