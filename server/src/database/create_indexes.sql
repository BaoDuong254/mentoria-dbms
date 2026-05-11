-- ============================================================
-- Mentoria Database -- Nonclustered Index Definitions
-- ============================================================
-- Cach chay:
--   1. Mo file nay trong SSMS va chay (F5)
--   2. Hoac dung sqlcmd: sqlcmd -S . -d [mentoria-dbms] -i create_indexes.sql
-- Tat ca index deu co guard IF NOT EXISTS, co the chay lai an toan.
--
-- Luu y ve INCLUDE:
--   SQL Server tu dong them clustering key (PK) vao moi nonclustered index
--   de lam row locator, nen khong can INCLUDE lai cac cot PK.
-- ============================================================

USE [mentoria-dbms];
GO

-- ============================================================
-- SECTION 1: USERS
-- role + status la cap filter chinh cua sp_SearchMentors.
-- country dung trong filter rieng le.
-- user_id (PK) duoc SQL Server tu them, khong can INCLUDE.
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_users_role_status' AND object_id = OBJECT_ID('dbo.users'))
    CREATE NONCLUSTERED INDEX IX_users_role_status
        ON dbo.users (role, status)
        INCLUDE (first_name, last_name, avatar_url, country, timezone);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_users_country' AND object_id = OBJECT_ID('dbo.users'))
    CREATE NONCLUSTERED INDEX IX_users_country
        ON dbo.users (country)
        INCLUDE (role, status);
GO

-- ============================================================
-- SECTION 2: MENTORS
-- rating dung trong WHERE (>= @MinRating) va ORDER BY.
-- user_id (PK) duoc SQL Server tu them.
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_mentors_rating' AND object_id = OBJECT_ID('dbo.mentors'))
    CREATE NONCLUSTERED INDEX IX_mentors_rating
        ON dbo.mentors (rating DESC)
        INCLUDE (total_reviews, total_stars, total_mentee);
GO

-- ============================================================
-- SECTION 3: PLANS
-- PK chi la plan_id; mentor_id la FK khong duoc index.
-- PlanInfo CTE va RevenueStats CTE deu GROUP BY / JOIN theo mentor_id.
-- plan_id (PK) duoc SQL Server tu them.
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_plans_mentor_id' AND object_id = OBJECT_ID('dbo.plans'))
    CREATE NONCLUSTERED INDEX IX_plans_mentor_id
        ON dbo.plans (mentor_id)
        INCLUDE (plan_type, plan_charge);
GO

-- ============================================================
-- SECTION 4: SLOTS
-- Kiem tra overlap: WHERE plan_id = ? AND date = ? AND start_time < ? AND end_time > ?
-- Calendar mentor: WHERE mentor_id = ? AND date BETWEEN ? AND ?
-- PK composite (mentor_id, start_time, end_time, date) duoc tu them lam row locator.
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_slots_plan_id_date' AND object_id = OBJECT_ID('dbo.slots'))
    CREATE NONCLUSTERED INDEX IX_slots_plan_id_date
        ON dbo.slots (plan_id, date)
        INCLUDE (status);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_slots_mentor_date' AND object_id = OBJECT_ID('dbo.slots'))
    CREATE NONCLUSTERED INDEX IX_slots_mentor_date
        ON dbo.slots (mentor_id, date)
        INCLUDE (status, plan_id);
GO

-- ============================================================
-- SECTION 5: INVOICES
-- mentee_id: JOIN + WHERE trong nhieu query.
-- paid_time + payment_status: BETWEEN filter trong dashboard.
-- stripe_session_id: hot path cua Stripe webhook.
-- invoice_id (PK) duoc SQL Server tu them.
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_invoices_mentee_id' AND object_id = OBJECT_ID('dbo.invoices'))
    CREATE NONCLUSTERED INDEX IX_invoices_mentee_id
        ON dbo.invoices (mentee_id)
        INCLUDE (plan_registerations_id, payment_status, paid_time, amount_total);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_invoices_paid_time_status' AND object_id = OBJECT_ID('dbo.invoices'))
    CREATE NONCLUSTERED INDEX IX_invoices_paid_time_status
        ON dbo.invoices (paid_time DESC, payment_status)
        INCLUDE (mentee_id, plan_registerations_id, amount_total, amount_subtotal);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_invoices_stripe_session' AND object_id = OBJECT_ID('dbo.invoices'))
    CREATE NONCLUSTERED INDEX IX_invoices_stripe_session
        ON dbo.invoices (stripe_session_id)
        INCLUDE (mentee_id, payment_status, amount_total);
GO

-- ============================================================
-- SECTION 6: BOOKINGS
-- PK composite la (mentee_id, plan_registerations_id).
-- plan_id la FK o vi tri thu 3, can index rieng cho reverse lookup.
-- mentee_id va plan_registerations_id (PK composite) duoc tu them lam row locator,
-- khong can INCLUDE.
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_bookings_plan_id' AND object_id = OBJECT_ID('dbo.bookings'))
    CREATE NONCLUSTERED INDEX IX_bookings_plan_id
        ON dbo.bookings (plan_id);
GO

-- ============================================================
-- SECTION 7: MEETINGS
-- PK chi la meeting_id.
-- mentor_id: GROUP BY trong MeetingStats CTE.
-- status + date: WHERE/ORDER BY trong dashboard va getMeetingsByMentee/Mentor.
-- meeting_id (PK) duoc SQL Server tu them.
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_meetings_mentor_id' AND object_id = OBJECT_ID('dbo.meetings'))
    CREATE NONCLUSTERED INDEX IX_meetings_mentor_id
        ON dbo.meetings (mentor_id)
        INCLUDE (invoice_id, plan_registerations_id, status, date, start_time, end_time);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_meetings_status_date' AND object_id = OBJECT_ID('dbo.meetings'))
    CREATE NONCLUSTERED INDEX IX_meetings_status_date
        ON dbo.meetings (status, date DESC)
        INCLUDE (mentor_id, invoice_id, plan_registerations_id);
GO

-- ============================================================
-- SECTION 8: DISCOUNTS
-- Moi checkout deu tra cuu discount_name + kiem tra status va khoang ngay.
-- discount_id (PK) duoc SQL Server tu them.
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_discounts_name_status' AND object_id = OBJECT_ID('dbo.discounts'))
    CREATE NONCLUSTERED INDEX IX_discounts_name_status
        ON dbo.discounts (discount_name, status)
        INCLUDE (discount_type, discount_value, start_date, end_date, used_count, usage_limit);
GO

-- ============================================================
-- SECTION 9: PLAN_REGISTERATIONS
-- discount_id la FK, khong nam o vi tri dau cua bat ky index nao.
-- registration_id (PK) duoc SQL Server tu them, khong can INCLUDE.
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_plan_reg_discount_id' AND object_id = OBJECT_ID('dbo.plan_registerations'))
    CREATE NONCLUSTERED INDEX IX_plan_reg_discount_id
        ON dbo.plan_registerations (discount_id);
GO

-- ============================================================
-- SECTION 10: MESSAGES
-- PK chi la message_id.
-- Xem cuoc tro chuyen can filter (sender_id, receiver_id) va sort sent_time.
-- Index thu 2 cho inbox query (receiver la chu the chinh).
-- message_id (PK) duoc SQL Server tu them.
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_messages_sender_receiver' AND object_id = OBJECT_ID('dbo.messages'))
    CREATE NONCLUSTERED INDEX IX_messages_sender_receiver
        ON dbo.messages (sender_id, receiver_id, sent_time DESC)
        INCLUDE (content);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_messages_receiver_sender' AND object_id = OBJECT_ID('dbo.messages'))
    CREATE NONCLUSTERED INDEX IX_messages_receiver_sender
        ON dbo.messages (receiver_id, sender_id, sent_time DESC)
        INCLUDE (content);
GO

-- ============================================================
-- SECTION 11: FEEDBACKS
-- PK composite la (mentee_id, mentor_id).
-- Lay danh sach feedback cua 1 mentor: mentor_id o vi tri thu 2 trong PK,
-- can index rieng. mentee_id (PK composite) duoc tu them lam row locator.
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_feedbacks_mentor_id' AND object_id = OBJECT_ID('dbo.feedbacks'))
    CREATE NONCLUSTERED INDEX IX_feedbacks_mentor_id
        ON dbo.feedbacks (mentor_id)
        INCLUDE (stars, content, sent_time);
GO

-- ============================================================
-- SECTION 12: OWN_SKILL
-- PK composite la (category_id, skill_id).
-- sp_SearchMentors JOIN nguoc tu skill_id -> category_id.
-- category_id (phan PK composite) duoc SQL Server tu them lam row locator,
-- khong can INCLUDE.
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_own_skill_skill_id' AND object_id = OBJECT_ID('dbo.own_skill'))
    CREATE NONCLUSTERED INDEX IX_own_skill_skill_id
        ON dbo.own_skill (skill_id);
GO

-- ============================================================
-- SECTION 13: WORK_FOR
-- PK composite la (mentor_id, c_company_id) -- mentor_id lookups dung clustered.
-- current_job_title_id la FK o vi tri thu 3, can index rieng.
-- mentor_id, c_company_id (PK composite) duoc tu them lam row locator.
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_work_for_job_title_id' AND object_id = OBJECT_ID('dbo.work_for'))
    CREATE NONCLUSTERED INDEX IX_work_for_job_title_id
        ON dbo.work_for (current_job_title_id);
GO

-- ============================================================
-- SECTION 14: LOOKUP TABLES
-- Index tren ten ho tro exact match va prefix search (LIKE 'x%').
-- Cac cot PK (skill_id, company_id, job_title_id, category_id) duoc tu them.
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_skills_name' AND object_id = OBJECT_ID('dbo.skills'))
    CREATE NONCLUSTERED INDEX IX_skills_name
        ON dbo.skills (skill_name);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_companies_name' AND object_id = OBJECT_ID('dbo.companies'))
    CREATE NONCLUSTERED INDEX IX_companies_name
        ON dbo.companies (cname);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_job_title_name' AND object_id = OBJECT_ID('dbo.job_title'))
    CREATE NONCLUSTERED INDEX IX_job_title_name
        ON dbo.job_title (job_name);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_categories_name' AND object_id = OBJECT_ID('dbo.categories'))
    CREATE NONCLUSTERED INDEX IX_categories_name
        ON dbo.categories (category_name)
        INCLUDE (super_category_id);
GO

-- ============================================================
-- SECTION 15: SENDED
-- PK composite la (u_user_id, n_no_id) -- u_user_id lookups dung clustered.
-- n_no_id o vi tri thu 2 can index rieng cho reverse lookup.
-- u_user_id (phan PK composite) duoc SQL Server tu them lam row locator.
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_sended_no_id' AND object_id = OBJECT_ID('dbo.sended'))
    CREATE NONCLUSTERED INDEX IX_sended_no_id
        ON dbo.sended (n_no_id)
        INCLUDE (sent_time);
GO

PRINT 'All nonclustered indexes have been created successfully.';
GO
