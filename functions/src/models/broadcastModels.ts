/**
 * Broadcast Models for Mission Control
 *
 * Defines the data structures for marketing & comms agent broadcasts,
 * including drafts, limits, and delivery statistics.
 */

import * as admin from 'firebase-admin';

/**
 * Broadcast segment/audience type
 */
export type BroadcastSegment = 'all' | 'vip' | 'inactive' | 'regional' | string;

/**
 * Broadcast delivery status
 */
export type BroadcastStatus = 'draft' | 'scheduled' | 'sending' | 'sent' | 'partial' | 'failed';

/**
 * Delivery statistics for a broadcast
 */
export interface BroadcastStats {
  sent: number;
  delivered: number;
  opened: number;
  failed: number;
  bounced: number;
  queued: number;
}

/**
 * A single broadcast draft/campaign
 *
 * Documents stored at: broadcasts/{broadcastId}
 */
export interface BroadcastDraft {
  id: string;
  title: string;
  body: string;
  targetSegment: BroadcastSegment;
  scheduledAt?: admin.firestore.Timestamp;
  createdBy: string;
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
  status: BroadcastStatus;
  stats: BroadcastStats;
  metadata?: {
    campaignId?: string;
    tags?: string[];
    notes?: string;
  };
}

/**
 * Broadcast rate limits and constraints
 *
 * Document stored at: broadcastConfig/limits
 */
export interface BroadcastLimit {
  maxPerDay: number; // Max broadcasts per calendar day (IST)
  maxPerHour: number; // Max broadcasts per hour
  maxPerMinute: number; // Max broadcasts per minute (for burst protection)
  quietHours: {
    startHour: number; // 0-23, 24-hour IST
    endHour: number; // 0-23
    enabled: boolean;
  };
  maxSegmentSize: number; // Max users per broadcast
  minIntervalMinutes: number; // Min time between consecutive broadcasts
  retryAttempts: number; // Max delivery retry attempts
  retryDelayMs: number; // Initial retry delay (exponential backoff)
}

/**
 * Broadcast segment query configuration
 *
 * Used to dynamically filter users for targeted broadcasts
 */
export interface BroadcastSegmentConfig {
  segment: BroadcastSegment;
  query: {
    collection: string;
    where?: Array<{
      field: string;
      operator: '<' | '<=' | '==' | '!=' | '>=' | '>' | 'array-contains' | 'in';
      value: unknown;
    }>;
    orderBy?: Array<{
      field: string;
      direction: 'asc' | 'desc';
    }>;
  };
  description: string;
}

/**
 * Broadcast delivery event (audit trail)
 *
 * Documents stored at: broadcasts/{broadcastId}/deliveryLog/{eventId}
 */
export interface BroadcastDeliveryEvent {
  id: string;
  broadcastId: string;
  timestamp: admin.firestore.Timestamp;
  eventType: 'sent' | 'delivered' | 'opened' | 'failed' | 'bounced' | 'queued';
  recipientCount: number;
  details?: {
    errorCode?: string;
    errorMessage?: string;
    fcmResponse?: {
      successCount: number;
      failureCount: number;
    };
  };
}

/**
 * Convert Firestore document to BroadcastDraft
 */
export function documentToBroadcastDraft(
  id: string,
  data: admin.firestore.DocumentData
): BroadcastDraft {
  return {
    id,
    title: data.title || '',
    body: data.body || '',
    targetSegment: data.targetSegment || 'all',
    scheduledAt: data.scheduledAt,
    createdBy: data.createdBy || 'system',
    createdAt: data.createdAt || admin.firestore.Timestamp.now(),
    updatedAt: data.updatedAt || admin.firestore.Timestamp.now(),
    status: data.status || 'draft',
    stats: {
      sent: data.stats?.sent || 0,
      delivered: data.stats?.delivered || 0,
      opened: data.stats?.opened || 0,
      failed: data.stats?.failed || 0,
      bounced: data.stats?.bounced || 0,
      queued: data.stats?.queued || 0,
    },
    metadata: data.metadata,
  };
}

/**
 * Convert BroadcastDraft to Firestore document
 */
export function broadcastDraftToDocument(draft: BroadcastDraft): Record<string, unknown> {
  return {
    title: draft.title,
    body: draft.body,
    targetSegment: draft.targetSegment,
    scheduledAt: draft.scheduledAt,
    createdBy: draft.createdBy,
    createdAt: draft.createdAt,
    updatedAt: draft.updatedAt,
    status: draft.status,
    stats: draft.stats,
    metadata: draft.metadata,
  };
}

/**
 * Validate broadcast before sending
 */
export function validateBroadcast(draft: BroadcastDraft): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  if (!draft.title || draft.title.trim().length === 0) {
    errors.push('Title is required');
  }

  if (draft.title.length > 100) {
    errors.push('Title must be 100 characters or less');
  }

  if (!draft.body || draft.body.trim().length === 0) {
    errors.push('Body is required');
  }

  if (draft.body.length > 500) {
    errors.push('Body must be 500 characters or less');
  }

  if (!draft.targetSegment) {
    errors.push('Target segment is required');
  }

  if (draft.scheduledAt && draft.scheduledAt.toDate() < new Date()) {
    errors.push('Scheduled time must be in the future');
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

/**
 * Default broadcast limits (can be overridden per shop/owner)
 */
export const DEFAULT_BROADCAST_LIMITS: BroadcastLimit = {
  maxPerDay: 5,
  maxPerHour: 1,
  maxPerMinute: 0, // Disabled by default, set to >0 for burst protection
  quietHours: {
    startHour: 21, // 9 PM IST
    endHour: 7, // 7 AM IST
    enabled: true,
  },
  maxSegmentSize: 50000,
  minIntervalMinutes: 60,
  retryAttempts: 3,
  retryDelayMs: 1000, // 1 second initial, exponential backoff
};

/**
 * Default segment configurations
 */
export const DEFAULT_SEGMENT_CONFIGS: Record<BroadcastSegment, BroadcastSegmentConfig> = {
  all: {
    segment: 'all',
    query: {
      collection: 'users',
    },
    description: 'All users',
  },
  vip: {
    segment: 'vip',
    query: {
      collection: 'users',
      where: [
        {
          field: 'role',
          operator: '==',
          value: 'customer',
        },
        {
          field: 'totalOrders',
          operator: '>=',
          value: 10,
        },
      ],
    },
    description: 'VIP customers (10+ orders)',
  },
  inactive: {
    segment: 'inactive',
    query: {
      collection: 'users',
      where: [
        {
          field: 'role',
          operator: '==',
          value: 'customer',
        },
        {
          field: 'lastSeenAt',
          operator: '<',
          value: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000), // 30 days ago
        },
      ],
    },
    description: 'Inactive users (no activity in 30 days)',
  },
  regional: {
    segment: 'regional',
    query: {
      collection: 'users',
      where: [
        {
          field: 'region',
          operator: '!=',
          value: null,
        },
      ],
    },
    description: 'Users with location data',
  },
};
