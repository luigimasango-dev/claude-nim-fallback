$pidFile = Join-Path $PSScriptRoot "logs\proxy.pid"
if (-not (Test-Path $pidFile)) {
    Write-Host "No proxy.pid file found - proxy likely not running (or was started outside this script)."
    exit 0
}
$targetPid = Get-Content $pidFile
try {
    Stop-Process -Id $targetPid -Force -ErrorAction Stop
    Write-Host "Stopped LiteLLM proxy (pid $targetPid)."
} catch {
    Write-Host "Process $targetPid not found (already stopped)."
}
Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
