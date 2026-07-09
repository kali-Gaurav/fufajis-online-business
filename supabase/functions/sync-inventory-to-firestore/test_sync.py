#!/usr/bin/env python3
"""
Local testing script for inventory sync function
Tests the sync function against development/staging environment
"""

import os
import sys
import json
import time
import requests
from datetime import datetime
from typing import Dict, Any, Optional
import argparse

# Colors for output
class Colors:
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    RESET = '\033[0m'

def log_success(msg: str):
    print(f"{Colors.GREEN}✓ {msg}{Colors.RESET}")

def log_warning(msg: str):
    print(f"{Colors.YELLOW}⚠ {msg}{Colors.RESET}")

def log_error(msg: str):
    print(f"{Colors.RED}✗ {msg}{Colors.RESET}")

def log_info(msg: str):
    print(f"{Colors.BLUE}ℹ {msg}{Colors.RESET}")

class InventorySyncTester:
    def __init__(self,
                 function_url: str,
                 cron_secret: str,
                 supabase_url: Optional[str] = None,
                 supabase_key: Optional[str] = None):
        self.function_url = function_url
        self.cron_secret = cron_secret
        self.supabase_url = supabase_url
        self.supabase_key = supabase_key
        self.session = requests.Session()

    def test_auth_failure(self) -> bool:
        """Test that missing/wrong auth fails"""
        log_info("Testing auth failure (should return 401)...")

        # Missing secret
        response = self.session.post(self.function_url)
        if response.status_code == 401:
            log_success("Missing secret correctly rejected (401)")
        else:
            log_error(f"Expected 401, got {response.status_code}")
            return False

        # Wrong secret
        response = self.session.post(
            self.function_url,
            headers={"X-Cron-Secret": "wrong-secret"}
        )
        if response.status_code == 401:
            log_success("Wrong secret correctly rejected (401)")
        else:
            log_error(f"Expected 401, got {response.status_code}")
            return False

        return True

    def test_sync(self) -> Dict[str, Any]:
        """Run the actual sync"""
        log_info("Running inventory sync...")

        start_time = time.time()

        response = self.session.post(
            self.function_url,
            headers={
                "X-Cron-Secret": self.cron_secret,
                "Content-Type": "application/json"
            },
            json={}
        )

        duration = time.time() - start_time

        if response.status_code != 200:
            log_error(f"Sync failed with status {response.status_code}")
            log_error(f"Response: {response.text}")
            return None

        result = response.json()
        result['http_duration'] = duration

        return result

    def verify_firestore_sync(self) -> bool:
        """Check if Firestore has data after sync"""
        if not self.supabase_url or not self.supabase_key:
            log_warning("Supabase credentials not provided, skipping Firestore verification")
            return True

        log_info("Verifying Firestore sync (checking sync_logs)...")

        import psycopg2
        from urllib.parse import urlparse

        try:
            # Parse Supabase connection string
            # Format: postgresql://user:password@host:port/database
            parsed = urlparse(self.supabase_url.replace("postgres://", "postgresql://"))

            conn = psycopg2.connect(
                host=parsed.hostname,
                port=parsed.port or 5432,
                user=parsed.username,
                password=parsed.password,
                database=parsed.path.lstrip('/')
            )

            cursor = conn.cursor()

            # Query last sync
            cursor.execute("""
                SELECT status, synced_count, failed_count, synced_at
                FROM sync_logs
                WHERE sync_type = 'inventory_to_firestore'
                ORDER BY synced_at DESC
                LIMIT 1
            """)

            result = cursor.fetchone()
            cursor.close()
            conn.close()

            if result:
                status, synced_count, failed_count, synced_at = result
                log_success(f"Last sync: {status} at {synced_at}")
                log_info(f"  Synced: {synced_count}, Failed: {failed_count}")
                return status == 'success'
            else:
                log_warning("No sync logs found")
                return False

        except Exception as e:
            log_warning(f"Could not verify Firestore: {e}")
            return False

    def analyze_result(self, result: Dict[str, Any]) -> bool:
        """Analyze sync result and print details"""
        if not result:
            return False

        print("\n" + "="*60)
        print("SYNC RESULT")
        print("="*60)

        print(f"Timestamp: {result.get('timestamp')}")
        print(f"Total Products: {result.get('total_products', 0)}")
        print(f"Synced: {result.get('synced_count', 0)}")
        print(f"Failed: {result.get('failed_count', 0)}")
        print(f"Duration: {result.get('duration_ms', 0)}ms (HTTP: {result.get('http_duration', 0):.2f}s)")

        if result.get('errors'):
            print(f"\nErrors ({len(result['errors'])}):")
            for error in result['errors'][:5]:  # Show first 5
                print(f"  - {error['product_id']}: {error['reason']}")
            if len(result['errors']) > 5:
                print(f"  ... and {len(result['errors']) - 5} more")

        success_rate = 0
        if result.get('total_products', 0) > 0:
            success_rate = (result.get('synced_count', 0) / result.get('total_products', 1)) * 100

        print(f"\nSuccess Rate: {success_rate:.1f}%")

        if result.get('failed_count', 0) == 0:
            log_success("Sync completed successfully!")
            return True
        elif success_rate >= 95:
            log_warning(f"Sync mostly successful ({success_rate:.1f}%)")
            return True
        else:
            log_error(f"Sync had high failure rate ({success_rate:.1f}%)")
            return False

def main():
    parser = argparse.ArgumentParser(
        description="Test Fufaji inventory sync function"
    )

    parser.add_argument(
        "--url",
        required=True,
        help="Function URL (e.g., http://localhost:54321/functions/v1/sync-inventory-to-firestore)"
    )

    parser.add_argument(
        "--secret",
        required=True,
        help="Cron secret (INVENTORY_SYNC_CRON_SECRET)"
    )

    parser.add_argument(
        "--supabase-url",
        help="Supabase database URL (for verification)"
    )

    parser.add_argument(
        "--supabase-key",
        help="Supabase API key"
    )

    parser.add_argument(
        "--skip-auth-test",
        action="store_true",
        help="Skip auth failure tests"
    )

    parser.add_argument(
        "--skip-firestore-verify",
        action="store_true",
        help="Skip Firestore verification"
    )

    args = parser.parse_args()

    print("╔════════════════════════════════════════════════════════╗")
    print("║  Fufaji Inventory Sync - Function Tester              ║")
    print("╚════════════════════════════════════════════════════════╝")
    print()

    tester = InventorySyncTester(
        function_url=args.url,
        cron_secret=args.secret,
        supabase_url=args.supabase_url,
        supabase_key=args.supabase_key
    )

    all_passed = True

    # Test 1: Auth
    if not args.skip_auth_test:
        print("\n[Test 1/3] Authentication")
        print("-" * 60)
        if not tester.test_auth_failure():
            all_passed = False

    # Test 2: Sync
    print("\n[Test 2/3] Inventory Sync")
    print("-" * 60)
    result = tester.test_sync()
    if not result:
        all_passed = False
    else:
        if not tester.analyze_result(result):
            all_passed = False

    # Test 3: Verification
    if not args.skip_firestore_verify:
        print("\n[Test 3/3] Firestore Verification")
        print("-" * 60)
        if not tester.verify_firestore_sync():
            all_passed = False

    # Summary
    print("\n" + "="*60)
    if all_passed:
        log_success("All tests passed!")
        return 0
    else:
        log_error("Some tests failed")
        return 1

if __name__ == "__main__":
    sys.exit(main())
