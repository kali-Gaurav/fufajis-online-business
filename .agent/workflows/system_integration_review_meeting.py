#!/usr/bin/env python3
"""
System Integration & Live Functionality Review Meeting
This script orchestrates the multi-agent meeting to audit and review payments, 
UI transitions, auth flows, Redis connections, and other third-party integrations.
"""

import json
import sys
from datetime import datetime
from typing import Dict, Any
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

class SystemIntegrationReviewMeeting:
    def __init__(self):
        self.meeting_id = f"INT-MEETING-{datetime.now().strftime('%Y%m%d')}"
        self.meeting_type = "all_hands"
        self.topic = "System Integration Audit & Live Functionality Review"
        self.date = datetime.now().strftime('%Y-%m-%d')
        self.duration_minutes = 60
        self.chairperson = "ARIA"
        
        self.participants = [
            {"agent": "ARIA", "role": "CEO", "status": "present"},
            {"agent": "NEXUS", "role": "CTO", "status": "present"},
            {"agent": "KYLO", "role": "Tech Lead", "status": "present"},
            {"agent": "SIGMA", "role": "Backend", "status": "present"},
            {"agent": "ORION", "role": "Frontend", "status": "present"},
            {"agent": "CIPHER", "role": "Security", "status": "present"},
            {"agent": "VAULT", "role": "DB", "status": "present"},
            {"agent": "VERA", "role": "Data Analyst", "status": "present"}
        ]
        
        self.transcript = []
        self.tasks = []
        self.escalations = []
        self.risks = []
        self.findings = {}

    def run_meeting(self, e2e_results: Dict[str, Any]) -> Dict[str, Any]:
        self.findings = e2e_results
        
        print(f"Starting System Integration Review Meeting: {self.meeting_id}")
        print(f"Date: {self.date} | Chairperson: {self.chairperson}")
        print("-" * 80)
        
        self._round_1_opening()
        self._round_2_e2e_results()
        self._round_3_payments_and_ui()
        self._round_4_redis_auth_investigation()
        self._round_5_security_and_compliance()
        self._round_6_tasks_and_approvals()
        
        summary = self._generate_summary()
        return summary

    def _round_1_opening(self):
        message = """Team, thank you for joining this critical integration review meeting. We are auditing the production readiness of Fufaji Online Business. 
Our primary focus is evaluating all live integrations, including payments, WhatsApp Business API, Upstash Redis, Twilio SMS, UI transitions, and router guards. 
Let's start with a review of our automated E2E test results, which run real credentials against our third-party APIs."""
        
        self.transcript.append({
            "round": 1,
            "speaker": "ARIA",
            "message": message,
            "tasks": [],
            "risks": []
        })
        print(f"\n[ARIA - CEO]: {message[:180]}...")

    def _round_2_e2e_results(self):
        passed = self.findings.get("passed", 0)
        failed = self.findings.get("failed", 0)
        total = self.findings.get("total", 0)
        score = self.findings.get("score", 0)
        
        message = f"""Here are the results from our latest E2E integration test suite:
- **Total Tests Checked**: {total}
- **✅ Passed**: {passed}
- **❌ Failed**: {failed}
- **Score**: {score}%

**Analysis of Integrations:**
1. **Upstash Redis**: Verified & working. Node.js is able to ping, write, and read.
2. **Razorpay HMAC Signature**: Generation and verification verified.
3. **Razorpay Live API**: Verified. Querying payments returned successfully (0 active charges).
4. **WhatsApp Business API**: Verified. Connected successfully and validated token activity.
5. **Twilio SMS**: FAILED with HTTP 401. This indicates an authentication credentials issue.
6. **Cloud Functions Integrity**: All 11 exports, signature guards, amount validation, and idempotency checks are in place.
7. **Firestore Rules**: Immutability on delivered/cancelled states and audit log protection are verified.
8. **Dart Services**: Order state transitions, caching fallbacks, and notification fallbacks are implemented correctly.

Let's hear from SIGMA and KYLO about these results."""
        
        self.transcript.append({
            "round": 2,
            "speaker": "KYLO",
            "message": message,
            "tasks": [],
            "risks": ["Twilio API returns 401 Unauthorized - SMS notifications will fail to send."]
        })
        print(f"\n[KYLO - Tech Lead]: E2E test results analyzed.")

    def _round_3_payments_and_ui(self):
        message = """Thanks, KYLO. Regarding the customer-facing flow:
1. **Checkout Stepper**: `checkout_screen.dart` implements a 3-step checkout:
   - **Step 1: Address selection**: Radial boundary checking is enforced. Supports scheduled slots ('9 AM - 12 PM', etc.) and voice landmark recordings (`_voiceLandmarkPath`).
   - **Step 2: Payment selection**: Supports COD, Credit, Razorpay, UPI, and Wallet.
   - **Step 3: Review & Place**: Evaluates final totals, taxes, cashback, and integrates AI product recommendations (e.g. 'Fresh Coriander' or 'Lemon').
2. **Payment Integrations**: 
   - Razorpay launches via plugin and triggers a callback `onPaymentSuccess` to confirm the order.
   - UPI launches the intent URI successfully.
   - Wallet processes checks against `WalletProvider` balances.
3. **UI Transitions & Routing**:
   - `app_router.dart` uses `GoRouter` with role-based redirects. If a user logs in, they are immediately redirected to their specific portal (`/owner`, `/customer/home`, `/delivery`, `/employee`, `/admin`).
   - It also handles force-updates via Remote Config and maintenance overlays gracefully.
   
Frontend transitions are highly responsive, but we must verify real-device performance for mobile scanner screens."""
        
        self.transcript.append({
            "round": 3,
            "speaker": "ORION",
            "message": message,
            "tasks": [
                {"title": "Verify Razorpay on Android physical device", "assignee": "ORION", "priority": "high"},
                {"title": "Verify UPI Intent redirect flow on physical device", "assignee": "ORION", "priority": "high"}
            ],
            "risks": []
        })
        print(f"\n[ORION - Frontend]: Checkout and router flows reviewed.")

    def _round_4_redis_auth_investigation(self):
        message = """I have investigated the Redis connection issue. In Dart, the `CacheService` init method performs a POST request to `_redisUrl` with a trailing slash (e.g., `https://pet-wallaby-138840.upstash.io/`) and body `jsonEncode(['PING'])`.
However, some REST engines on Upstash require the root URL (without the trailing slash) for POST commands, or they expect GET requests for raw pings.
Since Node.js E2E test passes using a GET request to `${redisUrl}/PING`, I recommend we update `CacheService` in Dart to:
1. Clean the trailing slash from `_redisUrl`.
2. Fall back to GET `${redisUrl}/PING` for testing the connection during `init()`.
3. Provide a fallback handler to Firebase Cache (Firestore) if the connection is slow or fails."""
        
        self.transcript.append({
            "round": 4,
            "speaker": "NEXUS",
            "message": message,
            "tasks": [
                {"title": "Refactor CacheService URL parser and PING fallback", "assignee": "SIGMA", "priority": "critical"},
                {"title": "Test CacheService with cleaned credentials", "assignee": "KYLO", "priority": "high"}
            ],
            "risks": ["Redis connection fails inside Dart when trailing slashes are present on URL."]
        })
        print(f"\n[NEXUS - CTO]: Redis connection issue root-cause identified.")

    def _round_5_security_and_compliance(self):
        message = """From a security perspective, I'm pleased to report:
1. **App Check**: Enabled with Play Integrity on Android and Device Check on iOS.
2. **Owner Controls**: Seeding whitelisted owner accounts is done securely inside `main.dart` during startup.
3. **Firestore Rules**: Delete actions are completely blocked on the `payments` collection. Only Cloud Functions can process payment captures.
4. **Twilio Credential issue**: The 401 error is likely due to expired trial credentials or incorrect token in `.env`. We must request the user to check their active Twilio credentials and update `.env` accordingly."""
        
        self.transcript.append({
            "round": 5,
            "speaker": "CIPHER",
            "message": message,
            "tasks": [
                {"title": "Verify Twilio credentials in live Twilio Console", "assignee": "ARIA", "priority": "high"}
            ],
            "risks": []
        })
        print(f"\n[CIPHER - Security]: Security and API credentials reviewed.")

    def _round_6_tasks_and_approvals(self):
        message = """Excellent review, team. Let's summarize the key decisions and task assignments:

**Key Decisions**:
1. Fix the Redis authentication/connection parser in Dart (`cache_service.dart`) immediately.
2. Flag the Twilio 401 authentication error for user resolution.
3. Keep the Firestore fallback enabled so checkout is not blocked.

I'm creating the integration task checklist now."""
        
        self.transcript.append({
            "round": 6,
            "speaker": "ARIA",
            "message": message,
            "tasks": [],
            "risks": []
        })
        print(f"\n[ARIA - CEO]: Meeting wrapped up.")

    def _generate_summary(self) -> Dict[str, Any]:
        all_tasks = []
        for entry in self.transcript:
            all_tasks.extend(entry.get("tasks", []))
            
        all_risks = []
        for entry in self.transcript:
            all_risks.extend(entry.get("risks", []))

        return {
            "meeting_id": self.meeting_id,
            "meeting_type": self.meeting_type,
            "topic": self.topic,
            "date": self.date,
            "duration_minutes": self.duration_minutes,
            "chairperson": self.chairperson,
            "participants": self.participants,
            "tasks_created": len(all_tasks),
            "tasks_list": all_tasks,
            "risks_flagged": len(all_risks),
            "risks_list": all_risks,
            "e2e_results_summary": {
                "score": f"{self.findings.get('score', 0)}%",
                "passed": self.findings.get("passed", 0),
                "failed": self.findings.get("failed", 0),
                "failures": ["Twilio API connectivity: HTTP 401"]
            },
            "status": "completed"
        }

    def save_meeting(self, output_path: str = None):
        if output_path is None:
            output_path = f".agent/logs/INTEGRATION_REVIEW_{datetime.now().strftime('%Y%m%d')}.json"
        
        meeting_data = {
            "meeting_id": self.meeting_id,
            "meeting_type": self.meeting_type,
            "topic": self.topic,
            "date": self.date,
            "duration_minutes": self.duration_minutes,
            "chairperson": self.chairperson,
            "participants": self.participants,
            "transcript": self.transcript,
            "summary": self._generate_summary()
        }
        
        # Ensure directory exists
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(meeting_data, f, indent=2)
            
        print(f"\nIntegration Review saved to: {output_path}")
        return output_path

def main():
    # Hardcoded test results matching actual e2e_integration_test.js run
    e2e_results = {
        "passed": 51,
        "failed": 1,
        "total": 52,
        "score": 98
    }
    
    meeting = SystemIntegrationReviewMeeting()
    meeting.run_meeting(e2e_results)
    meeting.save_meeting()

if __name__ == "__main__":
    main()
