<#
Non-interactive smoke test: starts the proxy if needed, sends one real
request through it in Anthropic Messages format, and prints the reply.
Run this after setting up .env, before trusting Start-ClaudeNim.ps1.
#>
param([string]$Model = "nim-nemotron-ultra-550b")

$root = $PSScriptRoot
& (Join-Path $root "_EnsureProxy.ps1") -Model $Model
if ($LASTEXITCODE -ne 0) { exit 1 }

$body = @{
    model      = $Model
    max_tokens = 300
    messages   = @(@{ role = "user"; content = "Reply with exactly: NIM proxy OK" })
} | ConvertTo-Json -Depth 5

$headers = @{
    "x-api-key"         = $env:LITELLM_MASTER_KEY
    "anthropic-version" = "2023-06-01"
    "content-type"      = "application/json"
}

try {
    $resp = Invoke-RestMethod -Uri "http://127.0.0.1:4000/v1/messages" -Method Post -Headers $headers -Body $body -TimeoutSec 90
    Write-Host "Response text:" -ForegroundColor Green
    $resp.content | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text }
    Write-Host ""
    Write-Host "SMOKE TEST PASSED - proxy correctly bridges Anthropic format to NVIDIA NIM." -ForegroundColor Green
} catch {
    Write-Host "SMOKE TEST FAILED:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message }
    exit 1
}
