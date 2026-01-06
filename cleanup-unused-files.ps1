# Cleanup Unused Files
# This script identifies and optionally deletes files not required by the main deployment scripts

$rootPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Files to DELETE (documentation/guides not used by scripts)
$filesToDelete = @(
    "monitoring\Basic_Monitoring_Setup.md"
    "monitoring\IMPLEMENTATION_GUIDE.md"
    "monitoring\INDEX.md"
    "monitoring\MANUAL_SETUP_GUIDE.md"
    "monitoring\Monitoring_README.md"
    "monitoring\MONITORING_SUMMARY.md"
    "monitoring\NETWORK_CONFIGURATION.md"
    "monitoring\QUICK_START.md"
    "monitoring\README.md"
    "monitoring\3-tier-app\README.md"
    "AGENT.md"
    "remove-emojis.ps1"
)

# Backup dashboard files (duplicates - root copies exist)
$duplicateDashboards = @(
    "monitoring\grafana\dashboards\bmi-application-metrics.json.bak"
    "monitoring\grafana\dashboards\system-overview.json.bak"
    "monitoring\grafana\dashboards\update-datasource.ps1"
)

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "Unused File Cleanup Utility" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Files that will be DELETED:" -ForegroundColor Yellow
Write-Host ""

$totalSize = 0
$fileList = @()

foreach ($file in ($filesToDelete + $duplicateDashboards)) {
    $fullPath = Join-Path $rootPath $file
    if (Test-Path $fullPath) {
        $item = Get-Item $fullPath
        $size = $item.Length
        $totalSize += $size
        $fileList += $fullPath
        Write-Host "  [X] $file ($([math]::Round($size/1KB, 2)) KB)" -ForegroundColor Red
    } else {
        Write-Host "  [ ] $file (not found)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Total files: $($fileList.Count)" -ForegroundColor Yellow
Write-Host "Total size: $([math]::Round($totalSize/1KB, 2)) KB" -ForegroundColor Yellow
Write-Host ""
Write-Host "These files are documentation/guides not referenced by:" -ForegroundColor White
Write-Host "  - IMPLEMENTATION_AUTO.sh" -ForegroundColor Green
Write-Host "  - monitoring/MONITORING_SERVER_SETUP.sh" -ForegroundColor Green
Write-Host "  - monitoring/Basic_Monitoring_Setup.sh" -ForegroundColor Green
Write-Host "  - monitoring/scripts/setup-application-exporters.sh" -ForegroundColor Green
Write-Host "  - monitoring/scripts/setup-monitoring-server.sh" -ForegroundColor Green
Write-Host "  - monitoring/3-tier-app/scripts/*.sh" -ForegroundColor Green
Write-Host ""

$response = Read-Host "Do you want to DELETE these files? (yes/no)"

if ($response -eq "yes") {
    Write-Host ""
    Write-Host "Deleting files..." -ForegroundColor Yellow
    
    foreach ($file in $fileList) {
        try {
            Remove-Item $file -Force
            Write-Host "  Deleted: $file" -ForegroundColor Green
        } catch {
            Write-Host "  Failed to delete: $file - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Cleanup completed!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Operation cancelled. No files were deleted." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "KEPT Files (Required by deployment scripts):" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Main Scripts:" -ForegroundColor White
Write-Host "  - IMPLEMENTATION_AUTO.sh" -ForegroundColor Cyan
Write-Host "  - monitoring/MONITORING_SERVER_SETUP.sh" -ForegroundColor Cyan
Write-Host "  - monitoring/Basic_Monitoring_Setup.sh" -ForegroundColor Cyan
Write-Host "  - monitoring/scripts/*.sh" -ForegroundColor Cyan
Write-Host "  - monitoring/3-tier-app/scripts/*.sh" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration Files:" -ForegroundColor White
Write-Host "  - monitoring/prometheus/*.yml" -ForegroundColor Cyan
Write-Host "  - monitoring/promtail/*.yml" -ForegroundColor Cyan
Write-Host "  - monitoring/loki/*.yml" -ForegroundColor Cyan
Write-Host "  - monitoring/alertmanager/*.yml" -ForegroundColor Cyan
Write-Host "  - monitoring/exporters/bmi-app-exporter/*" -ForegroundColor Cyan
Write-Host ""
Write-Host "Dashboards:" -ForegroundColor White
Write-Host "  - monitoring/3-tier-app/dashboards/*.json" -ForegroundColor Cyan
Write-Host "  - monitoring/grafana/dashboards/*.json" -ForegroundColor Cyan
Write-Host "  - *.json (root level)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Application Code:" -ForegroundColor White
Write-Host "  - backend/**" -ForegroundColor Cyan
Write-Host "  - frontend/**" -ForegroundColor Cyan
Write-Host "  - database/**" -ForegroundColor Cyan
Write-Host ""
