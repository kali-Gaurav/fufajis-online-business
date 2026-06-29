-- Authentication and Security Audit Database Schemas

-- Table for tracking user logins and session statuses
CREATE TABLE IF NOT EXISTS login_logs (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(128) NOT NULL,
    device_id VARCHAR(128),
    ip_address VARCHAR(45),
    login_status VARCHAR(20) NOT NULL, -- e.g., 'SUCCESS', 'FAILED_PIN', 'FAILED_OTP'
    failure_reason VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table for structural role management audits
CREATE TABLE IF NOT EXISTS user_roles (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(128) NOT NULL,
    role VARCHAR(50) NOT NULL,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Audit Trail for Auth activity events
CREATE TABLE IF NOT EXISTS auth_audit_logs (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(128),
    action VARCHAR(100) NOT NULL, -- e.g. 'LOGIN', 'LOGOUT', 'SESSION_REVOCATION'
    details TEXT,
    ip_address VARCHAR(45),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes to optimize analytical performance queries
CREATE INDEX IF NOT EXISTS idx_login_logs_user ON login_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_user ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_auth_audit_logs_user ON auth_audit_logs(user_id);
