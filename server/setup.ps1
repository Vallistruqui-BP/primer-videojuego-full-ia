$ErrorActionPreference = 'Stop'
# Generate once, never print credentials or replace an existing configuration.
$secretDirectory = Join-Path $PSScriptRoot '.secrets'
if (Test-Path -LiteralPath (Join-Path $secretDirectory 'nakama.yml')) { throw 'Configuration already exists; preserve it.' }
New-Item -ItemType Directory -Path $secretDirectory -Force | Out-Null
function New-Secret { return [Convert]::ToHexString([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLowerInvariant() }
$dbSecret = New-Secret
$sessionSecret = New-Secret
$refreshSecret = New-Secret
$consoleSecret = New-Secret
$runtimeSecret = New-Secret
[IO.File]::WriteAllText((Join-Path $secretDirectory 'db_password'), $dbSecret)
$configuration = @"
name: office-preview
data_dir: /nakama/data
logger:
  level: WARN
database:
  address:
    - office:${dbSecret}@database:5432/nakama
socket:
  server_key: office-preview-client-v1
  max_message_size_bytes: 4096
session:
  encryption_key: ${sessionSecret}
  refresh_encryption_key: ${refreshSecret}
  token_expiry_sec: 7200
console:
  username: office_operator
  password: ${consoleSecret}
  signing_key: ${runtimeSecret}
runtime:
  http_key: ${runtimeSecret}
"@
[IO.File]::WriteAllText((Join-Path $secretDirectory 'nakama.yml'), $configuration)
Write-Output 'Independent server configuration created; secret values withheld.'
