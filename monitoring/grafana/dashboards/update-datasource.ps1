# Add dynamic datasource to Grafana dashboards
$dashboards = @(
    "system-overview.json",
    "bmi-application-metrics.json"
)

$inputsSection = @"
  "__inputs": [
    {
      "name": "DS_PROMETHEUS",
      "label": "Prometheus",
      "description": "",
      "type": "datasource",
      "pluginId": "prometheus",
      "pluginName": "Prometheus"
    }
  ],
  "__requires": [
    {
      "type": "grafana",
      "id": "grafana",
      "name": "Grafana",
      "version": "8.0.0"
    },
    {
      "type": "datasource",
      "id": "prometheus",
      "name": "Prometheus",
      "version": "1.0.0"
    }
  ],
"@

foreach ($dashboard in $dashboards) {
    Write-Host "Processing $dashboard..."
    
    $content = [System.IO.File]::ReadAllText($dashboard, [System.Text.Encoding]::UTF8)
    
    # Add __inputs and __requires if not already present
    if (-not $content.Contains('"__inputs"')) {
        $content = $content -replace '^{', "{`n$inputsSection"
    }
    
    # Replace hardcoded datasource with template variable
    $content = $content -replace '("datasource":\s*)"Prometheus"', '$1"$${DS_PROMETHEUS}"'
    
    # Write back
    [System.IO.File]::WriteAllText($dashboard, $content, [System.Text.Encoding]::UTF8)
    
    Write-Host "  Done!"
}

Write-Host "`nAll dashboards updated with dynamic datasource support."
Write-Host "When importing to Grafana, you'll be prompted to select your Prometheus datasource."
