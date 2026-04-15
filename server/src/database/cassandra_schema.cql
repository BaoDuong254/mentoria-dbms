-- =============================================================================
-- MENTORIA — Apache Cassandra Schema
-- Migrated from: SQL Server (SQL.sql + trigger.sql)
-- =============================================================================
--
-- DESIGN PHILOSOPHY
-- -----------------
-- SQL Server relies on normalisation (26 tables), JOINs, triggers for derived
-- attributes, and stored procedures for complex queries.
--
-- Cassandra is a wide-column store with NO joins, NO foreign keys, and NO
-- multi-column ad-hoc filtering (without ALLOW FILTERING, which is costly).
-- We therefore follow *query-first modelling*:
--   1. Identify every distinct read access pattern.
--   2. Create one table per access pattern (denormalise as needed).
--   3. Write to multiple tables atomically using LOGGED BATCH.
--   4. Replace SQL triggers with application-level counter updates.
--   5. Replace stored-procedure aggregations with pre-aggregated tables.
--
-- PARTITION KEY DESIGN RULES USED HERE
-- -------------------------------------
--   • Partition key = the equality filter in the most common query.
--   • Clustering columns = range/order columns inside the partition.
--   • Avoid partitions > ~100 MB; bucket by time/category where needed.
--   • Duplicate data freely — storage is cheap, JOINs are not.
--
-- DATA TYPE MAPPING  (SQL Server → Cassandra)
-- -------------------------------------------
--   INT IDENTITY   → uuid  (application generates UUID v4 on insert)
--   NVARCHAR(n)    → text
--   NVARCHAR(MAX)  → text
--   DATETIME       → timestamp
--   DATE           → date
--   DECIMAL(10,2)  → decimal
--   BIT            → boolean
--
-- =============================================================================


-- =============================================================================
-- 1. KEYSPACE
-- =============================================================================
-- NetworkTopologyStrategy is preferred in production multi-DC deployments.
-- SimpleStrategy is fine for a single datacenter / local development.
-- replication_factor = 3 means each row is stored on 3 nodes (fault tolerant).

CREATE KEYSPACE IF NOT EXISTS mentoriadbms
WITH replication = {
    'class': 'NetworkTopologyStrategy',
    'datacenter1': 3
}
AND durable_writes = true;

USE mentoriadbms;


-- =============================================================================
-- 2. USER TABLES
-- =============================================================================
-- SQL Server source: users, user_social_links
--
-- Two tables are created:
--   (a) users_by_id   — primary lookup by UUID
--   (b) users_by_email — lookup for authentication (email is unique in SQL Server)
--
-- Social links are embedded as a MAP<platform, url> to avoid a separate table.
-- OTP / reset-token fields are kept — they are short-lived and written rarely.
-- =============================================================================

-- (a) Primary user record — looked up after login or by session token
-- Example queries:
--   SELECT * FROM users_by_id WHERE user_id = ?;
--   UPDATE users_by_id SET avatar_url = ? WHERE user_id = ?;

CREATE TABLE IF NOT EXISTS users_by_id (
    user_id        uuid PRIMARY KEY,
    first_name     text,
    last_name      text,
    email          text,
    sex            text,            -- 'Male' | 'Female'
    role           text,            -- 'Mentee' | 'Mentor' | 'Admin'
    status         text,            -- 'Active' | 'Inactive' | 'Banned' | 'Pending'
    country        text,
    timezone       text,
    avatar_url     text,
    password_hash  text,            -- bcrypt hash (NULL for Google accounts)
    provider       text,            -- 'Local' | 'Google'
    google_id      text,
    is_email_verified boolean,
    otp            text,
    otp_expiration timestamp,
    reset_password_token            text,
    reset_password_token_expiration timestamp,
    social_links   map<text, text>, -- platform -> url  (replaces user_social_links table)
    created_at     timestamp,
    updated_at     timestamp
);

-- (b) Thin lookup table for login — avoids a full-table scan on email
-- Example query:
--   SELECT user_id, role, status, password_hash FROM users_by_email WHERE email = ?;

CREATE TABLE IF NOT EXISTS users_by_email (
    email          text PRIMARY KEY,
    user_id        uuid,
    first_name     text,
    last_name      text,
    role           text,
    status         text,
    password_hash  text,
    provider       text,
    google_id      text,
    is_email_verified boolean,
    avatar_url     text
);


-- =============================================================================
-- 3. MENTOR PROFILE TABLE
-- =============================================================================
-- SQL Server source: mentors, mentor_languages, work_for, companies, job_title,
--                    set_skill, skills, own_skill, categories, plans (summary),
--                    feedbacks (derived stats via triggers)
--
-- DESIGN DECISION: Full denormalisation into a single wide row per mentor.
-- This avoids the 8-table JOIN in sp_SearchMentors and supports the mentor
-- profile page with a single partition read.
--
-- Derived attributes (total_mentee, total_stars, total_reviews, rating) were
-- maintained by SQL Server triggers. In Cassandra we maintain them via:
--   • A dedicated counter table (mentor_stats_counters) for atomic increments.
--   • Application reads the counter table and periodically writes a snapshot
--     back to mentor_profiles.rating / total_reviews (or reads both together).
--
-- companies is a MAP<company_name, job_title> — a mentor can work for multiple
-- companies. This matches the work_for relation.
--
-- skills / languages / categories are SET<text> for O(1) membership tests
-- and efficient serialisation.
-- =============================================================================

-- Example queries:
--   SELECT * FROM mentor_profiles WHERE mentor_id = ?;
--   UPDATE mentor_profiles SET bio = ?, headline = ? WHERE mentor_id = ?;

CREATE TABLE IF NOT EXISTS mentor_profiles (
    mentor_id              uuid PRIMARY KEY,
    -- ── from users ──────────────────────────────────
    first_name             text,
    last_name              text,
    email                  text,
    avatar_url             text,
    country                text,
    timezone               text,
    status                 text,
    -- ── from mentors ─────────────────────────────────
    bio                    text,
    headline               text,
    response_time          text,
    cv_url                 text,
    bank_name              text,
    account_number         text,
    account_holder_name    text,
    bank_branch            text,
    swift_code             text,
    -- ── derived stats (snapshot from counter table) ──
    total_mentee           int,
    total_stars            int,
    total_reviews          int,
    rating                 decimal,
    -- ── denormalised collections ──────────────────────
    languages              set<text>,
    skills                 set<text>,
    categories             set<text>,
    companies              map<text, text>,  -- company_name -> job_title
    social_links           map<text, text>,  -- platform     -> url
    -- ── plan summary ─────────────────────────────────
    total_plans            int,
    lowest_plan_price      decimal,
    highest_plan_price     decimal,
    created_at             timestamp,
    updated_at             timestamp
);


-- =============================================================================
-- 4. MENTOR SEARCH / BROWSE TABLES
-- =============================================================================
-- SQL Server source: sp_SearchMentors (complex multi-join procedure)
--
-- DESIGN DECISION:
-- Cassandra cannot replicate the sp_SearchMentors stored procedure natively
-- because it mixes arbitrary equality + range filters across many dimensions.
-- We use THREE separate lookup tables (by category, by skill, by country) and
-- perform an application-level intersection when multiple filters are active.
--
-- For a production system, consider adding Apache Solr or Elasticsearch as the
-- search layer; Cassandra then becomes the source of truth / write path only.
--
-- All three tables are structured as:
--   PARTITION KEY  = the filter dimension (category / skill / country)
--   CLUSTERING COL = (rating DESC, mentor_id) for ranked listings
--
-- TRADE-OFF: Data is triplicated. Updates to a mentor's rating or skills must
-- be propagated to all three tables. Use LOGGED BATCH for atomicity.
-- =============================================================================

-- (a) Browse mentors within a category
-- Example query:
--   SELECT * FROM mentors_by_category
--   WHERE category_name = 'Backend Engineering'
--   ORDER BY rating DESC
--   LIMIT 20;

CREATE TABLE IF NOT EXISTS mentors_by_category (
    category_name     text,
    rating            decimal,
    mentor_id         uuid,
    -- summary columns (denormalised for display cards)
    first_name        text,
    last_name         text,
    headline          text,
    avatar_url        text,
    country           text,
    skills            set<text>,
    languages         set<text>,
    lowest_plan_price decimal,
    total_reviews     int,
    total_mentee      int,
    response_time     text,
    status            text,
    PRIMARY KEY ((category_name), rating, mentor_id)
) WITH CLUSTERING ORDER BY (rating DESC, mentor_id ASC);

-- (b) Browse mentors by skill
-- Example query:
--   SELECT * FROM mentors_by_skill WHERE skill_name = 'Python' LIMIT 20;

CREATE TABLE IF NOT EXISTS mentors_by_skill (
    skill_name        text,
    rating            decimal,
    mentor_id         uuid,
    first_name        text,
    last_name         text,
    headline          text,
    avatar_url        text,
    country           text,
    skills            set<text>,
    categories        set<text>,
    lowest_plan_price decimal,
    total_reviews     int,
    response_time     text,
    status            text,
    PRIMARY KEY ((skill_name), rating, mentor_id)
) WITH CLUSTERING ORDER BY (rating DESC, mentor_id ASC);

-- (c) Browse mentors by country
-- Example query:
--   SELECT * FROM mentors_by_country WHERE country = 'Vietnam' LIMIT 20;

CREATE TABLE IF NOT EXISTS mentors_by_country (
    country           text,
    rating            decimal,
    mentor_id         uuid,
    first_name        text,
    last_name         text,
    headline          text,
    avatar_url        text,
    skills            set<text>,
    categories        set<text>,
    lowest_plan_price decimal,
    total_reviews     int,
    response_time     text,
    status            text,
    PRIMARY KEY ((country), rating, mentor_id)
) WITH CLUSTERING ORDER BY (rating DESC, mentor_id ASC);


-- =============================================================================
-- 5. PLANS TABLE
-- =============================================================================
-- SQL Server source: plans, plan_sessions, plan_mentorships, mentorships_benefits
--
-- DESIGN DECISION:
-- plan_sessions and plan_mentorships are a 1:1 extension of plans (table
-- inheritance pattern in SQL Server). We collapse them into a single Cassandra
-- table using nullable columns. The plan_category column ('session' |
-- 'mentorship') indicates which fields are relevant.
--
-- benefits (from mentorships_benefits) are a LIST<text> inside the same row,
-- avoiding a separate table entirely.
-- =============================================================================

-- Example queries:
--   SELECT * FROM plans_by_mentor WHERE mentor_id = ?;
--   DELETE FROM plans_by_mentor WHERE mentor_id = ? AND plan_id = ?;

CREATE TABLE IF NOT EXISTS plans_by_mentor (
    mentor_id          uuid,
    plan_id            uuid,
    plan_type          text,
    plan_description   text,
    plan_charge        decimal,
    plan_category      text,       -- 'session' | 'mentorship'
    -- session-specific (NULL when plan_category = 'mentorship')
    sessions_duration  int,        -- minutes (15–120)
    -- mentorship-specific (NULL when plan_category = 'session')
    calls_per_month    int,
    minutes_per_call   int,
    benefits           list<text>, -- replaces mentorships_benefits table
    created_at         timestamp,
    PRIMARY KEY ((mentor_id), plan_id)
) WITH CLUSTERING ORDER BY (plan_id ASC);

-- Secondary lookup: get a single plan by its ID (e.g., during checkout)
-- Example query:
--   SELECT * FROM plans_by_id WHERE plan_id = ?;

CREATE TABLE IF NOT EXISTS plans_by_id (
    plan_id            uuid PRIMARY KEY,
    mentor_id          uuid,
    plan_type          text,
    plan_description   text,
    plan_charge        decimal,
    plan_category      text,
    sessions_duration  int,
    calls_per_month    int,
    minutes_per_call   int,
    benefits           list<text>
);


-- =============================================================================
-- 6. MENTOR AVAILABILITY SLOTS
-- =============================================================================
-- SQL Server source: slots (PK: mentor_id, start_time, end_time, date)
--
-- DESIGN DECISION:
-- Partition by (mentor_id, slot_date) so that "get all slots for mentor X on
-- date Y" is a single partition scan — this is the dominant query (calendar UI).
-- Clustering on start_time gives chronological ordering within the day.
--
-- slot_id (uuid) is added as a surrogate key to support O(1) status updates
-- (UPDATE … WHERE mentor_id=? AND slot_date=? AND start_time=?).
-- =============================================================================

-- Example queries:
--   SELECT * FROM mentor_slots WHERE mentor_id = ? AND slot_date = ?;
--   UPDATE mentor_slots SET status = 'Booked' WHERE mentor_id = ? AND slot_date = ? AND start_time = ?;

CREATE TABLE IF NOT EXISTS mentor_slots (
    mentor_id   uuid,
    slot_date   date,
    start_time  timestamp,
    end_time    timestamp,
    slot_id     uuid,
    status      text,     -- 'Available' | 'Booked'
    plan_id     uuid,
    plan_type   text,     -- denormalised for display
    plan_charge decimal,  -- denormalised for display
    PRIMARY KEY ((mentor_id, slot_date), start_time)
) WITH CLUSTERING ORDER BY (start_time ASC);


-- =============================================================================
-- 7. MEETINGS TABLES
-- =============================================================================
-- SQL Server source: meetings, invoices (joined for mentee_id), bookings, plans
--
-- DESIGN DECISION:
-- Three tables cover the three common read paths:
--   (a) meetings_by_mentee  — mentee dashboard (all meetings for a mentee)
--   (b) meetings_by_mentor  — mentor dashboard (all meetings for a mentor)
--   (c) meetings_by_id      — single-meeting lookup (detail page, status update)
--
-- All relevant data is denormalised in (a) and (b) so that the dashboard can
-- be rendered with a single partition scan (matches the getMeetingsByMenteeId
-- and getMeetingsByMentorId service queries).
--
-- Clustering on (meeting_date DESC, meeting_id) gives newest-first ordering
-- within a partition, matching the SQL ORDER BY m.date DESC, m.start_time DESC.
-- =============================================================================

-- (a) Mentee dashboard
-- Example queries:
--   SELECT * FROM meetings_by_mentee WHERE mentee_id = ? LIMIT 50;
--   SELECT * FROM meetings_by_mentee WHERE mentee_id = ? AND status = 'Pending';
--   UPDATE meetings_by_mentee SET status = 'Cancelled' WHERE mentee_id = ? AND meeting_date = ? AND meeting_id = ?;

CREATE TABLE IF NOT EXISTS meetings_by_mentee (
    mentee_id              uuid,
    meeting_date           date,
    meeting_id             uuid,
    -- meeting core fields
    status                 text,      -- 'Pending' | 'Scheduled' | 'Completed' | 'Cancelled'
    location               text,
    review_link            text,
    start_time             timestamp,
    end_time               timestamp,
    -- mentor info (denormalised)
    mentor_id              uuid,
    mentor_first_name      text,
    mentor_last_name       text,
    mentor_avatar_url      text,
    mentor_email           text,
    -- plan info (denormalised)
    plan_type              text,
    plan_description       text,
    plan_charge            decimal,
    amount_paid            decimal,
    discuss_message        text,
    -- invoice / booking refs
    invoice_id             uuid,
    plan_registration_id   uuid,
    PRIMARY KEY ((mentee_id), meeting_date, meeting_id)
) WITH CLUSTERING ORDER BY (meeting_date DESC, meeting_id ASC);

-- (b) Mentor dashboard
-- Example queries:
--   SELECT * FROM meetings_by_mentor WHERE mentor_id = ? LIMIT 50;

CREATE TABLE IF NOT EXISTS meetings_by_mentor (
    mentor_id              uuid,
    meeting_date           date,
    meeting_id             uuid,
    status                 text,
    location               text,
    review_link            text,
    start_time             timestamp,
    end_time               timestamp,
    -- mentee info (denormalised)
    mentee_id              uuid,
    mentee_first_name      text,
    mentee_last_name       text,
    mentee_avatar_url      text,
    mentee_email           text,
    -- plan info (denormalised)
    plan_type              text,
    plan_description       text,
    plan_charge            decimal,
    amount_paid            decimal,
    discuss_message        text,
    invoice_id             uuid,
    plan_registration_id   uuid,
    PRIMARY KEY ((mentor_id), meeting_date, meeting_id)
) WITH CLUSTERING ORDER BY (meeting_date DESC, meeting_id ASC);

-- (c) Single-meeting lookup (for status updates, location patches)
-- Example queries:
--   SELECT * FROM meetings_by_id WHERE meeting_id = ?;

CREATE TABLE IF NOT EXISTS meetings_by_id (
    meeting_id             uuid PRIMARY KEY,
    status                 text,
    location               text,
    review_link            text,
    start_time             timestamp,
    end_time               timestamp,
    meeting_date           date,
    mentor_id              uuid,
    mentee_id              uuid,
    invoice_id             uuid,
    plan_registration_id   uuid,
    plan_type              text,
    plan_charge            decimal,
    amount_paid            decimal,
    -- both parties (needed for email notifications on status change)
    mentor_first_name      text,
    mentor_last_name       text,
    mentor_email           text,
    mentor_avatar_url      text,
    mentee_first_name      text,
    mentee_last_name       text,
    mentee_email           text,
    mentee_avatar_url      text,
    discuss_message        text
);


-- =============================================================================
-- 8. INVOICES TABLE
-- =============================================================================
-- SQL Server source: invoices, plan_registerations, bookings, plans
--
-- DESIGN DECISION:
-- Partition by mentee_id so "get payment history for mentee X" is a single
-- partition scan (mentee billing page query pattern).
-- Clustering on paid_time DESC shows newest invoices first.
--
-- stripe_session_id is indexed separately (stripe_session_by_session_id) to
-- support the idempotent verifySession endpoint, which checks if a Stripe
-- session was already processed.
--
-- plan_registerations and bookings are collapsed here — they are purely a
-- normalisation artefact in SQL Server to support the invoice FK chain. In
-- Cassandra we store only what the application needs.
-- =============================================================================

-- Example queries:
--   SELECT * FROM invoices_by_mentee WHERE mentee_id = ? LIMIT 20;

CREATE TABLE IF NOT EXISTS invoices_by_mentee (
    mentee_id                      uuid,
    paid_time                      timestamp,
    invoice_id                     uuid,
    plan_registration_id           uuid,
    method                         text,
    -- stripe fields
    stripe_session_id              text,
    stripe_customer_id             text,
    stripe_customer_email          text,
    stripe_payment_intent_id       text,
    stripe_charge_id               text,
    stripe_balance_transaction_id  text,
    stripe_receipt_url             text,
    payment_status                 text,   -- 'paid' | 'failed'
    currency                       text,
    amount_subtotal                decimal,
    amount_total                   decimal,
    -- denormalised context
    mentor_id                      uuid,
    mentor_first_name              text,
    mentor_last_name               text,
    plan_type                      text,
    plan_description               text,
    discuss_message                text,
    discount_name                  text,
    discount_amount                decimal,
    PRIMARY KEY ((mentee_id), paid_time, invoice_id)
) WITH CLUSTERING ORDER BY (paid_time DESC, invoice_id ASC);

-- Lookup by Stripe session ID (idempotency check in verifySessionService)
-- Example query:
--   SELECT invoice_id, mentee_id FROM invoices_by_stripe_session WHERE stripe_session_id = ?;

CREATE TABLE IF NOT EXISTS invoices_by_stripe_session (
    stripe_session_id  text PRIMARY KEY,
    invoice_id         uuid,
    mentee_id          uuid,
    paid_time          timestamp,
    payment_status     text
);


-- =============================================================================
-- 9. MESSAGES TABLE
-- =============================================================================
-- SQL Server source: messages
--
-- DESIGN DECISION:
-- Partition by conversation_id — a deterministic string formed by sorting the
-- two user UUIDs and joining them with '_'. This ensures both participants
-- always map to the same partition.
--   conversation_id = min(user_a_id, user_b_id) + '_' + max(user_a_id, user_b_id)
--
-- BUCKETING: A very active 1:1 chat can generate millions of messages. Adding
-- a bucket column (e.g. 'YYYY-MM') as part of the partition key limits
-- partition size to roughly one month of messages per pair, at the cost of
-- requiring the application to query across buckets for cross-month history.
-- The bucket column is included here; if conversations are typically short
-- (as in a mentorship context) it can be removed.
--
-- Clustering on sent_time DESC + message_id ASC gives newest-first ordering.
-- =============================================================================

-- Example queries:
--   SELECT * FROM messages_by_conversation
--   WHERE conversation_id = ? AND bucket = '2025-01'
--   LIMIT 50;

CREATE TABLE IF NOT EXISTS messages_by_conversation (
    conversation_id  text,    -- 'min_uuid_max_uuid'
    bucket           text,    -- 'YYYY-MM' (time-based partition cap)
    sent_time        timestamp,
    message_id       uuid,
    sender_id        uuid,
    receiver_id      uuid,
    content          text,
    -- denormalised sender info for display (avoids secondary lookup)
    sender_first_name   text,
    sender_last_name    text,
    sender_avatar_url   text,
    PRIMARY KEY ((conversation_id, bucket), sent_time, message_id)
) WITH CLUSTERING ORDER BY (sent_time DESC, message_id ASC);

-- List all conversations for a user (inbox view)
-- DESIGN: Each time a message is sent, an entry is upserted here for BOTH
-- sender and receiver so that each user can see their full inbox with one read.
-- Example query:
--   SELECT * FROM conversations_by_user WHERE user_id = ? LIMIT 30;

CREATE TABLE IF NOT EXISTS conversations_by_user (
    user_id              uuid,
    last_message_time    timestamp,
    other_user_id        uuid,
    conversation_id      text,    -- same key as messages_by_conversation
    other_first_name     text,
    other_last_name      text,
    other_avatar_url     text,
    last_message_preview text,
    unread_count         int,
    PRIMARY KEY ((user_id), last_message_time, other_user_id)
) WITH CLUSTERING ORDER BY (last_message_time DESC, other_user_id ASC);


-- =============================================================================
-- 10. FEEDBACKS TABLE
-- =============================================================================
-- SQL Server source: feedbacks (PK: mentee_id, mentor_id)
--
-- DESIGN DECISION:
-- The dominant read pattern is "get all reviews for a mentor" (profile page).
-- Partition by mentor_id, cluster by sent_time DESC for newest-first ordering.
--
-- SQL Server enforces one feedback per (mentee, mentor) pair via composite PK.
-- Cassandra upserts naturally; the application enforces the uniqueness rule
-- by including mentee_id as a clustering column — a re-insert simply overwrites.
--
-- Mentee info is denormalised to avoid a secondary lookup when rendering cards.
--
-- The derived attributes (total_reviews, total_stars, rating) on the mentors
-- table were maintained by SQL Server triggers. In Cassandra:
--   • Increment mentor_stats_counters on INSERT.
--   • Decrement on DELETE.
--   • On UPDATE(stars): decrement old value, increment new value.
--   (see Section 13 — Counter Tables)
-- =============================================================================

-- Example queries:
--   SELECT * FROM feedbacks_by_mentor WHERE mentor_id = ? LIMIT 20;
--   SELECT * FROM feedbacks_by_mentor WHERE mentor_id = ? AND mentee_id = ?;  (using secondary index)

CREATE TABLE IF NOT EXISTS feedbacks_by_mentor (
    mentor_id         uuid,
    sent_time         timestamp,
    mentee_id         uuid,
    stars             int,
    content           text,
    -- denormalised mentee info
    mentee_first_name text,
    mentee_last_name  text,
    mentee_avatar_url text,
    PRIMARY KEY ((mentor_id), sent_time, mentee_id)
) WITH CLUSTERING ORDER BY (sent_time DESC, mentee_id ASC);

-- Lookup: did this mentee already leave feedback for this mentor?
-- Used to prevent duplicate feedback submissions.
-- Example query:
--   SELECT mentor_id FROM feedbacks_by_mentee_mentor WHERE mentee_id = ? AND mentor_id = ?;

CREATE TABLE IF NOT EXISTS feedbacks_by_mentee_mentor (
    mentee_id   uuid,
    mentor_id   uuid,
    stars       int,
    content     text,
    sent_time   timestamp,
    PRIMARY KEY ((mentee_id), mentor_id)
);


-- =============================================================================
-- 11. NOTIFICATIONS TABLE
-- =============================================================================
-- SQL Server source: notifications, sended
--
-- DESIGN DECISION:
-- The SQL Server model separates notification templates (notifications) from
-- their delivery record (sended). In Cassandra we collapse both into a single
-- table partitioned by user_id — each delivered notification is a full row
-- (template data + delivery metadata inline).
-- =============================================================================

-- Example queries:
--   SELECT * FROM notifications_by_user WHERE user_id = ? LIMIT 50;

CREATE TABLE IF NOT EXISTS notifications_by_user (
    user_id         uuid,
    sent_time       timestamp,
    notification_id uuid,
    title           text,
    content         text,
    is_read         boolean,
    PRIMARY KEY ((user_id), sent_time, notification_id)
) WITH CLUSTERING ORDER BY (sent_time DESC, notification_id ASC);


-- =============================================================================
-- 12. DISCOUNTS TABLE
-- =============================================================================
-- SQL Server source: discounts
--
-- DESIGN DECISION:
-- Two access patterns:
--   (a) Lookup a discount by its name (code) during checkout — most common.
--   (b) List all active discounts (admin dashboard) — less common, small dataset.
--
-- used_count is a counter that must live in a separate counter table
-- (discount_usage_counters, Section 13) because Cassandra counter columns
-- cannot be mixed with regular columns in the same table.
--
-- The application reads the counter, checks it against usage_limit before
-- applying the discount, and increments the counter on successful payment.
-- =============================================================================

-- (a) Lookup by code — used at checkout
-- Example query:
--   SELECT * FROM discounts_by_code WHERE discount_name = ?;

CREATE TABLE IF NOT EXISTS discounts_by_code (
    discount_name   text PRIMARY KEY,
    discount_id     uuid,
    discount_type   text,     -- 'Percentage' | 'Fixed'
    discount_value  decimal,
    start_date      timestamp,
    end_date        timestamp,
    status          text,     -- 'Active' | 'Inactive'
    usage_limit     int
    -- NOTE: used_count lives in discount_usage_counters (counter table)
);

-- (b) List active discounts (admin panel)
-- Example query:
--   SELECT * FROM discounts_by_status WHERE status = 'Active' AND end_date >= toTimestamp(now());

CREATE TABLE IF NOT EXISTS discounts_by_status (
    status          text,
    end_date        timestamp,
    discount_id     uuid,
    discount_name   text,
    discount_type   text,
    discount_value  decimal,
    start_date      timestamp,
    usage_limit     int,
    PRIMARY KEY ((status), end_date, discount_id)
) WITH CLUSTERING ORDER BY (end_date ASC, discount_id ASC);


-- =============================================================================
-- 13. COUNTER TABLES
-- =============================================================================
-- SQL Server source: mentors.total_mentee/total_stars/total_reviews/rating
--                    (maintained by triggers), discounts.used_count
--
-- DESIGN DECISION:
-- Cassandra's counter column type provides atomic, distributed increments
-- without read-before-write. Counter tables CANNOT contain non-counter
-- columns (except the primary key).
--
-- mentor_stats_counters replaces the four SQL Server triggers:
--   trg_meeting_completed → INCR total_mentee on meeting → Completed
--   trg_meeting_insert    → same
--   trg_feedback_insert   → INCR total_reviews + total_stars(by stars value)
--   trg_feedback_update   → adjust total_stars (decrement old, increment new)
--   trg_feedback_delete   → DECR total_reviews + total_stars
--
-- rating = total_stars / total_reviews is computed at read time by the app.
--
-- USAGE PATTERN:
--   UPDATE mentor_stats_counters SET total_reviews = total_reviews + 1,
--          total_stars = total_stars + ? WHERE mentor_id = ?;
--   (Application then reads back and recomputes rating = total_stars / total_reviews)
-- =============================================================================

CREATE TABLE IF NOT EXISTS mentor_stats_counters (
    mentor_id    uuid PRIMARY KEY,
    total_mentee counter,
    total_stars  counter,
    total_reviews counter
);

-- Discount usage counter (replaces discounts.used_count)
-- Example:
--   UPDATE discount_usage_counters SET used_count = used_count + 1 WHERE discount_id = ?;

CREATE TABLE IF NOT EXISTS discount_usage_counters (
    discount_id  uuid PRIMARY KEY,
    used_count   counter
);


-- =============================================================================
-- 14. REFERENCE / CATALOG TABLES
-- =============================================================================
-- SQL Server source: categories, skills, own_skill, companies, job_title
--
-- DESIGN DECISION:
-- These are small, mostly-read reference tables (catalog data).
-- In Cassandra they can be stored as simple tables with a UUID partition key.
-- categories and skills are denormalised — skill rows carry their parent
-- category directly, so the own_skill junction table is eliminated.
--
-- companies and job_title are also small; they are kept as simple lookup
-- tables. In practice, the application caches them in memory / Redis, so
-- Cassandra reads are infrequent.
-- =============================================================================

-- Categories (hierarchical — parent stored inline to avoid self-join)
-- Example query:
--   SELECT * FROM categories WHERE category_id = ?;

CREATE TABLE IF NOT EXISTS categories (
    category_id         uuid PRIMARY KEY,
    category_name       text,
    parent_category_id  uuid,       -- NULL for top-level
    parent_category_name text       -- denormalised to avoid second read
);

-- All categories (for dropdown / browse page)
-- Example query:
--   SELECT * FROM all_categories WHERE bucket = 'all';

CREATE TABLE IF NOT EXISTS all_categories (
    bucket         text,            -- always 'all' — single-partition reference table
    category_name  text,
    category_id    uuid,
    parent_category_id uuid,
    PRIMARY KEY ((bucket), category_name, category_id)
) WITH CLUSTERING ORDER BY (category_name ASC, category_id ASC);

-- Skills (each row carries its category for context)
-- Example query:
--   SELECT * FROM skills_by_category WHERE category_id = ?;

CREATE TABLE IF NOT EXISTS skills_by_category (
    category_id    uuid,
    skill_name     text,
    skill_id       uuid,
    PRIMARY KEY ((category_id), skill_name, skill_id)
) WITH CLUSTERING ORDER BY (skill_name ASC, skill_id ASC);

-- Companies (reference, small table)
CREATE TABLE IF NOT EXISTS companies (
    company_id   uuid PRIMARY KEY,
    cname        text
);

-- Job titles (reference, small table)
CREATE TABLE IF NOT EXISTS job_titles (
    job_title_id  uuid PRIMARY KEY,
    job_name      text
);


-- =============================================================================
-- 15. ADMIN ANALYTICS / DASHBOARD TABLES
-- =============================================================================
-- SQL Server source: sp_DashboardStatistics (GROUP BY mentor / month / category)
--
-- DESIGN DECISION:
-- Stored procedures that aggregate invoices/bookings/meetings in real time are
-- too expensive to replicate as Cassandra queries (no GROUP BY, no SUM across
-- partitions without ALLOW FILTERING).
--
-- Instead we maintain *pre-aggregated* tables that are updated on every
-- relevant write event (invoice created, meeting completed):
--   revenue_by_month   — matches the 'month' GROUP BY branch
--   revenue_by_mentor  — matches the 'mentor' GROUP BY branch
--   revenue_by_category — matches the 'category' GROUP BY branch
--
-- Updates use Cassandra's lightweight transaction (IF EXISTS) or counter
-- columns. For simplicity, counters are used for totals and the app upserts
-- the decimal revenue column (last-write-wins is acceptable for analytics).
--
-- TRADE-OFF: Analytics data is eventually consistent.
-- =============================================================================

-- Monthly revenue rollup (for line charts, year-over-year comparison)
-- Partition key = year_month so all rows for a given month are co-located.
-- Example query:
--   SELECT * FROM revenue_by_month WHERE year_month = '2025-01';
--   SELECT * FROM revenue_by_month WHERE year_month IN ('2025-01','2025-02',...);

CREATE TABLE IF NOT EXISTS revenue_by_month (
    year_month             text,    -- 'YYYY-MM'
    mentor_id              uuid,
    mentor_name            text,
    total_revenue          decimal,
    total_bookings         int,
    total_invoices         int,
    avg_invoice_amount     decimal,
    completed_meetings     int,
    cancelled_meetings     int,
    PRIMARY KEY ((year_month), mentor_id)
);

-- Per-mentor revenue summary (for admin mentor table with sorting)
-- Example queries:
--   SELECT * FROM revenue_by_mentor WHERE bucket = 'all' ORDER BY total_revenue DESC LIMIT 50;

CREATE TABLE IF NOT EXISTS revenue_by_mentor (
    bucket                  text,    -- 'all' (or a date range like '2025')
    total_revenue           decimal,
    mentor_id               uuid,
    mentor_name             text,
    mentor_email            text,
    mentor_avatar_url       text,
    mentor_country          text,
    mentor_status           text,
    mentor_headline         text,
    company_names           text,
    job_titles              text,
    skills                  text,
    total_bookings          int,
    total_invoices          int,
    avg_invoice_amount      decimal,
    completed_meetings      int,
    cancelled_meetings      int,
    upcoming_meetings       int,
    average_rating          decimal,
    total_reviews           int,
    total_mentee            int,
    total_plans             int,
    PRIMARY KEY ((bucket), total_revenue, mentor_id)
) WITH CLUSTERING ORDER BY (total_revenue DESC, mentor_id ASC);

-- Per-category revenue summary
-- Example query:
--   SELECT * FROM revenue_by_category WHERE bucket = 'all' ORDER BY total_revenue DESC;

CREATE TABLE IF NOT EXISTS revenue_by_category (
    bucket                    text,
    total_revenue             decimal,
    category_id               uuid,
    category_name             text,
    total_mentors_with_skill  int,
    total_bookings            int,
    PRIMARY KEY ((bucket), total_revenue, category_id)
) WITH CLUSTERING ORDER BY (total_revenue DESC, category_id ASC);


-- =============================================================================
-- 16. SECONDARY INDEXES
-- =============================================================================
-- Cassandra secondary indexes are suitable for LOW-CARDINALITY columns on
-- tables with many rows. They add a hidden local index on each node.
--
-- We use them sparingly — only where a full table scan would otherwise be
-- required and the column cardinality is low.
-- =============================================================================

-- Filter mentor search results by status ('Active' | 'Inactive' | 'Banned')
-- Low cardinality (3 values), used infrequently → secondary index is acceptable.
CREATE INDEX IF NOT EXISTS idx_mentors_category_status
    ON mentors_by_category (status);

CREATE INDEX IF NOT EXISTS idx_mentors_skill_status
    ON mentors_by_skill (status);

-- Filter meetings by status on the dashboard (e.g. show only Pending)
-- Low cardinality (4 values) — secondary index is acceptable here because
-- each partition (mentee_id) is bounded in size.
CREATE INDEX IF NOT EXISTS idx_meetings_mentee_status
    ON meetings_by_mentee (status);

CREATE INDEX IF NOT EXISTS idx_meetings_mentor_status
    ON meetings_by_mentor (status);


-- =============================================================================
-- 17. SUMMARY: WRITE-PATH PLAYBOOK
-- =============================================================================
--
-- When an event occurs in the application, the following tables must be
-- written atomically (use LOGGED BATCH for same-partition updates, or handle
-- cross-partition consistency at application level with retry logic):
--
-- ┌────────────────────────────────┬─────────────────────────────────────────────────────┐
-- │ Event                          │ Tables to write                                     │
-- ├────────────────────────────────┼─────────────────────────────────────────────────────┤
-- │ User registration              │ users_by_id, users_by_email                         │
-- │ Mentor profile update          │ users_by_id, mentor_profiles,                       │
-- │                                │ mentors_by_category, mentors_by_skill,              │
-- │                                │ mentors_by_country, revenue_by_mentor               │
-- │ Plan created/updated           │ plans_by_mentor, plans_by_id,                       │
-- │                                │ mentor_profiles (update lowest_plan_price)          │
-- │ Slot added                     │ mentor_slots                                        │
-- │ Payment completed (webhook)    │ invoices_by_mentee, invoices_by_stripe_session,     │
-- │                                │ meetings_by_mentee, meetings_by_mentor,             │
-- │                                │ meetings_by_id, mentor_slots (status→Booked)        │
-- │ Meeting status updated         │ meetings_by_mentee, meetings_by_mentor,             │
-- │                                │ meetings_by_id                                      │
-- │ Meeting → Completed            │ + INCR mentor_stats_counters.total_mentee           │
-- │                                │ + UPDATE revenue_by_month, revenue_by_mentor        │
-- │ Feedback submitted             │ feedbacks_by_mentor, feedbacks_by_mentee_mentor,    │
-- │                                │ INCR mentor_stats_counters.total_reviews + stars    │
-- │                                │ UPDATE mentor_profiles.rating (computed by app)     │
-- │ Message sent                   │ messages_by_conversation,                           │
-- │                                │ conversations_by_user (both sender + receiver rows) │
-- │ Discount used                  │ INCR discount_usage_counters.used_count             │
-- └────────────────────────────────┴─────────────────────────────────────────────────────┘
--
-- CONSISTENCY LEVELS (recommended)
-- ---------------------------------
--   Writes: QUORUM (majority of replicas must acknowledge)
--   Reads:  LOCAL_QUORUM (strong read, avoids cross-DC latency)
--   For non-critical reads (analytics): ONE (faster, eventually consistent)
--
-- WHAT IS NOT IN CASSANDRA
-- -------------------------
--   • CalculateMentorResponseTime() function — computed in application code
--     by reading messages_by_conversation and computing time deltas.
--   • FindBestDiscountForMentee()           — computed in application code
--     by reading discounts_by_status and evaluating each discount.
--   • Complex multi-filter mentor search    — handled by application-side
--     intersection of mentors_by_category + mentors_by_skill + mentors_by_country,
--     OR by an Elasticsearch cluster for full-text / faceted search.
-- =============================================================================
