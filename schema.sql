-- -----------------------------------------------------
-- Table `equipment`
-- Stores information about the NI test equipment.
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `equipment` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `serial_number` VARCHAR(100) NOT NULL,
  `model` VARCHAR(100) NULL,
  `name` VARCHAR(100) NULL COMMENT 'User-friendly name, e.g., "Lab A - Scope 3"',
  `last_calibration_date` DATE NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uq_serial_number` (`serial_number` ASC)
) 
COMMENT='Stores information about individual pieces of test equipment.';


-- -----------------------------------------------------
-- Table `test_sessions`
-- Records each test run, linking it to a piece of equipment.
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `test_sessions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `equipment_id` INT UNSIGNED NOT NULL,
  `test_name` VARCHAR(100) NOT NULL COMMENT 'Name of the test profile being run.',
  `status` ENUM('scheduled', 'running', 'completed', 'failed', 'aborted') NOT NULL DEFAULT 'scheduled',
  `start_time` TIMESTAMP(6) NULL,
  `end_time` TIMESTAMP(6) NULL,
  `notes` TEXT NULL COMMENT 'User-supplied notes or observations for the session.',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `fk_test_sessions_equipment_idx` (`equipment_id` ASC),
  INDEX `idx_start_time` (`start_time` DESC),
  INDEX `idx_status` (`status` ASC),
  CONSTRAINT `fk_test_sessions_equipment`
    FOREIGN KEY (`equipment_id`)
    REFERENCES `equipment` (`id`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) 
COMMENT='Records metadata for each test session.';


-- -----------------------------------------------------
-- Table `session_summary_metrics`
-- Stores the key aggregated metrics calculated from the raw data stream for a session.
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `session_summary_metrics` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `session_id` BIGINT UNSIGNED NOT NULL,
  `metric_definition_id` INT UNSIGNED NOT NULL,
  `metric_value` DOUBLE NOT NULL,
  `metadata` JSON NULL COMMENT 'Stores context, e.g., { "window_minutes": 5, "source_channel": "A" }',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `fk_summary_metrics_test_sessions_idx` (`session_id` ASC),
  INDEX `fk_summary_metrics_metric_definitions_idx` (`metric_definition_id` ASC),
  UNIQUE INDEX `uq_session_metric` (`session_id` ASC, `metric_definition_id` ASC, `metadata`(191)),
  CONSTRAINT `fk_summary_metrics_test_sessions`
    FOREIGN KEY (`session_id`)
    REFERENCES `test_sessions` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_summary_metrics_metric_definitions`
    FOREIGN KEY (`metric_definition_id`)
    REFERENCES `metric_definitions` (`id`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) 
COMMENT='Stores aggregated results and summary statistics for a test session.';


-- -----------------------------------------------------
-- Table `metric_definitions`
-- Lookup table for all possible metrics to ensure consistency.
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `metric_definitions` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL COMMENT 'e.g., mean, std_dev, min, max, p95',
  `unit` VARCHAR(50) NULL COMMENT 'e.g., Volts, Amps, Hz',
  `description` TEXT NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uq_metric_name` (`name` ASC)
) 
COMMENT='Lookup table for metric types, ensuring data consistency.';


-- -----------------------------------------------------
-- Table `detected_events`
-- Captures specific, noteworthy events from the data stream.
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `detected_events` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `session_id` BIGINT UNSIGNED NOT NULL,
  `event_definition_id` INT UNSIGNED NOT NULL,
  `event_timestamp` TIMESTAMP(6) NOT NULL,
  `value_at_event` DOUBLE NULL,
  `details` JSON NULL COMMENT 'e.g., { "threshold": 3.3, "anomaly_score": 0.98 }',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `fk_detected_events_test_sessions_idx` (`session_id` ASC),
  INDEX `fk_detected_events_event_definitions_idx` (`event_definition_id` ASC),
  INDEX `idx_event_timestamp` (`event_timestamp` DESC),
  CONSTRAINT `fk_detected_events_test_sessions`
    FOREIGN KEY (`session_id`)
    REFERENCES `test_sessions` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_detected_events_event_definitions`
    FOREIGN KEY (`event_definition_id`)
    REFERENCES `event_definitions` (`id`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
) 
COMMENT='Stores discrete events detected during a test session.';


-- -----------------------------------------------------
-- Table `event_definitions`
-- Lookup table for all possible event types to ensure consistency.
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `event_definitions` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `type` VARCHAR(100) NOT NULL COMMENT 'e.g., THRESHOLD_EXCEEDED, ANOMALY_DETECTED',
  `description` TEXT NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uq_event_type` (`type` ASC)
) 
COMMENT='Lookup table for event types, ensuring data consistency.';


-- -----------------------------------------------------
-- Table `session_array_results`
-- Stores larger, multi-dimensional results like a 40x20 float array.
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `session_array_results` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `session_id` BIGINT UNSIGNED NOT NULL,
  `result_name` VARCHAR(100) NOT NULL COMMENT 'A unique name for this result set, e.g., "final_waveform_capture"',
  `result_data` JSON NOT NULL COMMENT 'The 2D array of floats, stored as a JSON array of arrays.',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `fk_session_array_results_test_sessions_idx` (`session_id` ASC),
  UNIQUE INDEX `uq_session_result_name` (`session_id` ASC, `result_name` ASC),
  CONSTRAINT `fk_session_array_results_test_sessions`
    FOREIGN KEY (`session_id`)
    REFERENCES `test_sessions` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) 
COMMENT='Stores multi-dimensional array results for a test session.';


-- -----------------------------------------------------
-- Table `raw_stream_batches`
-- Stores the raw, unprocessed batch data from the stream for auditing.
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `raw_stream_batches` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `session_id` BIGINT UNSIGNED NOT NULL,
  `received_at` TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `raw_payload` JSON NOT NULL COMMENT 'The exact JSON payload received from the Redis stream.',
  `processing_status` ENUM('pending', 'processed', 'error') NOT NULL DEFAULT 'pending' COMMENT 'Tracks the processing state of this batch.',
  PRIMARY KEY (`id`),
  INDEX `fk_raw_stream_batches_test_sessions_idx` (`session_id` ASC),
  INDEX `idx_received_at` (`received_at` DESC),
  INDEX `idx_processing_status` (`processing_status` ASC),
  CONSTRAINT `fk_raw_stream_batches_test_sessions`
    FOREIGN KEY (`session_id`)
    REFERENCES `test_sessions` (`id`)
    ON DELETE CASCADE
    ON UPDATE CASCADE
) 
COMMENT='Audit log of raw batch payloads received from the data stream.';
