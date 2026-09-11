<#
Starts a local LiteLLM proxy that translates Claude Code's Anthropic-format
requests into NVIDIA NIM's OpenAI-compatible free API, then launches Claude
Code pointed at it.

Use ONLY when you've hit your normal Claude usage limit and want to keep
working on low-stakes, mechanical tasks. This is NOT Claude - it is a free
third-party model (Nemotron / Llama / Qwen / DeepSeek via NVIDIA NIM)
wearing Claude Code's UI. Tool-use behavior, judgment quality, and
reliability are all lower. Do not use it for ULC compliance/client-facing
work, trading decisions, or anything where being wrong is costly. Run
mechanical/scratch work only, in a fresh terminal, and switch back to a
normal `claude` session once your limit resets.
#>
param(
    [string]$Model = "nim-nemotron-lightning-30b",
    [int]$Port = 4000
)

$root = $PSScriptRoot
& (Join-Path $root "_EnsureProxy.ps1") -Model $Model -Port $Port
if ($LASTEXITCODE -ne 0) { exit 1 }

# --- point Claude Code at the local proxy instead of Anthropic ---
$env:ANTHROPIC_BASE_URL = "http://127.0.0.1:$Port"
$env:ANTHROPIC_AUTH_TOKEN = $env:LITELLM_MASTER_KEY
Remove-Item Env:\ANTHROPIC_API_KEY -ErrorAction SilentlyContinue

Write-Host ""
if ($Model -like 'nim-uncensored-*') {
    Write-Host "=============================================================" -ForegroundColor Red
    Write-Host " RUNNING ON AN ABLITERATED MODEL ($Model)" -ForegroundColor Red
    Write-Host " THIS IS NOT CLAUDE. Safety behaviour has been surgically" -ForegroundColor Red
    Write-Host " removed from these weights - it will not refuse, and it" -ForegroundColor Red
    Write-Host " will not push back on a bad idea." -ForegroundColor Red
    Write-Host ""
    Write-Host " Tool use IS supported (Gemma 4 has native function calling," -ForegroundColor Red
    Write-Host " and abliteration does not degrade it) - but it depends on" -ForegroundColor Red
    Write-Host " llama-server running with --jinja. If tool calls come back" -ForegroundColor Red
    Write-Host " malformed, check that flag before blaming the model." -ForegroundColor Red
    if ($Model -eq 'nim-uncensored-hosted') {
        Write-Host ""
        Write-Host " BACKEND IS A THIRD PARTY (abliteration.ai). No DPA." -ForegroundColor Red
        Write-Host " No client data, no personal info, nothing POPIA-covered." -ForegroundColor Red
    }
    Write-Host "=============================================================" -ForegroundColor Red
} else {
    Write-Host "=============================================================" -ForegroundColor Yellow
    Write-Host " RUNNING ON NVIDIA NIM FALLBACK ($Model) - THIS IS NOT CLAUDE" -ForegroundColor Yellow
    Write-Host " Mechanical/scratch work only. No ULC client work, no trading" -ForegroundColor Yellow
    Write-Host " decisions, no compliance judgment calls on this session." -ForegroundColor Yellow
    Write-Host "=============================================================" -ForegroundColor Yellow
}
Write-Host ""

claude --model $Model
