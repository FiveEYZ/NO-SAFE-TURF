-- NO SAFE TURF schema v1. MariaDB 10.11+, InnoDB, utf8mb4.
-- Select a dedicated empty database before applying this file.
-- This migration never drops tables, resets state, or creates database users.
-- The adapter initializes nst_meta with its computed Europe/Stockholm deadline.

CREATE TABLE IF NOT EXISTS nst_schema_migrations (
    version INT UNSIGNED NOT NULL PRIMARY KEY,
    applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS nst_meta (
    id TINYINT UNSIGNED NOT NULL PRIMARY KEY,
    revision BIGINT UNSIGNED NOT NULL,
    season BIGINT UNSIGNED NOT NULL,
    next_wipe BIGINT NOT NULL,
    extra LONGTEXT NOT NULL CHECK (JSON_VALID(extra)),
    CONSTRAINT nst_meta_singleton CHECK (id = 1),
    CONSTRAINT nst_meta_valid_season CHECK (season >= 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS nst_players (
    entity_id VARCHAR(128) NOT NULL PRIMARY KEY,
    payload LONGTEXT NOT NULL CHECK (JSON_VALID(payload))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS nst_player_items (
    owner_id VARCHAR(128) NOT NULL,
    item_id VARCHAR(128) NOT NULL,
    quantity BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (owner_id, item_id),
    CONSTRAINT nst_player_items_owner FOREIGN KEY (owner_id)
        REFERENCES nst_players(entity_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS nst_gangs (
    entity_id VARCHAR(128) NOT NULL PRIMARY KEY,
    payload LONGTEXT NOT NULL CHECK (JSON_VALID(payload))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS nst_gang_items (
    owner_id VARCHAR(128) NOT NULL,
    item_id VARCHAR(128) NOT NULL,
    quantity BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (owner_id, item_id),
    CONSTRAINT nst_gang_items_owner FOREIGN KEY (owner_id)
        REFERENCES nst_gangs(entity_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS nst_territories (
    entity_id VARCHAR(128) NOT NULL PRIMARY KEY,
    payload LONGTEXT NOT NULL CHECK (JSON_VALID(payload))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS nst_robberies (
    entity_id VARCHAR(128) NOT NULL PRIMARY KEY,
    payload LONGTEXT NOT NULL CHECK (JSON_VALID(payload))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS nst_hideouts (
    entity_id VARCHAR(128) NOT NULL PRIMARY KEY,
    payload LONGTEXT NOT NULL CHECK (JSON_VALID(payload))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS nst_drops (
    entity_id VARCHAR(128) NOT NULL PRIMARY KEY,
    payload LONGTEXT NOT NULL CHECK (JSON_VALID(payload))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS nst_alerts (
    entity_id VARCHAR(128) NOT NULL PRIMARY KEY,
    payload LONGTEXT NOT NULL CHECK (JSON_VALID(payload))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Persistent account data is independent of seasonal players and gangs.
CREATE TABLE IF NOT EXISTS nst_accounts (
    identifier VARCHAR(128) NOT NULL PRIMARY KEY,
    admin BOOLEAN NOT NULL DEFAULT FALSE,
    settings LONGTEXT NOT NULL CHECK (JSON_VALID(settings))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS nst_bans (
    identifier VARCHAR(128) NOT NULL PRIMARY KEY,
    reason TEXT NOT NULL,
    expires_at BIGINT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS nst_settings (
    setting_key VARCHAR(128) NOT NULL PRIMARY KEY,
    value LONGTEXT NOT NULL CHECK (JSON_VALID(value))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Pre-wipe logical backups supplement, rather than replace, external DB backups.
CREATE TABLE IF NOT EXISTS nst_backups (
    backup_id VARCHAR(128) NOT NULL PRIMARY KEY,
    created_at BIGINT NOT NULL,
    revision BIGINT UNSIGNED NOT NULL,
    payload LONGTEXT NOT NULL CHECK (JSON_VALID(payload)),
    sha256 CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS nst_wipes (
    wipe_key VARCHAR(100) NOT NULL PRIMARY KEY,
    previous_season BIGINT UNSIGNED NOT NULL,
    completed_at BIGINT NOT NULL,
    backup_id VARCHAR(128) NOT NULL,
    CONSTRAINT nst_wipes_backup FOREIGN KEY (backup_id)
        REFERENCES nst_backups(backup_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS nst_season_history (
    season BIGINT UNSIGNED NOT NULL PRIMARY KEY,
    ended_at BIGINT NOT NULL,
    leaderboard LONGTEXT NOT NULL CHECK (JSON_VALID(leaderboard))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE IF NOT EXISTS nst_audit (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    at BIGINT NOT NULL,
    action VARCHAR(80) NOT NULL,
    actor VARCHAR(128) NOT NULL,
    revision BIGINT UNSIGNED NOT NULL,
    INDEX nst_audit_revision (revision),
    INDEX nst_audit_time (at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- MariaDB DDL commits implicitly. Record the version only after all DDL succeeds.
INSERT IGNORE INTO nst_schema_migrations (version) VALUES (1);
