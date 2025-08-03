-- Production-grade Candidate table for recruitment system (DeNormalized)
CREATE TABLE IF NOT EXISTS Candidate (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Internal unique identifier for candidate',
    uuid CHAR(36) NOT NULL UNIQUE COMMENT 'UUID for sharding',
    name VARCHAR(100) NOT NULL COMMENT 'Full name of candidate',
    email VARCHAR(100) NOT NULL UNIQUE COMMENT 'Email address, must be unique',
    phone VARCHAR(15) COMMENT 'Phone number',
    resume TEXT COMMENT 'Resume or CV text',
    status ENUM('applied', 'interviewed', 'hired', 'rejected', 'archived') DEFAULT 'applied' COMMENT 'Current status in recruitment pipeline',
    privacy ENUM('public', 'private', 'internal') DEFAULT 'public' COMMENT 'Privacy setting for candidate profile',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    is_deleted BOOLEAN DEFAULT FALSE COMMENT 'Soft-delete flag for logical deletion',
    version INT DEFAULT 0 COMMENT 'Optimistic locking version',
    employer_name VARCHAR(100) COMMENT 'Denormalized employer name',
    change_log JSON COMMENT 'Change log for audit',
    INDEX idx_candidate_email (email),
    INDEX idx_candidate_status (status),
    INDEX idx_candidate_created_at (created_at),
    INDEX idx_candidate_status_created_at (status, created_at, name, email) -- Composite index for status, created_at, name, and email
)
ENGINE=MyRocks
DEFAULT CHARSET=utf8mb4
ROW_FORMAT=COMPRESSED
COMMENT='Stores candidate profiles for recruitment system'
PARTITION BY RANGE (YEAR(created_at)) (
    PARTITION p0 VALUES LESS THAN (2020),
    PARTITION p1 VALUES LESS THAN (2025),
    PARTITION p2 VALUES LESS THAN MAXVALUE
);


-- Normalized Skills Table
CREATE TABLE IF NOT EXISTS Skill (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique skill identifier',
    name VARCHAR(100) NOT NULL UNIQUE COMMENT 'Skill name',
    category VARCHAR(50) COMMENT 'Skill category (e.g., programming, language)'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Master list of skills';

-- Junction table for Candidate <-> Skill (many-to-many)
CREATE TABLE IF NOT EXISTS CandidateSkill (
    candidate_id BIGINT UNSIGNED NOT NULL COMMENT 'FK to Candidate',
    skill_id INT UNSIGNED NOT NULL COMMENT 'FK to Skill',
    proficiency ENUM('beginner','intermediate','advanced','expert') DEFAULT 'beginner' COMMENT 'Skill proficiency',
    years_experience DECIMAL(4,1) COMMENT 'Years of experience',
    PRIMARY KEY (candidate_id, skill_id),
    FOREIGN KEY (candidate_id) REFERENCES Candidate(id) ON DELETE CASCADE,
    FOREIGN KEY (skill_id) REFERENCES Skill(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Links candidates to their skills';

-- Normalized Education Table
CREATE TABLE IF NOT EXISTS Education (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique education record',
    candidate_id BIGINT UNSIGNED NOT NULL COMMENT 'FK to Candidate',
    institution VARCHAR(100) NOT NULL COMMENT 'School/University name',
    degree VARCHAR(100) COMMENT 'Degree or certification',
    field VARCHAR(100) COMMENT 'Field of study',
    start_year YEAR COMMENT 'Start year',
    end_year YEAR COMMENT 'End year',
    FOREIGN KEY (candidate_id) REFERENCES Candidate(id) ON DELETE CASCADE,
    INDEX idx_education_institution_start (institution, start_year) -- Composite index for institution and start_year
    -- Composite index for filtering by institution and start year
    CREATE INDEX idx_education_institution_start ON Education (institution, start_year)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Candidate education history';

-- Normalized Experience Table
CREATE TABLE IF NOT EXISTS Experience (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique experience record',
    candidate_id BIGINT UNSIGNED NOT NULL COMMENT 'FK to Candidate',
    company VARCHAR(100) NOT NULL COMMENT 'Company name',
    title VARCHAR(100) NOT NULL COMMENT 'Job title',
    start_date DATE COMMENT 'Start date',
    end_date DATE COMMENT 'End date',
    description TEXT COMMENT 'Role description',
    FOREIGN KEY (candidate_id) REFERENCES Candidate(id) ON DELETE CASCADE,
    INDEX idx_experience_company_start (company, start_date) -- Composite index for company and start_date
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Candidate work experience';


-- Production-grade Employers/Clients table
CREATE TABLE IF NOT EXISTS Employer (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Internal unique identifier for employer/client',
    uuid CHAR(36) NOT NULL UNIQUE COMMENT 'External UUID for deduplication and security',
    name VARCHAR(100) NOT NULL UNIQUE COMMENT 'Employer name (e.g., Google, Stripe)',
    industry VARCHAR(100) COMMENT 'Industry sector',
    location VARCHAR(100) COMMENT 'Headquarters or main location',
    website VARCHAR(255) COMMENT 'Company website',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    INDEX idx_employer_name (name),
    INDEX idx_employer_industry (industry)
)
ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COMMENT='Stores employer/client profiles for recruitment system';


-- Production-grade Job table
CREATE TABLE IF NOT EXISTS Job (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Internal unique identifier for job',
    uuid CHAR(36) NOT NULL UNIQUE COMMENT 'External UUID for deduplication and security',
    employer_id BIGINT UNSIGNED NOT NULL COMMENT 'FK to Employer',
    title VARCHAR(100) NOT NULL COMMENT 'Job title',
    description TEXT COMMENT 'Detailed job description',
    location VARCHAR(100) COMMENT 'Job location',
    salary_min DECIMAL(12,2) COMMENT 'Minimum salary',
    salary_max DECIMAL(12,2) COMMENT 'Maximum salary',
    status ENUM('open', 'closed', 'paused', 'filled') DEFAULT 'open' COMMENT 'Job status',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    INDEX idx_job_title (title),
    INDEX idx_job_status (status),
    INDEX idx_job_location (location),
    INDEX idx_job_status_created_at (status, created_at), -- Composite index for status and created_at
    FOREIGN KEY (employer_id) REFERENCES Employer(id) ON DELETE CASCADE
)
ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COMMENT='Stores job postings for recruitment system';


-- Production-grade Application table
CREATE TABLE IF NOT EXISTS Application (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Internal unique identifier for application',
    uuid CHAR(36) NOT NULL UNIQUE COMMENT 'External UUID for deduplication and security',
    candidate_id BIGINT UNSIGNED NOT NULL COMMENT 'FK to Candidate',
    job_id BIGINT UNSIGNED NOT NULL COMMENT 'FK to Job',
    recruiter_id BIGINT UNSIGNED COMMENT 'FK to Recruiter (optional)',
    status ENUM('applied', 'screening', 'interview', 'offered', 'hired', 'rejected', 'withdrawn') DEFAULT 'applied' COMMENT 'Current status of application',
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Application submission timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    is_deleted BOOLEAN DEFAULT FALSE COMMENT 'Soft-delete flag for logical deletion',
    INDEX idx_application_status (status),
    INDEX idx_application_applied_at (applied_at),
    INDEX idx_application_status_created_at (status, applied_at), -- Composite index for status and created_at
    FOREIGN KEY (candidate_id) REFERENCES Candidate(id) ON DELETE CASCADE,
    FOREIGN KEY (job_id) REFERENCES Job(id) ON DELETE CASCADE
    -- recruiter_id FK can be added after Recruiter table is defined
)
ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COMMENT='Tracks candidate applications to jobs'
PARTITION BY RANGE (YEAR(applied_at)) (
    PARTITION p0 VALUES LESS THAN (2020),
    PARTITION p1 VALUES LESS THAN (2025),
    PARTITION p2 VALUES LESS THAN MAXVALUE
);


-- Production-grade Recruiter table
CREATE TABLE IF NOT EXISTS Recruiter (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Internal unique identifier for recruiter',
    uuid CHAR(36) NOT NULL UNIQUE COMMENT 'External UUID for deduplication and security',
    name VARCHAR(100) NOT NULL COMMENT 'Recruiter full name',
    email VARCHAR(100) NOT NULL UNIQUE COMMENT 'Recruiter email address',
    phone VARCHAR(15) COMMENT 'Recruiter phone number',
    status ENUM('active', 'inactive', 'archived') DEFAULT 'active' COMMENT 'Recruiter account status',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    INDEX idx_recruiter_email (email),
    INDEX idx_recruiter_status (status)
)
ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COMMENT='Stores recruiter profiles for recruitment system';


-- Production-grade Interview table
CREATE TABLE IF NOT EXISTS Interview (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Internal unique identifier for interview',
    uuid CHAR(36) NOT NULL UNIQUE COMMENT 'External UUID for deduplication and security',
    application_id BIGINT UNSIGNED NOT NULL COMMENT 'FK to Application',
    recruiter_id BIGINT UNSIGNED COMMENT 'FK to Recruiter (optional)',
    scheduled_at DATETIME NOT NULL COMMENT 'Scheduled date and time for interview',
    feedback TEXT COMMENT 'Feedback from interview',
    status ENUM('scheduled', 'completed', 'cancelled', 'no_show') DEFAULT 'scheduled' COMMENT 'Interview status',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    INDEX idx_interview_status (status),
    INDEX idx_interview_scheduled_at (scheduled_at),
    FOREIGN KEY (application_id) REFERENCES Application(id) ON DELETE CASCADE
    -- recruiter_id FK can be added after Recruiter table is defined
)
ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COMMENT='Tracks interviews for candidate applications';


-- Production-grade Offer table
CREATE TABLE IF NOT EXISTS Offer (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Internal unique identifier for offer',
    uuid CHAR(36) NOT NULL UNIQUE COMMENT 'External UUID for deduplication and security',
    application_id BIGINT UNSIGNED NOT NULL COMMENT 'FK to Application',
    salary DECIMAL(12,2) NOT NULL COMMENT 'Offered salary',
    benefits TEXT COMMENT 'Benefits offered',
    status ENUM('extended', 'accepted', 'declined', 'expired', 'withdrawn') DEFAULT 'extended' COMMENT 'Offer status',
    extended_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Offer extension timestamp',
    responded_at TIMESTAMP NULL COMMENT 'Timestamp of candidate response',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    INDEX idx_offer_status (status),
    INDEX idx_offer_extended_at (extended_at),
    FOREIGN KEY (application_id) REFERENCES Application(id) ON DELETE CASCADE
)
ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COMMENT='Tracks job offers extended to candidates';


-- Production-grade Event/Audit table
CREATE TABLE IF NOT EXISTS Event (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Internal unique identifier for event',
    uuid CHAR(36) NOT NULL UNIQUE COMMENT 'External UUID for deduplication and security',
    entity_type ENUM('candidate', 'employer', 'job', 'application', 'recruiter', 'interview', 'offer') NOT NULL COMMENT 'Type of entity affected',
    entity_id BIGINT UNSIGNED NOT NULL COMMENT 'ID of the affected entity',
    action VARCHAR(50) NOT NULL COMMENT 'Action performed (e.g., create, update, delete)',
    performed_by BIGINT UNSIGNED COMMENT 'User/Recruiter who performed the action',
    performed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Timestamp of the event',
    details TEXT COMMENT 'Additional details or JSON payload',
    INDEX idx_event_entity_type (entity_type),
    INDEX idx_event_performed_at (performed_at),
    INDEX idx_event_status_performed_at (entity_type, performed_at) -- Composite index for status and performed_at
)
ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COMMENT='Tracks audit events and changes for compliance and debugging';


-- Reference table for status values (example for extensibility/localization)
CREATE TABLE IF NOT EXISTS Status (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique status identifier',
    entity_type ENUM('candidate', 'job', 'application', 'recruiter', 'interview', 'offer') NOT NULL COMMENT 'Type of entity',
    code VARCHAR(50) NOT NULL COMMENT 'Status code (e.g., applied, hired)',
    label VARCHAR(100) NOT NULL COMMENT 'Human-readable label',
    description TEXT COMMENT 'Description or localization',
    UNIQUE KEY uniq_status_entity_code (entity_type, code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Reference table for status values, extensible and localizable';

-- CandidateNote Table: Private notes for candidate profiles
CREATE TABLE IF NOT EXISTS CandidateNote (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique note identifier',
    candidate_id BIGINT UNSIGNED NOT NULL COMMENT 'FK to Candidate',
    recruiter_id BIGINT UNSIGNED NOT NULL COMMENT 'FK to Recruiter',
    note TEXT NOT NULL COMMENT 'Note content',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Note creation timestamp',
    FOREIGN KEY (candidate_id) REFERENCES Candidate(id) ON DELETE CASCADE,
    FOREIGN KEY (recruiter_id) REFERENCES Recruiter(id) ON DELETE CASCADE,
    INDEX idx_candidatenote_candidate (candidate_id),
    INDEX idx_candidatenote_recruiter (recruiter_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Private notes for candidate profiles';

-- CandidateTag Table: Tagging candidates for search/organization
CREATE TABLE IF NOT EXISTS CandidateTag (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique tag identifier',
    candidate_id BIGINT UNSIGNED NOT NULL COMMENT 'FK to Candidate',
    tag VARCHAR(50) NOT NULL COMMENT 'Tag value',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Tag creation timestamp',
    FOREIGN KEY (candidate_id) REFERENCES Candidate(id) ON DELETE CASCADE,
    INDEX idx_candidatetag_candidate (candidate_id),
    INDEX idx_candidatetag_tag (tag)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Tags for candidate search and organization';

-- CandidateDocument Table: Additional documents for candidates
CREATE TABLE IF NOT EXISTS CandidateDocument (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique document identifier',
    candidate_id BIGINT UNSIGNED NOT NULL COMMENT 'FK to Candidate',
    url VARCHAR(255) NOT NULL COMMENT 'Document file URL',
    type ENUM('cover_letter', 'certificate', 'portfolio', 'other') NOT NULL COMMENT 'Document type',
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Upload timestamp',
    FOREIGN KEY (candidate_id) REFERENCES Candidate(id) ON DELETE CASCADE,
    INDEX idx_candidatedoc_candidate (candidate_id),
    INDEX idx_candidatedoc_type (type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Additional documents for candidate profiles';

-- ApplicationStage Table: Tracks multi-stage application progress
CREATE TABLE IF NOT EXISTS ApplicationStage (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique stage identifier',
    application_id BIGINT UNSIGNED NOT NULL COMMENT 'FK to Application',
    stage ENUM('screening', 'interview', 'offer', 'hired', 'rejected', 'withdrawn') NOT NULL COMMENT 'Application stage',
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Stage start timestamp',
    completed_at TIMESTAMP COMMENT 'Stage completion timestamp',
    FOREIGN KEY (application_id) REFERENCES Application(id) ON DELETE CASCADE,
    INDEX idx_appstage_application (application_id),
    INDEX idx_appstage_stage (stage)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Tracks multi-stage application progress';

-- RecruiterActivity Table: Audits recruiter actions for compliance/analytics
CREATE TABLE IF NOT EXISTS RecruiterActivity (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique activity identifier',
    recruiter_id BIGINT UNSIGNED NOT NULL COMMENT 'FK to Recruiter',
    action VARCHAR(50) NOT NULL COMMENT 'Action performed',
    entity_type ENUM('candidate', 'job', 'application', 'interview', 'offer') NOT NULL COMMENT 'Entity type',
    entity_id BIGINT UNSIGNED NOT NULL COMMENT 'ID of affected entity',
    details TEXT COMMENT 'Additional details or JSON payload',
    performed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Action timestamp',
    FOREIGN KEY (recruiter_id) REFERENCES Recruiter(id) ON DELETE CASCADE,
    INDEX idx_recruiteractivity_recruiter (recruiter_id),
    INDEX idx_recruiteractivity_entity (entity_type, entity_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Audits recruiter actions for compliance and analytics';

-- Interviewer Table: Tracks interviewers (internal/external)
CREATE TABLE IF NOT EXISTS Interviewer (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique interviewer identifier',
    name VARCHAR(100) NOT NULL COMMENT 'Interviewer name',
    email VARCHAR(100) NOT NULL COMMENT 'Interviewer email',
    type ENUM('internal', 'external') DEFAULT 'internal' COMMENT 'Interviewer type',
    status ENUM('active', 'inactive') DEFAULT 'active' COMMENT 'Interviewer status',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    INDEX idx_interviewer_email (email),
    INDEX idx_interviewer_type (type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Tracks interviewers for interviews';

-- InterviewSchedule Table: Stores interview slots and availability
CREATE TABLE IF NOT EXISTS InterviewSchedule (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique schedule identifier',
    interview_id BIGINT UNSIGNED NOT NULL COMMENT 'FK to Interview',
    interviewer_id BIGINT UNSIGNED NOT NULL COMMENT 'FK to Interviewer',
    scheduled_at DATETIME NOT NULL COMMENT 'Scheduled date and time',
    status ENUM('pending', 'confirmed', 'cancelled') DEFAULT 'pending' COMMENT 'Schedule status',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Record creation timestamp',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Last update timestamp',
    FOREIGN KEY (interview_id) REFERENCES Interview(id) ON DELETE CASCADE,
    FOREIGN KEY (interviewer_id) REFERENCES Interviewer(id) ON DELETE CASCADE,
    INDEX idx_interviewschedule_interview (interview_id),
    INDEX idx_interviewschedule_interviewer (interviewer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Stores interview schedules and interviewer availability';

-- Notification Table: Sends notifications to interviewers
CREATE TABLE IF NOT EXISTS Notification (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Unique notification identifier',
    user_id BIGINT UNSIGNED COMMENT 'FK to User (recipient)',
    interviewer_id BIGINT UNSIGNED COMMENT 'FK to Interviewer (recipient)',
    type ENUM('interview_scheduled', 'interview_cancelled', 'reminder', 'other') NOT NULL COMMENT 'Notification type',
    entity_type ENUM('interview', 'application', 'candidate', 'other') NOT NULL COMMENT 'Entity type',
    entity_id BIGINT UNSIGNED COMMENT 'ID of affected entity',
    message VARCHAR(255) NOT NULL COMMENT 'Notification message',
    is_read BOOLEAN DEFAULT FALSE COMMENT 'Read status',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Notification creation timestamp',
    FOREIGN KEY (user_id) REFERENCES User(id) ON DELETE CASCADE,
    FOREIGN KEY (interviewer_id) REFERENCES Interviewer(id) ON DELETE CASCADE,
    INDEX idx_notification_user (user_id),
    INDEX idx_notification_interviewer (interviewer_id),
    INDEX idx_notification_entity (entity_type, entity_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='Notifications for interviewers and users';

CREATE TABLE ArchivedCandidate LIKE Candidate;

CREATE INDEX idx_candidate_status_applied ON Candidate (status)
WHERE status = 'applied';

ALTER TABLE Candidate MODIFY uuid CHAR(36) NOT NULL UNIQUE COMMENT 'UUID for sharding';

ALTER TABLE Candidate DISABLE KEYS;
-- Perform bulk insert
ALTER TABLE Candidate ENABLE KEYS;

SELECT /*+ INDEX(Candidate idx_candidate_status_created_at) */ * 
FROM Candidate 
WHERE status = 'applied';

INSERT INTO Event (entity_type, entity_id, action, performed_at)
VALUES ('candidate', 123, 'update', NOW())
ON DUPLICATE KEY UPDATE performed_at = NOW();

ALTER TABLE Candidate AUTO_INCREMENT = 1000000;
