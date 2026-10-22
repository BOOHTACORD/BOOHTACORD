CREATE TABLE IF NOT EXISTS support_contact_configuration (
    singleton BOOLEAN PRIMARY KEY DEFAULT true CHECK (singleton),
    support_account_id UUID REFERENCES users(id) ON DELETE SET NULL,
    revision BIGINT NOT NULL DEFAULT 1 CHECK (revision > 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO support_contact_configuration(singleton) VALUES (true) ON CONFLICT (singleton) DO NOTHING;
