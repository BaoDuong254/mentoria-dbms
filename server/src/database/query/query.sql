-- Testcase 1: Plan cache

-- Lần 1: xóa cache, đo cold execution
DBCC FREEPROCCACHE;
SET STATISTICS TIME ON;
EXEC dbo.sp_SearchMentors
    @SkillName = N'React', @Page = 1, @Limit = 10;
SET STATISTICS TIME OFF;
GO

-- Lần 2: plan đã cache, đo warm execution
SET STATISTICS TIME ON;
EXEC dbo.sp_SearchMentors
    @SkillName = N'Python', @Page = 1, @Limit = 10;
SET STATISTICS TIME OFF;
GO

-- Testcase 2: Query Translation Pipeline

SELECT u.user_id,
       u.first_name + N' ' + u.last_name AS mentor_name,
       m.rating,
       COUNT(DISTINCT mt.meeting_id)  AS recent_completed,
       SUM(inv.amount_total)          AS revenue_365d
FROM users u
JOIN mentors m  ON u.user_id = m.user_id
JOIN set_skill ss ON m.user_id = ss.mentor_id
JOIN skills sk    ON ss.skill_id = sk.skill_id
JOIN meetings mt  ON m.user_id = mt.mentor_id
JOIN invoices inv  ON mt.invoice_id = inv.invoice_id
WHERE sk.skill_name       = N'React'
  AND m.rating     >= 4.0
  AND u.country    = N'United States'
  AND mt.status    = N'Completed'
  AND mt.date      >= DATEADD(DAY, -365, GETDATE())
  AND inv.payment_status = N'paid'
GROUP BY u.user_id, u.first_name, u.last_name, m.rating
ORDER BY revenue_365d DESC;

-- Testcase 3: Heuristic Optimization — Predicate Pushdown

DBCC FREEPROCCACHE;
GO

-- Lần 1: Date range 12 tháng — filter rộng, invoices scan lớn nhất
DECLARE @S1 DATETIME = DATEADD(MONTH, -12, GETDATE()), @E1 DATETIME = GETDATE();
SET STATISTICS IO ON;
EXEC dbo.sp_DashboardStatistics
    @GroupBy   = N'mentor',
    @StartDate = @S1,
    @EndDate   = @E1
WITH RECOMPILE;
SET STATISTICS IO OFF;
GO

-- Lần 2: Date range 3 tháng — invoices scan nhỏ hơn, logical reads giảm rõ rệt
DECLARE @S2 DATETIME = DATEADD(MONTH, -3, GETDATE()), @E2 DATETIME = GETDATE();
SET STATISTICS IO ON;
EXEC dbo.sp_DashboardStatistics
    @GroupBy   = N'mentor',
    @StartDate = @S2,
    @EndDate   = @E2
WITH RECOMPILE;
SET STATISTICS IO OFF;
GO
