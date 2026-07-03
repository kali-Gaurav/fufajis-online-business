# LOOP 1.5 - Unknown Product Rejection Fix Verification
# Run both test suites with proper output capture

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "LOOP 1.5 BUGFIX - Unknown Product Fix" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Run QA Tests
Write-Host "Running QA Tests (Gate 2)..." -ForegroundColor Yellow
flutter test test/voice_ordering_qa_tests.dart -v 2>&1 | tee qa_results_final.log

Write-Host ""
Write-Host "Running Cart Tests (Gate 5)..." -ForegroundColor Yellow
flutter test test/voice_cart_inventory_tests.dart -v 2>&1 | tee cart_results_final.log

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "VERIFICATION - Checking Output" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Check for key success indicators
$qaLog = Get-Content qa_results_final.log | Select-String "Parsed|All tests"
$cartLog = Get-Content cart_results_final.log | Select-String "passed"

Write-Host ""
Write-Host "QA Results:" -ForegroundColor Green
$qaLog | Select-Object -Last 20

Write-Host ""
Write-Host "Cart Results:" -ForegroundColor Green
$cartLog

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "CRITICAL CHECKS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Check for fractional quantity fix
if ((Get-Content qa_results_final.log) -match 'butter.*x0.5.*kg') {
    Write-Host "✅ Fractional quantities: WORKING" -ForegroundColor Green
} else {
    Write-Host "❌ Fractional quantities: FAILED" -ForegroundColor Red
}

# Check for unknown product rejection
if ((Get-Content qa_results_final.log) -match 'xyz abc def.*conf.*0.05|conf.*0.0') {
    Write-Host "✅ Unknown product rejection: WORKING" -ForegroundColor Green
} else {
    Write-Host "⚠️  Unknown product confidence may not be optimal" -ForegroundColor Yellow
    Get-Content qa_results_final.log | Select-String "xyz abc def"
}

# Check test pass rate
if ((Get-Content qa_results_final.log) -match 'All.*29.*passed') {
    Write-Host "✅ QA Tests: 29/29 PASSED" -ForegroundColor Green
} elseif ((Get-Content qa_results_final.log) -match 'All tests passed') {
    Write-Host "✅ QA Tests: PASSED" -ForegroundColor Green
} else {
    Write-Host "❌ QA Tests: FAILED" -ForegroundColor Red
}

Write-Host ""
Write-Host "Done! Review logs for details:" -ForegroundColor Cyan
Write-Host "  - qa_results_final.log" -ForegroundColor Gray
Write-Host "  - cart_results_final.log" -ForegroundColor Gray
