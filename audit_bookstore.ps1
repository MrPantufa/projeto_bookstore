param(
  [string]$ProjectPath = "C:\Users\Mateus\Desktop\projeto_bookstore-feat-paginacao-drf",
  [string]$BindHost    = "127.0.0.1",   # não usar $Host (reservado do PowerShell)
  [int]$Port           = 8000,
  [int]$SeedCount      = 12,
  [switch]$SomenteChecagens
)

# ============= Utilidades =============
$ErrorActionPreference = "Stop"
function Say($m,$c="Gray"){ Write-Host $m -ForegroundColor $c }
function Pass($m){ Write-Host "✔ $m" -ForegroundColor Green }
function Fail($m){ Write-Host "✖ $m" -ForegroundColor Red }
function Warn($m){ Write-Host "! $m" -ForegroundColor Yellow }

$Report = [ordered]@{
  meta = [ordered]@{
    when     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    pwsh     = $PSVersionTable.PSVersion.ToString()
    user     = $env:USERNAME
    computer = $env:COMPUTERNAME
  }
  checks = @()
  http   = @{}
}

function Add-Check($name,$ok,$info=""){
  $Report.checks += [ordered]@{name=$name;ok=[bool]$ok;info=$info}
  if($ok){ Pass $name } else { Fail $name; if($info){ Say "  -> $info" "DarkGray" } }
}
function ReadRaw($p){ if(Test-Path $p){ Get-Content $p -Raw } else { "" } }

function Run-Ok($args){
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "python"
  $psi.Arguments = $args
  $psi.RedirectStandardError = $true
  $psi.RedirectStandardOutput = $true
  $psi.UseShellExecute = $false
  $psi.WorkingDirectory = $ProjectPath
  $p = [System.Diagnostics.Process]::Start($psi)
  $p.WaitForExit()
  return @{
    ok   = ($p.ExitCode -eq 0)
    out  = $p.StandardOutput.ReadToEnd()
    err  = $p.StandardError.ReadToEnd()
    code = $p.ExitCode
  }
}

function Test-PortOpen([string]$host,[int]$port,[int]$timeoutMs=1000){
  try {
    $client = New-Object System.Net.Sockets.TcpClient
    $iar = $client.BeginConnect($host,$port,$null,$null)
    $ok = $iar.AsyncWaitHandle.WaitOne($timeoutMs,$false)
    if($ok){ $client.EndConnect($iar) }
    $client.Close()
    return $ok
  } catch { return $false }
}

function Test-ReqPin($text, $name, $version){
  $pattern = "(?m)^\s*{0}\s*==\s*{1}(\s*;.*)?\s*$" -f ([regex]::Escape($name)), ([regex]::Escape($version))
  return ($text -match $pattern)
}

# ============= Início =============
if(-not (Test-Path $ProjectPath)){ throw "Pasta do projeto não encontrada: $ProjectPath" }
Set-Location $ProjectPath
Say "📁 Projeto: $ProjectPath" "Cyan"

# 1) Arquivos essenciais
Add-Check "manage.py existe" (Test-Path ".\manage.py")
Add-Check "bookstore/settings.py existe" (Test-Path ".\bookstore\settings.py")
Add-Check "bookstore/urls.py existe" (Test-Path ".\bookstore\urls.py")
Add-Check "product/urls.py existe" (Test-Path ".\product\urls.py")
Add-Check "product tem migrations" (Test-Path ".\product\migrations\0001_initial.py")
if(Test-Path ".\order"){ Add-Check "order tem migrations (se app existir)" (Test-Path ".\order\migrations\0001_initial.py") }

# 2) requirements.txt — checagens
$reqOk=$true
if(Test-Path ".\requirements.txt"){
  $req = ReadRaw ".\requirements.txt"
  $r = @{
    django = Test-ReqPin $req 'django' '5.2.5'
    drf    = Test-ReqPin $req 'djangorestframework' '3.16.1'
    ddt    = ($req -match '(?m)^\s*django-debug-toolbar\s*==\s*4\.\d+\s*(;.*)?$' -or
              $req -match '(?m)^\s*django-debug-toolbar\s*>=\s*4\.4.*<\s*5\.0')
    asgi   = Test-ReqPin $req 'asgiref' '3.9.1'
    tzwin  = ($req -match '(?m)^\s*tzdata\s*==\s*\d{4}\.\d(\s*;.*)?$')
  }
  foreach($k in $r.Keys){ if(-not $r[$k]){ $reqOk=$false } }
  Add-Check "requirements.txt com pins principais" $reqOk @(
    if(-not $r.django){"- Falta: django==5.2.5"}
    if(-not $r.drf){"- Falta: djangorestframework==3.16.1"}
    if(-not $r.ddt){"- Falta: django-debug-toolbar ~4.4.x"}
    if(-not $r.asgi){"- Falta: asgiref==3.9.1"}
    if(-not $r.tzwin){"- Falta: tzdata==YYYY.M (Windows)"}
  ) -join "`n"
}else{
  Add-Check "requirements.txt presente" $false "Crie/complete requirements.txt"
}

# 3) Poetry
$pyproj = Test-Path ".\pyproject.toml"
$lock   = Test-Path ".\poetry.lock"
Add-Check "pyproject.toml presente" $pyproj
if($pyproj){
  Add-Check "poetry.lock presente" $lock "Execute: poetry lock"
  $poetry = Get-Command poetry -ErrorAction SilentlyContinue
  if($poetry){
    $syncOK=$true
    try{ poetry lock --check | Out-Null }catch{ $syncOK=$false }
    Add-Check "poetry.lock sincronizado (poetry lock --check)" $syncOK "Rode 'poetry lock' até passar."
  } else {
    Warn "Poetry não encontrado no PATH; verificação --check pulada."
  }
}

# 4) Inspeção de settings/DRF/Toolbar via Python (robusto ao CWD)
$projEsc = $ProjectPath.Replace('\','\\')
$pyCode = @"
import os, sys, json
sys.path.insert(0, r"$projEsc")
os.chdir(r"$projEsc")
os.environ.setdefault("DJANGO_SETTINGS_MODULE","bookstore.settings")
import django
django.setup()
from django.conf import settings
from django.utils.module_loading import import_string

out = {}
inst = set(settings.INSTALLED_APPS)
out["has_rest_framework"] = "rest_framework" in inst
out["has_debug_toolbar"]  = "debug_toolbar" in inst
out["has_middleware_ddt"] = any("DebugToolbarMiddleware" in m for m in settings.MIDDLEWARE)
out["internal_ips_ok"]    = hasattr(settings,"INTERNAL_IPS") and ("127.0.0.1" in getattr(settings,"INTERNAL_IPS",[]))
ah = set(getattr(settings,"ALLOWED_HOSTS",[]))
out["allowed_hosts_ok"]   = bool(ah.intersection({"127.0.0.1","localhost","*"}))

rf = getattr(settings,"REST_FRAMEWORK",{})
out["has_rest_framework_dict"] = bool(rf)
cls_path = rf.get("DEFAULT_PAGINATION_CLASS")
out["default_pagination_class"] = cls_path
ok_pag = False
page_cfg = {}
if cls_path:
    cls = import_string(cls_path)
    p = cls()
    page_cfg = {
        "page_size": getattr(p,"page_size",None),
        "page_size_query_param": getattr(p,"page_size_query_param",None),
        "max_page_size": getattr(p,"max_page_size",None),
    }
    ok_pag = (page_cfg.get("page_size")==5 and page_cfg.get("page_size_query_param")=="page_size")
out["pagination_ok"] = ok_pag
out["pagination_cfg"] = page_cfg

try:
    from product.models import Product
    out["product_import_ok"] = True
except Exception as e:
    out["product_import_ok"] = False
    out["product_import_err"] = str(e)

print(json.dumps(out))
"@
$pyTmp = Join-Path $env:TEMP ("audit_django_{0}.py" -f ([guid]::NewGuid().ToString()))
Set-Content -Path $pyTmp -Value $pyCode -Encoding UTF8
$pyCheck = & python $pyTmp
Remove-Item $pyTmp -ErrorAction SilentlyContinue

$pyObj = $null
try{ $pyObj = $pyCheck | ConvertFrom-Json }catch{ $pyObj = $null }

if($pyObj){
  Add-Check "INSTALLED_APPS inclui rest_framework" ($pyObj.has_rest_framework)
  Add-Check "INSTALLED_APPS inclui debug_toolbar" ($pyObj.has_debug_toolbar)
  Add-Check "MIDDLEWARE inclui DebugToolbarMiddleware" ($pyObj.has_middleware_ddt)
  Add-Check "INTERNAL_IPS inclui 127.0.0.1" ($pyObj.internal_ips_ok)
  Add-Check "ALLOWED_HOSTS permite localhost/127.0.0.1" ($pyObj.allowed_hosts_ok)
  Add-Check "REST_FRAMEWORK definido" ($pyObj.has_rest_framework_dict)
  Add-Check "DEFAULT_PAGINATION_CLASS configurada" ([string]::IsNullOrWhiteSpace($pyObj.default_pagination_class) -eq $false)
  Add-Check "Paginação OK (page_size=5 e ?page_size habilitado)" ($pyObj.pagination_ok) ("Config atual: " + ($pyObj.pagination_cfg | ConvertTo-Json -Compress))
} else {
  Add-Check "Inspeção de settings via Python" $false $pyCheck
}

# 5) URLs – presença de product/order e prefixo versionado
$urls = ReadRaw ".\bookstore\urls.py"
$hasProduct = ($urls -match "include\(\s*[`"']product\.urls")
$hasOrder   = ($urls -match "include\(\s*[`"']order\.urls")
$hasVersion = ($urls -match "(?m)re_path\(\s*r[`"']\^?bookstore/\(\?P<version>\((?:v1\|v2)\)\)/")
Add-Check "bookstore/urls.py inclui product.urls" $hasProduct
Add-Check "bookstore/urls.py inclui order.urls" $hasOrder
Add-Check "Rotas versionadas ^bookstore/(?P<version>(v1|v2))/" $hasVersion

# 6) manage.py check + migrate
$rCheck = Run-Ok "manage.py check"
Add-Check "manage.py check OK" $rCheck.ok ($rCheck.err + "`n" + $rCheck.out)

$rMig = Run-Ok "manage.py migrate --no-input"
Add-Check "Migrations aplicadas" $rMig.ok ($rMig.err + "`n" + $rMig.out)

# 7) (Opcional) testes
$testPath = ".\product\tests\test_pagination\test_drf_pagination_and_toolbar.py"
if(Test-Path $testPath){
  try {
    $rTests = Run-Ok "manage.py test product.tests.test_pagination -v 2"
    Add-Check "Testes de paginação/toolbar OK" $rTests.ok ("Saída:`n" + $rTests.out)
  } catch {
    Add-Check "Falha ao rodar testes" $false $_.Exception.Message
  }
} else {
  Warn "Teste de paginação não encontrado em $testPath – pulado."
}

# 8) Seed + HTTP smoke (pula se -SomenteChecagens)
if (-not $SomenteChecagens) {
  $seedPy = @"
import os, sys
os.environ.setdefault("DJANGO_SETTINGS_MODULE","bookstore.settings")
import django
django.setup()
from product.models import Product
Product.objects.all().delete()
objs = [Product(title=f"Produto {i}") for i in range(1, $SeedCount+1)]
Product.objects.bulk_create(objs)
print(Product.objects.count())
"@
  $seedTmp = Join-Path $env:TEMP ("seed_{0}.py" -f ([guid]::NewGuid().ToString()))
  Set-Content $seedTmp -Value $seedPy -Encoding UTF8
  $seedOut = & python $seedTmp
  Remove-Item $seedTmp -ErrorAction SilentlyContinue
  Add-Check "Seed aplicado ($SeedCount produtos)" ($seedOut.Trim() -eq "$SeedCount") "Retorno: $seedOut"

  $serverArgs = @("manage.py","runserver","$BindHost`:$Port","--noreload")
  $serverProc = Start-Process -FileName "python" -ArgumentList $serverArgs -WorkingDirectory $ProjectPath -WindowStyle Hidden -PassThru

  $deadline = (Get-Date).AddSeconds(30)
  do {
    Start-Sleep 1
    $ready = Test-PortOpen -host $BindHost -port $Port -timeoutMs 800
  } until ($ready -or (Get-Date) -gt $deadline)

  # <<< FIX AQUI: sem conflito com ':' >>>
  Add-Check ("Servidor respondeu na porta {0}:{1}" -f $BindHost, $Port) $ready

  if ($ready) {
    $base = "http://$BindHost`:$Port/bookstore/v1/product/"
    try {
      $r1 = Invoke-RestMethod -Uri $base -Method Get
      $r2 = Invoke-RestMethod -Uri ($base + "?page=2") -Method Get
      $r3 = Invoke-RestMethod -Uri ($base + "?page_size=7") -Method Get
      Add-Check "Página 1 retorna 5 itens" ($r1.results.Count -eq 5)
      Add-Check "Página 2 retorna 5 itens" ($r2.results.Count -eq 5)
      Add-Check "page_size=7 retorna 7 itens" ($r3.results.Count -eq 7)
      $Report.http = @{
        base       = $base
        total      = $r1.count
        page1      = $r1.results.Count
        page2      = $r2.results.Count
        page_size7 = $r3.results.Count
        next       = $r1.next
      }
    } catch {
      Add-Check "Requisições HTTP aos endpoints" $false $_.Exception.Message
    }
  }

  if ($serverProc -and -not $serverProc.HasExited) {
    try { Stop-Process -Id $serverProc.Id -Force -ErrorAction SilentlyContinue } catch {}
  }
} else {
  Warn "SomenteChecagens ligado – seed/servidor/HTTP pulados."
}

# 9) Resumo final (e salva JSON)
Say "`nResumo:" "Cyan"
$reportPath = Join-Path $ProjectPath "audit_result.json"
$Report | ConvertTo-Json -Depth 6 | Tee-Object -Variable jsonOut | Set-Content -Path $reportPath -Encoding UTF8
Write-Host $jsonOut
Say "Relatório salvo em: $reportPath" "Cyan"
