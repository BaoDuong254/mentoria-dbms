/**
 * seed-slot-cassandra.ts
 *
 * Populates the Cassandra `mentor_slots` table using SQL Server as the
 * authoritative source for mentor/plan metadata.
 *
 * Slot-generation logic mirrors seed-slot.ts exactly:
 *   - 14-day window from today (UTC)
 *   - 9 base start times per day
 *   - Up to 2 non-overlapping slots per plan per day
 *
 * Idempotency: before every INSERT the script does a full-primary-key
 * SELECT (mentor_id + slot_date + start_time).  No ALLOW FILTERING used.
 *
 * UUID mapping (deterministic, matches cassandra_insert_data.cql):
 *   user_id  N  →  a1000000-0000-0000-0000-NNNNNNNNNNNN
 *   plan_id  N  →  b2000000-0000-0000-0000-NNNNNNNNNNNN
 *   slot_id     →  c3000000-0000-0000-0000-NNNNNNNNNNNN  (global counter)
 */

import { types as CassandraTypes, type Client } from "cassandra-driver";
import chalk from "chalk";
import poolPromise from "@/config/database";
import { getCassandraClient, closeCassandraClient } from "@/config/cassandra";

// ─── Domain types ─────────────────────────────────────────────────────────────

type PlanCategory = "session" | "mentorship";

interface SqlMentorPlanRow {
  user_id: number;
  email: string;
  plan_id: number;
  plan_type: string;
  plan_charge: number;
  sessions_duration: number | null;
  minutes_per_call: number | null;
}

interface PlanInfo {
  planId: number;
  planType: string;
  planCharge: number;
  duration: number; // minutes
  planCategory: PlanCategory;
}

interface MentorData {
  email: string;
  plans: PlanInfo[];
}

interface TimeSlot {
  hour: number;
  minute: number;
}

interface OccupiedRange {
  start: Date;
  end: Date;
}

// ─── UUID helpers ─────────────────────────────────────────────────────────────

function userUuid(id: number): string {
  return `a1000000-0000-0000-0000-${id.toString().padStart(12, "0")}`;
}

function planUuid(id: number): string {
  return `b2000000-0000-0000-0000-${id.toString().padStart(12, "0")}`;
}

function slotUuid(counter: number): string {
  return `c3000000-0000-0000-0000-${counter.toString().padStart(12, "0")}`;
}

// ─── Time helpers ─────────────────────────────────────────────────────────────

/** Returns true when [s1, e1) and [s2, e2) overlap. */
function isOverlapping(s1: Date, e1: Date, s2: Date, e2: Date): boolean {
  return s1 < e2 && s2 < e1;
}

// ─── Slot-generation config ───────────────────────────────────────────────────

const BASE_TIME_SLOTS: TimeSlot[] = [
  { hour: 9, minute: 0 },
  { hour: 10, minute: 0 },
  { hour: 11, minute: 0 },
  { hour: 13, minute: 0 },
  { hour: 14, minute: 0 },
  { hour: 15, minute: 0 },
  { hour: 16, minute: 0 },
  { hour: 18, minute: 0 },
  { hour: 19, minute: 0 },
];

const DAYS_AHEAD = 14;
const MAX_SLOTS_PER_PLAN_PER_DAY = 2;

// ─── SQL: fetch mentor-plan metadata ─────────────────────────────────────────

async function fetchMentorPlans(): Promise<Map<number, MentorData>> {
  const pool = await poolPromise;
  if (!pool) throw new Error("SQL Server connection unavailable");

  const result = await pool.request().query<SqlMentorPlanRow>(`
    SELECT DISTINCT
      u.user_id,
      u.email,
      p.plan_id,
      p.plan_type,
      p.plan_charge,
      ps.sessions_duration,
      pm.minutes_per_call
    FROM users u
    INNER JOIN mentors m ON u.user_id = m.user_id
    INNER JOIN plans p ON m.user_id = p.mentor_id
    LEFT JOIN plan_sessions    ps ON p.plan_id = ps.sessions_id
    LEFT JOIN plan_mentorships pm ON p.plan_id = pm.mentorships_id
    WHERE u.role = 'Mentor'
    ORDER BY u.user_id, p.plan_id
  `);

  const mentorMap = new Map<number, MentorData>();

  for (const row of result.recordset) {
    let duration: number;
    let planCategory: PlanCategory;

    if (row.sessions_duration != null) {
      duration = row.sessions_duration;
      planCategory = "session";
    } else if (row.minutes_per_call != null) {
      duration = row.minutes_per_call;
      planCategory = "mentorship";
    } else {
      continue; // plan has no resolvable duration — skip
    }

    if (!mentorMap.has(row.user_id)) {
      mentorMap.set(row.user_id, { email: row.email, plans: [] });
    }

    mentorMap.get(row.user_id)!.plans.push({
      planId: row.plan_id,
      planType: row.plan_type,
      planCharge: row.plan_charge,
      duration,
      planCategory,
    });
  }

  return mentorMap;
}

// ─── Cassandra: idempotency check and insert ──────────────────────────────────

// Full-primary-key SELECT — no ALLOW FILTERING needed because we supply all
// three components of PRIMARY KEY ((mentor_id, slot_date), start_time).
const SELECT_SLOT_CQL = `
  SELECT start_time
  FROM   mentor_slots
  WHERE  mentor_id  = ?
    AND  slot_date  = ?
    AND  start_time = ?
`;

const INSERT_SLOT_CQL = `
  INSERT INTO mentor_slots
    (mentor_id, slot_date, start_time, end_time, slot_id,
     status, plan_id, plan_type, plan_charge)
  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
`;

async function slotExistsInCassandra(
  client: Client,
  mentorUuidStr: string,
  slotDate: CassandraTypes.LocalDate,
  startTime: Date
): Promise<boolean> {
  const rs = await client.execute(SELECT_SLOT_CQL, [mentorUuidStr, slotDate, startTime], { prepare: true });
  return rs.rowLength > 0;
}

async function insertSlotIntoCassandra(
  client: Client,
  params: {
    mentorUuidStr: string;
    slotDate: CassandraTypes.LocalDate;
    startTime: Date;
    endTime: Date;
    slotUuidStr: string;
    planUuidStr: string;
    planType: string;
    planCharge: number;
  }
): Promise<void> {
  await client.execute(
    INSERT_SLOT_CQL,
    [
      params.mentorUuidStr,
      params.slotDate,
      params.startTime,
      params.endTime,
      params.slotUuidStr,
      "Available",
      params.planUuidStr,
      params.planType,
      params.planCharge,
    ],
    { prepare: true }
  );
}

// ─── Core seeding logic ───────────────────────────────────────────────────────

async function seedCassandraSlots(): Promise<void> {
  // 1. Fetch source data from SQL Server
  console.log(chalk.yellow("  Fetching mentor/plan data from SQL Server..."));
  const mentorMap = await fetchMentorPlans();
  console.log(chalk.yellow(`  Found ${mentorMap.size} mentor(s).`));

  // 2. Open Cassandra connection
  const cassClient = await getCassandraClient();

  // Anchor today at UTC midnight to avoid local-timezone date drift
  const nowUtc = new Date();
  const todayMidnightUtc = new Date(Date.UTC(nowUtc.getUTCFullYear(), nowUtc.getUTCMonth(), nowUtc.getUTCDate()));

  let slotCounter = 0; // global counter → deterministic slot UUIDs
  let insertedCount = 0;
  let skippedCount = 0;

  // 3. Iterate days → mentors → plans → time-slot candidates
  for (let dayOffset = 0; dayOffset < DAYS_AHEAD; dayOffset++) {
    // Derive UTC date components for this day
    const dayMs = todayMidnightUtc.getTime() + dayOffset * 24 * 60 * 60 * 1000;
    const dayDate = new Date(dayMs);
    const year = dayDate.getUTCFullYear();
    const month = dayDate.getUTCMonth(); // 0-based (used in Date.UTC)
    const day = dayDate.getUTCDate();

    // cassandra-driver LocalDate: month is 1-based
    const cassandraDate = new CassandraTypes.LocalDate(year, month + 1, day);

    // Track occupied time ranges for each mentor on this day so we never
    // insert overlapping slots even across different plans.
    const mentorOccupied = new Map<number, OccupiedRange[]>();

    for (const [mentorId, mentorData] of mentorMap) {
      if (!mentorOccupied.has(mentorId)) {
        mentorOccupied.set(mentorId, []);
      }
      const occupied = mentorOccupied.get(mentorId)!;
      const mentorUuidStr = userUuid(mentorId);

      // Shuffle plans so different plan types are distributed across time slots
      const shuffledPlans = [...mentorData.plans].sort(() => 0.5 - Math.random());

      for (const plan of shuffledPlans) {
        let slotsCreated = 0;

        for (const ts of BASE_TIME_SLOTS) {
          if (slotsCreated >= MAX_SLOTS_PER_PLAN_PER_DAY) break;

          // Build start/end in UTC to avoid date-boundary drift
          const startTime = new Date(Date.UTC(year, month, day, ts.hour, ts.minute, 0, 0));
          const endTime = new Date(startTime.getTime() + plan.duration * 60_000);

          // In-memory overlap check (fast — no DB round-trip)
          const overlaps = occupied.some((r) => isOverlapping(startTime, endTime, r.start, r.end));
          if (overlaps) continue;

          // Mark occupied regardless of whether we insert or skip (prevents
          // later plans from claiming an already-checked time window)
          occupied.push({ start: startTime, end: endTime });

          // Idempotency: full-primary-key SELECT — no ALLOW FILTERING
          const exists = await slotExistsInCassandra(cassClient, mentorUuidStr, cassandraDate, startTime);

          if (exists) {
            skippedCount++;
            slotsCreated++; // count as "used" to keep slot counts stable
            continue;
          }

          slotCounter++;
          await insertSlotIntoCassandra(cassClient, {
            mentorUuidStr,
            slotDate: cassandraDate,
            startTime,
            endTime,
            slotUuidStr: slotUuid(slotCounter),
            planUuidStr: planUuid(plan.planId),
            planType: plan.planType,
            planCharge: plan.planCharge,
          });

          insertedCount++;
          slotsCreated++;
        }
      }
    }

    const dateLabel = `${year}-${String(month + 1).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
    console.log(
      chalk.gray(
        `    Day ${String(dayOffset + 1).padStart(2, " ")}/${DAYS_AHEAD} (${dateLabel}) — inserted so far: ${insertedCount}`
      )
    );
  }

  console.log(chalk.green(`\n  Inserted : ${insertedCount} slot(s)`));
  console.log(chalk.gray(`  Skipped  : ${skippedCount} duplicate(s)`));
}

// ─── Entry point ─────────────────────────────────────────────────────────────

async function run(): Promise<void> {
  try {
    console.log(chalk.blue("\n🕐 Starting Cassandra slot seeding...\n"));
    await seedCassandraSlots();
    console.log(chalk.blue("\n✅ Cassandra slot seeding completed successfully!\n"));
  } catch (error) {
    console.error(chalk.red("\n❌ Error seeding Cassandra slots:"), error);
    process.exit(1);
  } finally {
    await closeCassandraClient();
    process.exit(0);
  }
}

run();
