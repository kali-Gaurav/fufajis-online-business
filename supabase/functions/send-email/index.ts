// ============================================================================
// EMAIL SERVICE — Production Edge Function
// ============================================================================
// Integrates with SendGrid for reliable transactional emails
// Handles: Order confirmations, receipts, notifications, password resets
// ============================================================================

import { createServerClient } from "npm:@supabase/supabase-js";

const SENDGRID_API_KEY = Deno.env.get("SENDGRID_API_KEY");
const SENDGRID_FROM_EMAIL = Deno.env.get("SENDGRID_FROM_EMAIL") || "noreply@fufaji.store";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SECRET_KEY = Deno.env.get("SUPABASE_SECRET_KEY");

interface EmailRequest {
  to: string;
  templateId: string; // SendGrid template ID
  dynamicTemplateData: Record<string, any>;
  bcc?: string[];
  replyTo?: string;
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
    const emailReq: EmailRequest = await req.json();

    // Validate
    if (!emailReq.to || !emailReq.templateId) {
      return new Response(
        JSON.stringify({ error: "Missing to or templateId" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!SENDGRID_API_KEY) {
      console.error("SENDGRID_API_KEY not set");
      return new Response(
        JSON.stringify({ error: "Email service not configured" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // Send email via SendGrid
    const result = await sendEmailViaSendGrid(emailReq);

    if (!result.success) {
      console.error("Failed to send email:", result.error);
      return new Response(
        JSON.stringify({ error: result.error }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // Log email sent (for tracking/analytics)
    const supabase = createServerClient(SUPABASE_URL, SUPABASE_SECRET_KEY, {
      auth: { persistSession: false },
    });

    await logEmailSent(emailReq, result.messageId, supabase);

    return new Response(
      JSON.stringify({ success: true, messageId: result.messageId }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Email handler error:", error);
    return new Response(
      JSON.stringify({
        error: "Failed to send email",
        details: error instanceof Error ? error.message : "Unknown error",
      }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
};

// ============================================================================
// SENDGRID INTEGRATION
// ============================================================================

async function sendEmailViaSendGrid(
  emailReq: EmailRequest
): Promise<{ success: boolean; messageId?: string; error?: string }> {
  try {
    const payload = {
      from: {
        email: SENDGRID_FROM_EMAIL,
        name: "Fufaji Store",
      },
      personalizations: [
        {
          to: [{ email: emailReq.to }],
          ...(emailReq.bcc && { bcc: emailReq.bcc.map((email) => ({ email })) }),
          dynamic_template_data: emailReq.dynamicTemplateData,
        },
      ],
      template_id: emailReq.templateId,
      ...(emailReq.replyTo && { reply_to: { email: emailReq.replyTo } }),
    };

    const response = await fetch("https://api.sendgrid.com/v3/mail/send", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${SENDGRID_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      const errorData = await response.text();
      console.error("SendGrid error:", response.status, errorData);
      return {
        success: false,
        error: `SendGrid returned ${response.status}`,
      };
    }

    // Extract message ID from response headers
    const messageId = response.headers.get("X-Message-Id") || "unknown";

    return { success: true, messageId };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
    };
  }
}

// ============================================================================
// TEMPLATE HELPERS
// ============================================================================

export const emailTemplates = {
  ORDER_CONFIRMATION: "d-YOUR_TEMPLATE_ID_ORDER_CONFIRMATION",
  PAYMENT_RECEIPT: "d-YOUR_TEMPLATE_ID_PAYMENT_RECEIPT",
  ORDER_SHIPPED: "d-YOUR_TEMPLATE_ID_ORDER_SHIPPED",
  DELIVERY_CONFIRMATION: "d-YOUR_TEMPLATE_ID_DELIVERY_CONFIRMATION",
  REFUND_PROCESSED: "d-YOUR_TEMPLATE_ID_REFUND_PROCESSED",
  PASSWORD_RESET: "d-YOUR_TEMPLATE_ID_PASSWORD_RESET",
  WEEKLY_DIGEST: "d-YOUR_TEMPLATE_ID_WEEKLY_DIGEST",
};

// ============================================================================
// BATCH EMAIL SENDING (for campaigns)
// ============================================================================

async function sendBatchEmails(
  recipients: Array<{ email: string; templateId: string; data: Record<string, any> }>,
  delayBetweenEmails: number = 100
): Promise<void> {
  for (const recipient of recipients) {
    try {
      await sendEmailViaSendGrid({
        to: recipient.email,
        templateId: recipient.templateId,
        dynamicTemplateData: recipient.data,
      });

      // Respect SendGrid rate limits
      await new Promise((resolve) => setTimeout(resolve, delayBetweenEmails));
    } catch (error) {
      console.error(`Failed to send email to ${recipient.email}:`, error);
      // Continue with next email
    }
  }
}

// ============================================================================
// LOGGING
// ============================================================================

async function logEmailSent(
  emailReq: EmailRequest,
  messageId: string,
  supabase: any
): Promise<void> {
  try {
    await supabase.from("email_log").insert({
      to: emailReq.to,
      template_id: emailReq.templateId,
      message_id: messageId,
      sent_at: new Date().toISOString(),
      status: "sent",
    });
  } catch (error) {
    console.error("Failed to log email:", error);
  }
}

// ============================================================================
// WEBHOOK HANDLER (for email events: bounce, open, click)
// ============================================================================

async function handleSendGridWebhook(
  req: Request,
  supabase: any
): Promise<Response> {
  try {
    const events = await req.json();

    for (const event of events) {
      await supabase.from("email_events").insert({
        message_id: event.sg_message_id,
        event_type: event.event, // delivered, opened, clicked, bounced, etc.
        timestamp: new Date(event.timestamp * 1000).toISOString(),
        payload: event,
      });
    }

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("SendGrid webhook error:", error);
    return new Response(JSON.stringify({ error: "Webhook processing failed" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
}

export default handler;
