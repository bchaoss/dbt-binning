Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " Running dbt_binning Integration Tests (PS)" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# 1. Initialize Seed Data
Write-Host "`nStep 1: Initializing Seed Data..." -ForegroundColor Yellow
dbt seed
if ($LASTEXITCODE -ne 0) { throw "dbt seed failed. Test execution terminated." }

# 2. Normal Model Tests (Excludes the test_should_fail model folder)
Write-Host "`nStep 2: Running normal models and validations..." -ForegroundColor Yellow
dbt run --exclude models/test_should_fail
if ($LASTEXITCODE -ne 0) { throw "Normal models failed to run. Test execution terminated." }

dbt test --exclude models/test_should_fail
if ($LASTEXITCODE -ne 0) { throw "Data tests failed. Test execution terminated." }

# 3. test_should_fail Tests (Targets only the models/test_should_fail folder)
Write-Host "`nStep 3: Running test_should_fail tests (Validating data type enforcement)..." -ForegroundColor Yellow

# Create the bad view (Expected to succeed because it only deploys the view metadata)
dbt run --select models/test_should_fail
if ($LASTEXITCODE -ne 0) { throw "Failed to deploy test_should_fail test views. Test execution terminated." }

# Force a query against the view to trigger the database's internal CAST error
Write-Host "Querying the invalid view to force database type validation..." -ForegroundColor Gray

$ErrorActionPreference = "SilentlyContinue"
dbt show --select models/test_should_fail --limit 1
$DbtStatus = $LASTEXITCODE
$ErrorActionPreference = "Continue"

# Assertion: dbt show MUST fail (Exit code should NOT be 0) for the test to pass
if ($DbtStatus -eq 0) {
    Write-Host "`n[ERROR] test_should_fail test failed! The view was successfully queried without errors, meaning data type enforcement failed to trigger." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n[SUCCESS] test_should_fail test passed! Querying the bad view successfully triggered the expected database casting error." -ForegroundColor Green
}

Write-Host "`n=============================================" -ForegroundColor Green
Write-Host " Success! All integration tests passed! " -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green