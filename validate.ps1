# PowerShell 5.1
$ErrorActionPreference = 'Stop'

function Fail([string]$msg, [int]$code) {
  Write-Error $msg
  exit $code
}

Write-Host "1) Conferindo arquivos essenciais..."
$must = @('docker-compose.yml', 'Dockerfile', 'pyproject.toml')
foreach ($f in $must) { if (-not (Test-Path -Path $f)) { Fail "Arquivo ausente: $f" 10 } }
Write-Host "OK`n"

Write-Host "2) Subindo containers (build + up)..."
try { docker compose down -v --remove-orphans | Out-Null } catch {}
docker compose up -d --build | Out-Null
if ($LASTEXITCODE -ne 0) { Fail "Falha no 'docker compose up'." 20 }
Write-Host "OK`n"

Write-Host "3) Aguardando serviços: db=healthy e web=running..."
$deadline = (Get-Date).AddMinutes(4)
do {
  $dbId  = (docker compose ps -q db) 2>$null
  $webId = (docker compose ps -q web) 2>$null
  $dbId  = if ($dbId)  { $dbId.Trim() } else { "" }
  $webId = if ($webId) { $webId.Trim() } else { "" }

  $dbHealth = if ($dbId)  { docker inspect -f "{{.State.Health.Status}}" $dbId  2>$null } else { "" }
  $webState = if ($webId) { docker inspect -f "{{.State.Status}}"        $webId 2>$null } else { "" }

  $okDb  = ($dbHealth -eq "healthy")
  $okWeb = ($webState -eq "running")

  if (-not ($okDb -and $okWeb)) { Start-Sleep -Seconds 3 }
} until (($okDb -and $okWeb) -or (Get-Date) -gt $deadline)

if (-not ($okDb -and $okWeb)) {
  docker compose ps
  Fail "Serviços não ficaram prontos (db=$dbHealth, web=$webState)." 30
}
Write-Host "OK (db=$dbHealth, web=$webState)`n"

Write-Host "4) Validando rede 'bookstore_net'..."
$netOK = docker network ls --format '{{.Name}}' | Select-String -SimpleMatch 'bookstore_net'
if (-not $netOK) { Fail "Rede 'bookstore_net' não encontrada." 40 }
Write-Host "OK`n"

Write-Host "5) Testando conectividade web -> db:5432..."
# pequena espera extra para o Postgres aceitar conexões
Start-Sleep -Seconds 2
$connectOK = $false
try {
  $out = docker compose exec -T web python -c "import socket; s=socket.create_connection(('db',5432),5); print('OK'); s.close()" 2>&1
  if ($out -match 'OK') { $connectOK = $true }
} catch { $connectOK = $false }
if (-not $connectOK) { Fail "Conexão web->db (porta 5432) falhou." 50 }
Write-Host "OK`n"

Write-Host "6) Verificando HTTP do Django (/admin/login/)..."
$okHttp = $false
for ($i=0; $i -lt 45; $i++) {
  try {
    $resp = Invoke-WebRequest "http://localhost:8000/admin/login/" -UseBasicParsing -TimeoutSec 5
    if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 400) { $okHttp = $true; break }
  } catch { }
  Start-Sleep -Seconds 2
}
if (-not $okHttp) { Fail "HTTP /admin/login/ indisponível." 60 }
Write-Host "OK`n"

Write-Host "`n✅ Validação concluída com sucesso."
docker compose ps
