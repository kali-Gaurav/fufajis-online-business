// ============================================================================
// PUSH NOTIFICATION SERVICE — Firebase Cloud Messaging (FCM)
// ============================================================================
// Sends real-time notifications to mobile app
// Handles: Order updates, payment confirmations, delivery tracking
// ============================================================================

import { createServerClient } from "npm:@supabase/supabase-js";

const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SECRET_KEY = Deno.env.get("SUPABASE_SECRET_KEY");

interface NotificationRequest {
  userId: string;
  title: string;
  body: string;
  data?: Record<string, string>;
  imageUrl?: string;
  priority?: "high" | "normal";
  ttl?: number; // Time to live in seconds
}

// ============================================================================
// MAIN HANDLER
// ============================================================================

const handler = async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const notifReq: NotificationRequest = await req.json();

    if (!notifReq.userId || !notifReq.title || !notifReq.body) {
      return new Response(
        JSON.stringify({ error: "Missing userId, title, or body" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabase = createServerClient(SUPABASE_URL, SUPABASE_SECRET_KEY, {
      auth: { persistSession: false },
    });

    // Get user's FCM token
    const { data: customer } = await supabase
      .from("customers")
      .select("device_tokens")
      .eq("id", notifReq.userId)
      .single();

    if (!customer?.device_tokens || customer.device_tokens.length === 0) {
      console.log("No FCM tokens for user:", notifReq.userId);
      return new Response(
        JSON.stringify({ success: true, message: "No devices to notify" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Send to all user's devices
    const results = await Promise.all(
      customer.device_tokens.map((token: string) =>
        sendFCMNotification(token, notifReq)
      )
    );

    const successful = results.filter((r) => r.success).length;
    const failed = results.filter((r) => !r.success).length;

    // Log notification sent
    await logNotificationSent(notifReq, successful, failed, supabase);

    return new Response(
      JSON.stringify({
        success: true,
        sent: successful,
        failed,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Notification handler error:", error);
    return new Response(
      JSON.stringify({
        error: "Failed to send notification",
        details: error instanceof Error ? error.message : "Unknown error",
      }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
};

// ============================================================================
// FCM INTEGRATION
// ============================================================================

async function sendFCMNotification(
  deviceToken: string,
  notifReq: NotificationRequest
): Promise<{ success: boolean; error?: string }> {
  try {
    if (!FCM_SERVER_KEY) {
      throw new Error("FCM_SERVER_KEY not configured");
    }

    const payload = {
      message: {
        token: deviceToken,
        notification: {
          title: notifReq.title,
          body: notifReq.body,
          ...(notifReq.imageUrl && { image: notifReq.imageUrl }),
        },
        data: notifReq.data || {},
        android: {
          priority: notifReq.priority || "high",
          ttl: `${(notifReq.ttl || 86400)}s`,
          notification: {
            sound: "default",
            color: "#FF6B35", // Fufaji brand color
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: notifReq.title,
                body: notifReq.body,
              },
              sound: "default",
              badge: 1,
            },
          },
        },
        webpush: {
          notification: {
            title: notifReq.title,
            body: notifReq.body,
            icon: "https://fufaji.store/icon-192x192.png",
          },
        },
      },
    };

    const response = await fetch(
      "https://fcm.googleapis.com/v1/projects/fufaji-store/messages:send",
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${await getFirebaseAccessToken()}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
      }
    );

    if (!response.ok) {
      const errorData = await response.json();
      console.error("FCM error:", response.status, errorData);

      // Handle specific errors
      if (response.status === 404) {
        // Invalid token - should be removed
        return { success: false, error: "Invalid token" };
      }

      return {
        success: false,
        error: `FCM returned ${response.status}`,
      };
    }

    const data = await response.json();
    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
    };
  }
}

// ============================================================================
// FIREBASE AUTHENTICATION (for FCM v1 API)
// ============================================================================

let cachedAccessToken: string | null = null;
let tokenExpiry: number = 0;

async function getFirebaseAccessToken(): Promise<string> {
  // Return cached token if still valid
  if (cachedAccessToken && Date.now() < tokenExpiry) {
    return cachedAccessToken;
  }

  // In production, use Firebase Admin SDK or service account JSON
  // This is a simplified example - use proper auth in production
  const firebaseServiceAccount = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");

  if (!firebaseServiceAccount) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT not configured");
  }

  // Parse service account
  const serviceAccount = JSON.parse(firebaseServiceAccount);

  // Create JWT
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: serviceAccount.client_email,
    scope:
      "https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: Math.floor(Date.now() / 1000) + 3600,
    iat: Math.floor(Date.now() / 1000),
  };

  // For production, sign with private key
  // This example uses an external token endpoint
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: createJWT(header, payload, serviceAccount.private_key),
    }),
  });

  const tokenData = await response.json();
  cachedAccessToken = tokenData.access_token;
  tokenExpiry = Date.now() + tokenData.expires_in * 1000;

  return cachedAccessToken;
}

function createJWT(header: any, payload: any, privateKey: string): string {
  // Simplified JWT creation - use proper library in production
  const headerEncoded = btoa(JSON.stringify(header));
  const payloadEncoded = btoa(JSON.stringify(payload));

  // In production, sign with private key properly
  // This is a placeholder
  return `${headerEncoded}.${payloadEncoded}.signature`;
}

// ============================================================================
// BATCH NOTIFICATIONS (for campaigns)
// ============================================================================

async function sendBatchNotifications(
  userIds: string[],
  notifReq: Omit<NotificationRequest, "userId">,
  supabase: any
): Promise<{ successful: number; failed: number }> {
  let successful = 0;
  let failed = 0;

  for (const userId of userIds) {
    try {
      const result = await (
        await fetch(
          `${SUPABASE_URL}/functions/v1/send-notification`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${SUPABASE_SECRET_KEY}`,
            },
            body: JSON.stringify({ userId, ...notifReq }),
          }
        )
      ).json();

      if (result.success) successful++;
      else failed++;
    } catch (error) {
      console.error(`Failed to notify ${userId}:`, error);
      failed++;
    }

    // Rate limiting
    await new Promise((resolve) => setTimeout(resolve, 50));
  }

  return { successful, failed };
}

// ============================================================================
// LOGGING
// ============================================================================

async function logNotificationSent(
  notifReq: NotificationRequest,
  successful: number,
  failed: number,
  supabase: any
): Promise<void> {
  try {
    await supabase.from("notification_log").insert({
      user_id: notifReq.userId,
      title: notifReq.title,
      body: notifReq.body,
      data: notifReq.data || {},
      successful_count: successful,
      failed_count: failed,
      sent_at: new Date().toISOString(),
    });
  } catch (error) {
    console.error("Failed to log notification:", error);
  }
}

export default handler;
