# Bookstore API — Django + Docker + PostgreSQL

Este projeto executa uma API Django “bookstore” **dockerizada**, com **PostgreSQL** e gerenciamento de dependências via **Poetry**.  
Este README está pronto para substituir o existente no repositório.

---

## Requisitos

- **Docker Desktop** (com Docker Compose v2)  
- **Windows PowerShell 5.1** (para os comandos/scritps abaixo). Em macOS/Linux use o terminal equivalente.

> Importante: A aplicação usa **Python 3.10** dentro do container, compatível com **Django 3.2**.

---

## Subir rapidamente (ambiente de desenvolvimento)

No PowerShell, dentro da pasta do projeto:

```powershell
docker compose down -v
docker compose up -d --build
```

Verifique os serviços:

```powershell
docker compose ps
```

- **web**: Django dev server em `0.0.0.0:8000`
- **db**: PostgreSQL 13 (com *healthcheck*) em `5432`

Parar/limpar quando terminar:

```powershell
docker compose down -v
```

---

## Endpoints úteis (dev)

> A raiz `/` não possui rota. Use os caminhos abaixo.

- `http://localhost:8000/hello/` – página simples (teste rápido)
- `http://localhost:8000/admin/` – admin do Django (tela de login)
- `http://localhost:8000/bookstore/v1/product/` – API de produtos (DRF)
- `http://localhost:8000/bookstore/v1/category/` – API de categorias (DRF)
- `http://localhost:8000/bookstore/v1/order/` – API de pedidos (DRF)
- `http://localhost:8000/api-token-auth/` – obtenção de *token* (POST `username`/`password`)

---

## Criar usuário admin (opcional)

```powershell
docker compose exec web python -c "import os; os.environ.setdefault('DJANGO_SETTINGS_MODULE','bookstore.settings'); import django; django.setup(); from django.contrib.auth.models import User; u, c = User.objects.get_or_create(username='admin'); u.is_staff=True; u.is_superuser=True; u.set_password('admin123'); u.save(); print('admin:admin123 pronto')"
```

---

## Variáveis de ambiente

A aplicação lê as seguintes variáveis (definidas no `docker-compose.yml`):

- `SQL_DATABASE`
- `SQL_USER`
- `SQL_PASSWORD`
- `SQL_HOST` (padrão: `db`)
- `SQL_PORT` (padrão: `5432`)
- `DJANGO_ALLOWED_HOSTS` (opcional; em dev pode usar `*`)

---

## Dockerfile (resumo)

- Base: `python:3.10-slim`
- Dependências: `build-essential` e `libpq-dev` (para psycopg2)
- Poetry no build com `poetry lock` **antes** do `poetry install`
- *Entrypoint* (dev): `python manage.py runserver 0.0.0.0:8000`

Trecho relevante:

```dockerfile
FROM python:3.10-slim

RUN apt-get update && apt-get install -y --no-install-recommends build-essential libpq-dev && rm -rf /var/lib/apt/lists/*

WORKDIR /code
COPY . /code/

RUN pip install --no-cache-dir poetry  && poetry config virtualenvs.create false  && poetry lock --no-interaction --no-ansi  && poetry install --no-interaction --no-ansi

EXPOSE 8000
CMD ["python","manage.py","runserver","0.0.0.0:8000"]
```

---

## Verificações rápidas

```powershell
# Porta aberta
Test-NetConnection -ComputerName localhost -Port 8000

# Resposta HTTP (hello)
Invoke-WebRequest http://localhost:8000/hello/ -UseBasicParsing

# Logs
docker compose logs --tail 100 web
docker compose logs --tail 60 db
```

---

## Script E2E (PowerShell 5.1) — opcional

O script abaixo executa uma checagem ponta-a-ponta: Docker/Compose, arquivos, dependências, build+up,
*healthcheck* do Postgres, HTTP, ENGINE/HOST do Django e conexão real via `psycopg2`.  
**Cole no PowerShell 5.1** (na raiz do projeto).

```powershell
$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue'
$ProjectPath = (Get-Location).Path
$RequiredFiles = @('Dockerfile','docker-compose.yml','bookstore\settings.py','pyproject.toml')
$WebService='web'; $DbService='db'; $HttpUrl='http://localhost:8000/hello/'
$MaxWaitDbHealthySec=120; $MaxWaitWebPortSec=120
$Results = New-Object System.Collections.ArrayList
function Add-Result([string]$Check,[bool]$Ok,[string]$Details){$s='FAIL';if($Ok){$s='PASS'};$null=$Results.Add([pscustomobject]@{Check=$Check;Status=$s;Details=$Details})}
function CmdExists([string]$c){[bool](Get-Command $c -ErrorAction SilentlyContinue)}
$ComposeMode=$null; if(CmdExists 'docker'){try{& docker compose version 1>$null 2>$null; if($LASTEXITCODE -eq 0){$ComposeMode='docker'}}catch{}}
if(-not $ComposeMode -and (CmdExists 'docker-compose')){$ComposeMode='dc'}
function Invoke-Compose([string[]]$a){ if($ComposeMode -eq 'docker'){& docker @('compose') + $a}elseif($ComposeMode -eq 'dc'){& docker-compose $a}else{throw "Docker Compose não encontrado."}}
function Compose-PS([string]$s){ if($ComposeMode -eq 'docker'){(& docker compose ps -q $s | Select-Object -First 1)}else{(& docker-compose ps -q $s | Select-Object -First 1)}}
$dockerOk=CmdExists 'docker'; $dockerDetail="docker não encontrado"; if($dockerOk){$dockerDetail=(& docker --version)}; Add-Result "Docker instalado" $dockerOk $dockerDetail
$composeOk=($null -ne $ComposeMode); $composeDetail="nem 'docker compose' nem 'docker-compose'"; if($composeOk){$composeDetail="modo: $ComposeMode"}; Add-Result "Docker Compose disponível" $composeOk $composeDetail
foreach($f in $RequiredFiles){$e=Test-Path $f; Add-Result "Arquivo: $f" $e ($(if($e){'ok'}else{'ausente'}))}
$PsyOk=$false; $DrfOk=$false; if(Test-Path 'pyproject.toml'){ $py=Get-Content -Raw 'pyproject.toml'; if($py -match 'psycopg2(-binary)?'){$PsyOk=$true}; if(($py -match '(^|\s)djangorestframework') -and -not ($py -match 'django-rest-framework')){$DrfOk=$true}}
Add-Result "pyproject: psycopg2 presente" $PsyOk ($(if($PsyOk){'ok'}else{'ausente: use psycopg2-binary'}))
Add-Result "pyproject: nome correto do DRF" $DrfOk ($(if($DrfOk){'djangorestframework ok'}else{'nome incorreto (ex.: django-rest-framework)'}))
$UpOk=$false; if($composeOk){try{Invoke-Compose @('down','-v') 2>$null|Out-Null}catch{}; try{Invoke-Compose @('up','-d','--build')|Out-Null; if($LASTEXITCODE -eq 0){$UpOk=$true}}catch{$UpOk=$false}}
Add-Result "docker compose up --build" $UpOk ($(if($UpOk){'ok'}else{'verifique Docker Desktop rodando'}))
$WebId=$null;$DbId=$null; try{$WebId=Compose-PS $WebService}catch{}; try{$DbId=Compose-PS $DbService}catch{}
Add-Result "Container db em execução" ([bool]$DbId) ($(if($DbId){"id: $DbId"}else{'não encontrado'}))
Add-Result "Container web em execução" ([bool]$WebId) ($(if($WebId){"id: $WebId"}else{'não encontrado'}))
if(-not $UpOk -and $WebId -and $DbId){foreach($r in $Results){if($r.Check -eq 'docker compose up --build'){$r.Status='PASS';$r.Details='ok (containers em execução)';break}}}
$DbHealthy=$false; if($DbId){$t0=Get-Date; while((New-TimeSpan -Start $t0 -End (Get-Date)).TotalSeconds -lt $MaxWaitDbHealthySec){$st=(& docker inspect -f "{{.State.Health.Status}}" $DbId 2>$null); if($st -eq 'healthy'){$DbHealthy=$true;break}; Start-Sleep 3}}
Add-Result "PostgreSQL healthy" $DbHealthy ($(if($DbHealthy){'ok'}else{"timeout ($MaxWaitDbHealthySec s)"}))
$WebPortOk=$false; if($WebId){$el=0; while($el -lt $MaxWaitWebPortSec){$tnc=Test-NetConnection -ComputerName 'localhost' -Port 8000 -WarningAction SilentlyContinue; if($tnc -and $tnc.TcpTestSucceeded){$WebPortOk=$true;break}; Start-Sleep 3; $el+=3}}
Add-Result "Porta 8000 acessível (localhost:8000)" $WebPortOk ($(if($WebPortOk){'ok'}else{"timeout ($MaxWaitWebPortSec s)"}))
$HttpOk=$false; $HttpStatus=''; if($WebPortOk){try{$resp=Invoke-WebRequest -Uri $HttpUrl -UseBasicParsing; if($resp){$HttpStatus="HTTP $($resp.StatusCode)"; $HttpOk=$true}}catch{$HttpOk=$false; $HttpStatus="erro GET: " + $_.Exception.Message}}
Add-Result "HTTP resposta da app" $HttpOk $HttpStatus
$DjangoEngineOk=$false;$DjangoHostOk=$false;$DbConnectOk=$false;$DbEngine='';$DbHostValue=''
if($WebId){ try{$pyOne="import os; os.environ.setdefault('DJANGO_SETTINGS_MODULE','bookstore.settings'); import django; django.setup(); from django.conf import settings; d=settings.DATABASES['default']; print(d.get('ENGINE','')); print(d.get('HOST',''))"; $out=& docker exec $WebId python -c $pyOne 2>$null; if($out){$lines=($out -split "`n" | % { $_.Trim() }) | ? { $_ -ne '' }; if($lines.Count -ge 2){$DbEngine=$lines[0];$DbHostValue=$lines[1]; if($DbEngine -eq 'django.db.backends.postgresql'){$DjangoEngineOk=$true}; if($DbHostValue -eq 'db'){$DjangoHostOk=$true}}}}catch{}
 try{$connectCmd=@"
import os, sys
try:
    import psycopg2
    d = dict(
        dbname=os.environ.get('SQL_DATABASE',''),
        user=os.environ.get('SQL_USER',''),
        password=os.environ.get('SQL_PASSWORD',''),
        host=os.environ.get('SQL_HOST',''),
        port=os.environ.get('SQL_PORT','5432'),
    )
    conn = psycopg2.connect(**d)
    cur = conn.cursor(); cur.execute('SELECT 1'); cur.fetchone()
    print('OK'); conn.close(); sys.exit(0)
except Exception as e:
    print('ERR:'+str(e)); sys.exit(1)
"@; $out2=& docker exec -i $WebId python -c $connectCmd 2>$null; if($LASTEXITCODE -eq 0 -and $out2 -match 'OK'){$DbConnectOk=$true}}catch{} }
Add-Result "Django ENGINE=postgresql" $DjangoEngineOk ("ENGINE: " + ($DbEngine|Out-String).Trim())
Add-Result "Django HOST aponta para 'db'" $DjangoHostOk ("HOST: " + ($DbHostValue|Out-String).Trim())
Add-Result "Conexão real via psycopg2 (web -> db)" $DbConnectOk ($(if($DbConnectOk){'ok'}else{'falhou'}))
$WebLogs='';$DbLogs=''; try{$WebLogs=(& docker logs --tail 60 $WebId 2>$null) -join "`n"}catch{}; try{$DbLogs=(& docker logs --tail 40 $DbId 2>$null) -join "`n"}catch{}
Write-Host "`n====================== RESULTADOS DO TESTE ======================" -ForegroundColor Cyan
$Results | Select-Object Check,Status,Details | Format-Table -AutoSize
$pass=($Results|?{$_.Status -eq 'PASS'}).Count; $fail=($Results|?{$_.Status -eq 'FAIL'}).Count
Write-Host "-----------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ("TOTAL: {0}  |  PASS: {1}  |  FAIL: {2}" -f ($Results.Count), $pass, $fail) -ForegroundColor Yellow
```

---

Pronto! 🚀
