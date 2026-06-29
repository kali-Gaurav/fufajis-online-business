// ============================================================
//  Mission Control - Chief-of-Staff-lite (B5)
//
//  7:30 AM IST: composes a short bilingual "morning brief" from the
//  latest Business Analyst report plus the count of agent_tasks
//  awaiting the owner's approval, then pushes it to the owner via
//  FCM. Logged through the same withAgentRun wrapper as other
//  scheduled shifts (agent_runs + agent KPI updates).
// ============================================================

import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { withAgentRun } from './scheduledAgentRunner';
import { executeAgentTool } from './agentToolExecutor';

const db = admin.firestore();

export const CHIEF_OF_STAFF_AGENT_ID = 'chief_of_staff';

/**
 * Fetch the latest report with retry logic.
 * The Business Analyst runs at 6:30 AM, and this Chief-of-Staff runs at 7:30 AM.
 * Verifies that the report generatedAt timestamp matches today's date in IST.
 * If the latest report is from a previous day, retries or falls back to null.
 *
 * @param maxRetries - Maximum number of retry attempts (default: 5)
 * @returns Latest report document and its ID, or null if not found/outdated after retries
 */
async function fetchLatestReportWithRetry(
  maxRetries: number = 5
): Promise<{ report: admin.firestore.DocumentData | null; reportId: string | null }> {
  const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const reportSnap = await db
        .collection('reports')
        .orderBy('generatedAt', 'desc')
        .limit(1)
        .get();

      if (!reportSnap.empty) {
        const report = reportSnap.docs[0].data();
        const reportId = reportSnap.docs[0].id;
        
        // Verify the report date matches today's date in IST
        const generatedAt = (report.generatedAt as admin.firestore.Timestamp)?.toDate();
        if (generatedAt) {
          const nowIST = new Date(Date.now() + IST_OFFSET_MS);
          const generatedIST = new Date(generatedAt.getTime() + IST_OFFSET_MS);

          const isToday = nowIST.getUTCDate() === generatedIST.getUTCDate() &&
                          nowIST.getUTCMonth() === generatedIST.getUTCMonth() &&
                          nowIST.getUTCFullYear() === generatedIST.getUTCFullYear();

          if (isToday) {
            console.log(`[ChiefOfStaff] Found today's report on attempt ${attempt}: ${reportId}`);
            return { report, reportId };
          } else {
            console.log(`[ChiefOfStaff] Latest report found is outdated (generated on ${generatedIST.toISOString().split('T')[0]}).`);
          }
        }
      }

      // Report not found yet or is outdated. If this is not the last attempt, wait and retry.
      if (attempt < maxRetries) {
        const delayMs = Math.min(1000 * Math.pow(2, attempt - 1), 8000); // Exponential backoff: 1s, 2s, 4s, 8s, 8s
        console.log(
          `[ChiefOfStaff] Today's report not found on attempt ${attempt}/${maxRetries}. ` +
            `Retrying in ${delayMs}ms...`
        );
        await new Promise((resolve) => setTimeout(resolve, delayMs));
      }
    } catch (err) {
      console.error(`[ChiefOfStaff] Query error on attempt ${attempt}:`, err);
      if (attempt < maxRetries) {
        const delayMs = Math.min(1000 * Math.pow(2, attempt - 1), 8000);
        await new Promise((resolve) => setTimeout(resolve, delayMs));
      }
    }
  }

  console.warn(
    `[ChiefOfStaff] Today's report not found after ${maxRetries} attempts. ` +
      `Business Analyst may have failed to run or reports collection is empty. Falling back.`
  );
  return { report: null, reportId: null };
}


/**
 * Builds the bilingual brief text from the latest report's
 * narrative + insight count and the number of items waiting on the
 * owner.
 */
function composeBrief(
  latestReport: admin.firestore.DocumentData | null,
  needsYouCount: number
): { title_en: string; body_en: string; title_hi: string; body_hi: string } {
  const insightCount = Array.isArray(latestReport?.insights) ? latestReport!.insights.length : 0;

  const needsYouText =
    needsYouCount === 0
      ? 'Nothing needs you right now.'
      : needsYouCount === 1
      ? '1 thing needs you.'
      : `${needsYouCount} things need you.`;

  const needsYouTextHi =
    needsYouCount === 0
      ? 'अभी आपकी ज़रूरत किसी काम में नहीं है।'
      : `${needsYouCount} काम आपकी मंज़ूरी के लिए तैयार ${needsYouCount === 1 ? 'है' : 'हैं'}।`;

  const ideasText = insightCount > 0 ? ` ${insightCount} idea(s) ready in today's report.` : '';
  const ideasTextHi = insightCount > 0 ? ` आज की रिपोर्ट में ${insightCount} सुझाव तैयार हैं।` : '';

  const title_en = '☕ Good morning';
  const title_hi = '☕ शुभ प्रभात';

  const body_en = latestReport
    ? `${needsYouText}${ideasText}`
    : `${needsYouText} No report is available yet - the Business Analyst will run soon.`;

  const body_hi = latestReport
    ? `${needsYouTextHi}${ideasTextHi}`
    : `${needsYouTextHi} अभी कोई रिपोर्ट तैयार नहीं है - बिज़नेस एनालिस्ट जल्द चलेगा।`;

  return { title_en, body_en, title_hi, body_hi };
}

async function sendOwnerPush(
  brief: { title_en: string; body_en: string; title_hi: string; body_hi: string },
  needsYouCount: number,
  reportId: string | null
): Promise<{ sent: number; failed: number }> {
  const usersSnap = await db
    .collection('users')
    .where('role', 'in', ['UserRole.owner', 'UserRole.manager', 'owner', 'manager'])
    .get();

  const tokens: string[] = [];
  usersSnap.forEach((doc) => {
    const token = doc.data().fcmToken;
    if (typeof token === 'string' && token.length > 0) tokens.push(token);
  });

  if (tokens.length === 0) {
    return { sent: 0, failed: 0 };
  }

  // English title/body with Hindi as a second line - keeps a single
  // notification while staying bilingual per spec principle 8.
  const title = brief.title_en;
  const body = `${brief.body_en}\n${brief.body_hi}`;

  try {
    const response = await admin.messaging().sendMulticast({
      tokens,
      notification: { title, body },
      data: {
        type: 'mission_control_morning_brief',
        needsYouCount: String(needsYouCount),
        reportId: reportId ?? '',
      },
    });
    return { sent: response.successCount, failed: response.failureCount };
  } catch (err) {
    console.error('[ChiefOfStaff] Failed to send morning brief push:', err);
    return { sent: 0, failed: tokens.length };
  }
}

/**
 * Chief-of-Staff-lite - 7:30 AM morning brief.
 * Runs after the Business Analyst's 6:30 AM daily shift completes,
 * summarizing the report and pending approvals.
 */
export const chiefOfStaffMorningBrief = functions
  .region('asia-south1')
  .pubsub.schedule('30 7 * * *')
  .timeZone('Asia/Kolkata')
  .onRun(async () => {
    await withAgentRun(CHIEF_OF_STAFF_AGENT_ID, 'morning_brief', async () => {
      // Fetch pending tasks in parallel with report retry logic
      const pendingTasksSnap = await db
        .collection('agent_tasks')
        .where('status', '==', 'awaiting_approval')
        .get();

      // Fetch latest report with retry logic (handles Firestore write latency)
      const { report: latestReport, reportId: latestReportId } =
        await fetchLatestReportWithRetry(5);

      const needsYouCount = pendingTasksSnap.size;

      const brief = composeBrief(latestReport, needsYouCount);
      const pushResult = await sendOwnerPush(brief, needsYouCount, latestReportId);

      // File the brief as a lightweight advisory task so it shows up
      // in the owner's activity history even if the push fails.
      await executeAgentTool(
        'create_task',
        {
          title: brief.title_en,
          description: `${brief.body_en}\n\n${brief.body_hi}`,
          type: 'morning_brief',
          autonomy: 'advisory',
          priority: needsYouCount > 0 ? 60 : 20,
          confidence: 1,
          evidence: [
            { label: 'needsYou', value: needsYouCount },
            { label: 'reportId', value: latestReportId ?? 'none' },
          ],
          payload: { reportId: latestReportId, needsYouCount },
          reasoning: 'Scheduled 7:30 AM morning brief.',
        },
        { agentId: CHIEF_OF_STAFF_AGENT_ID, reasoning: 'Scheduled 7:30 AM morning brief.' }
      );

      return {
        needsYouCount,
        reportId: latestReportId,
        pushSent: pushResult.sent,
        pushFailed: pushResult.failed,
      };
    });
    return null;
  });
