# Demarre Redis (Docker), charge les donnees de demo (dates de depart fraiches) et affiche la suite.
# Usage :  .\load-demo.ps1
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "1/3 Redis (Docker)..." -ForegroundColor Cyan
docker compose up -d
if ($LASTEXITCODE -ne 0) { throw "docker compose a echoue : Docker Desktop est-il lance ? Un autre conteneur nomme blasa-redis existe-t-il deja (docker rm -f blasa-redis) ?" }
for ($i = 0; $i -lt 20; $i++) {
    if ((docker exec blasa-redis redis-cli ping) -eq "PONG") { break }
    Start-Sleep 1
}

Write-Host "2/3 Generation des donnees (departs dans 20 a 50 heures)..." -ForegroundColor Cyan
$t = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + 20 * 3600
$t = $t - ($t % 3600)
$offsets = @(0, 1, 3, 26, 30, 2, 4, 28)
$c = [IO.File]::ReadAllText("$PSScriptRoot\redis\01_seed.template.redis")
for ($i = 1; $i -le $offsets.Count; $i++) {
    $c = $c.Replace("{{DEP$i}}", [string]($t + $offsets[$i - 1] * 3600))
}
[IO.File]::WriteAllText("$PSScriptRoot\redis\01_seed.redis", $c, (New-Object Text.UTF8Encoding($false)))

Write-Host "3/3 Chargement dans Redis..." -ForegroundColor Cyan
cmd /c "docker exec -i blasa-redis redis-cli < redis\01_seed.redis" | Out-Null
Write-Host ("Termine : " + (docker exec blasa-redis redis-cli dbsize) + " cles.") -ForegroundColor Green
Write-Host ""
Write-Host "Ouvrir redis-cli :        docker exec -it blasa-redis redis-cli"
Write-Host "Rejouer les requetes :    cmd /c ""docker exec -i blasa-redis redis-cli < redis\02_queries.redis"""
