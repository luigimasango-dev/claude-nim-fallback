<#
Internal helper: loads .env, starts the LiteLLM proxy if not already running,
waits for it to be healthy. Sets process env vars for the caller.
Not meant to be run directly.
#>
param(
    [string]$Model = "nim-nemotron-ultra-550b",
    [int]$Port = 4000
)

$root = $PSScriptRoot
$litellmExe = "C:\Users\Luigi Masango\AppData\Local\Packages\PythonSoftwareFoundation.Python.3.13_qbz5n2kfra8p0\LocalCache\local-packages\Python313\Scripts\litellm.exe"
$pidFile = Join-Path $root "logs\proxy.pid"
$outLog  = Join-Path $root "logs\proxy.log"
$errLog  = Join-Path $root "logs\proxy-err.log"

$envFile = Join-Path $root ".env"
if (-not (Test-Path $envFile)) {
    Write-Error "Missing .env - copy .env.example to .env and fill in NVIDIA_NIM_API_KEY first."
    exit 1
}
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
    $k, $v = $_.Split('=', 2)
    [System.Environment]::SetEnvironmentVariable($k.Trim(), $v.Trim(), 'Process')
}
if (-not $env:NVIDIA_NIM_API_KEY -or $env:NVIDIA_NIM_API_KEY -like '*xxxx*') {
    Write-Error "NVIDIA_NIM_API_KEY not set in .env. Get a free key at https://build.nvidia.com"
    exit 1
}

function Test-ProxyUp {
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health/liveliness" -TimeoutSec 5 -UseBasicParsing
        return $r.StatusCode -eq 200
    } catch { return $false }
}

if (-not (Test-ProxyUp)) {
    Write-Host "Starting LiteLLM proxy (NVIDIA NIM backend) on port $Port..."
    if (-not (Test-Path $litellmExe)) {
        Write-Error "litellm.exe not found at $litellmExe - reinstall with: pip install --user `"litellm[proxy]==1.94.1`""
        exit 1
    }

    # Force UTF-8 for the proxy process.
    #
    # LiteLLM prints an ASCII-art banner at startup containing characters the
    # Windows legacy console code page (cp1252) cannot encode. Output is
    # redirected to a file here, so Python selects cp1252, click.echo raises
    # UnicodeEncodeError inside the startup event, and the WHOLE PROXY DIES
    # before it ever binds the port. The visible symptom is the unhelpful
    # "Proxy did not come up in 45s" - nothing mentioning encoding, and nothing
    # to do with which model was requested.
    [System.Environment]::SetEnvironmentVariable('PYTHONIOENCODING', 'utf-8', 'Process')
    [System.Environment]::SetEnvironmentVariable('PYTHONUTF8', '1', 'Process')

    # Build a runtime config with the real API key substituted in.
    #
    # Entries using the native `nvidia_nim/` provider need a LITERAL api_key:
    # that provider does not resolve LiteLLM's `os.environ/NAME` indirection
    # (the generic `openai/` provider does), and fails with "Missing
    # credentials" even when the variable is set in the process. Rather than
    # commit a key, config.yaml carries NIM_KEY_PLACEHOLDER and we write a
    # resolved copy to logs\ for the proxy to read.
    $runtimeConfig = Join-Path $root "logs\config.runtime.yaml"
    (Get-Content (Join-Path $root "config.yaml") -Raw).
        Replace('NIM_KEY_PLACEHOLDER', $env:NVIDIA_NIM_API_KEY) |
        Set-Content -Path $runtimeConfig -Encoding utf8

    $proc = Start-Process -FilePath $litellmExe `
        -ArgumentList @("--config", $runtimeConfig, "--port", "$Port") `
        -WorkingDirectory $root `
        -WindowStyle Hidden `
        -RedirectStandardOutput $outLog `
        -RedirectStandardError $errLog `
        -PassThru
    $proc.Id | Out-File -FilePath $pidFile -Encoding ascii

    $ready = $false
    for ($i = 0; $i -lt 45; $i++) {
        Start-Sleep -Seconds 1
        if (Test-ProxyUp) { $ready = $true; break }
    }
    if (-not $ready) {
        Write-Error "Proxy did not come up in 45s. Check logs at $errLog"
        Get-Content $errLog -Tail 20 -ErrorAction SilentlyContinue
        exit 1
    }
    Write-Host "Proxy is up (pid $($proc.Id))."
} else {
    Write-Host "Proxy already running on port $Port."
}
exit 0
