-- Create MLflow database
CREATE DATABASE mlflowdb;

-- Create users table for authentication
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    is_admin BOOLEAN DEFAULT false,
    quota_tier VARCHAR(50) DEFAULT 'default',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP
);

-- Create sessions table
CREATE TABLE IF NOT EXISTS sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    ip_address INET
);

-- Create environments table
CREATE TABLE IF NOT EXISTS environments (
    id SERIAL PRIMARY KEY,
    container_id VARCHAR(255) UNIQUE NOT NULL,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    environment_type VARCHAR(100) NOT NULL,
    environment_name VARCHAR(255),
    status VARCHAR(50) DEFAULT 'creating',
    gpu_count INTEGER DEFAULT 0,
    memory_mb INTEGER,
    cpu_cores DECIMAL(3,1),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP,
    stopped_at TIMESTAMP,
    access_url VARCHAR(500),
    port_mapping JSONB
);

-- Create resource_usage table for tracking
CREATE TABLE IF NOT EXISTS resource_usage (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    environment_id INTEGER REFERENCES environments(id) ON DELETE CASCADE,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    gpu_utilization DECIMAL(5,2),
    memory_used_mb INTEGER,
    cpu_percent DECIMAL(5,2),
    storage_used_gb DECIMAL(10,2)
);

-- Create audit_logs table
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(255) NOT NULL,
    resource_type VARCHAR(100),
    resource_id VARCHAR(255),
    details JSONB,
    ip_address INET,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX idx_sessions_token ON sessions(session_token);
CREATE INDEX idx_sessions_expires ON sessions(expires_at);
CREATE INDEX idx_environments_user ON environments(user_id);
CREATE INDEX idx_environments_status ON environments(status);
CREATE INDEX idx_resource_usage_user_time ON resource_usage(user_id, timestamp);
CREATE INDEX idx_audit_logs_user_time ON audit_logs(user_id, timestamp);

-- Create default admin user (password: admin123 - should be changed immediately)
INSERT INTO users (username, email, password_hash, is_admin, quota_tier)
VALUES ('admin', 'admin@localhost', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewKyNiLXCJRD7XuC', true, 'enterprise')
ON CONFLICT DO NOTHING; 