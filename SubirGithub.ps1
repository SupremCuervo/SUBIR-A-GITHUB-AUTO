#Requires -Version 5.1
# SubirGithub — menú para subir a GitHub (nuevo remoto, actual o borrar .git)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

function Write-Step {
	param([string]$Message)
	Write-Host ""
	Write-Host "  >> $Message" -ForegroundColor Yellow
}

function Test-GitRepo {
	$null = git rev-parse --is-inside-work-tree 2>$null
	return ($LASTEXITCODE -eq 0)
}

function Test-LocalGitMetadata {
	return (Test-Path -LiteralPath (Join-Path $script:SubirGithubRoot '.git'))
}

function Test-GitAvailable {
	return $null -ne (Get-Command git -ErrorAction SilentlyContinue)
}

function Invoke-Git {
	param([string[]]$GitArguments)
	& git @GitArguments
	return ,$LASTEXITCODE
}

function Format-GitArgsDisplay {
	param([string[]]$GitArguments)
	$parts = foreach ($a in $GitArguments) {
		if ($a -match '[\s"]') {
			"`"$($a -replace '"', '\"')`""
		} else {
			$a
		}
	}
	return ($parts -join ' ')
}

function Invoke-GitVisible {
	param([string[]]$GitArguments)
	$line = Format-GitArgsDisplay $GitArguments
	Write-Host ""
	Write-Host "  === git $line ===" -ForegroundColor Cyan
	# Capturar salida aquí: si no, al hacer "$ec = Invoke-GitVisible" PowerShell mete el texto de git
	# en la variable y el código de salida se pierde (parece fallo aunque git devolvió 0).
	$gitOut = & git @GitArguments 2>&1
	$ec = $LASTEXITCODE
	foreach ($item in @($gitOut)) {
		if ($item -is [System.Management.Automation.ErrorRecord]) {
			Write-Host "  $($item.ToString())" -ForegroundColor Red
		} else {
			Write-Host "  $item"
		}
	}
	Write-Host "  === fin (código salida: $ec) ===" -ForegroundColor $(if ($ec -eq 0) { 'DarkGray' } else { 'Red' })
	$script:SubirGithubLastGitExit = $ec
	# No devolver $ec: si no se asigna la llamada, PowerShell imprimiría "0" en consola.
}

function Show-Menu {
	Write-Host ""
	Write-Host "  _______________________________________" -ForegroundColor DarkGray
	Write-Host ""
	Write-Host "  ========== SubirGithub ==========" -ForegroundColor Cyan
	Write-Host "  1) Subir a nuevo repositorio"
	Write-Host "  2) Subir a repositorio actual"
	Write-Host "  3) Eliminar repositorio actual (.git)"
	Write-Host "  4) Salir"
	Write-Host "  =================================" -ForegroundColor Cyan
	Write-Host ""
}

function New-RepoFlow {
	Enter-ProjectRoot
	if (-not (Assert-NotUserProfileRoot)) {
		return
	}
	Write-Host ""
	Write-Host "  Carpeta de trabajo: $(Get-Location)" -ForegroundColor DarkGray
	Write-Host "  --- Nuevo repositorio (como primer subida) ---" -ForegroundColor Green
	$commitMsg = Read-Host "  Mensaje del commit"
	if (-not [string]::IsNullOrWhiteSpace($commitMsg)) {
		$commitMsg = $commitMsg.Trim()
	}
	if ([string]::IsNullOrWhiteSpace($commitMsg)) {
		Write-Host "  El commit no puede estar vacío." -ForegroundColor Red
		Read-Host "  Pulsa Enter para volver"
		return
	}
	$remoteUrl = Read-Host "  Enlace del repositorio GitHub (HTTPS)"
	if ([string]::IsNullOrWhiteSpace($remoteUrl)) {
		Write-Host "  El enlace no puede estar vacío." -ForegroundColor Red
		Read-Host "  Pulsa Enter para volver"
		return
	}
	$remoteUrl = $remoteUrl.Trim()

	if (-not (Test-LocalGitMetadata)) {
		$projNorm = (Resolve-Path -LiteralPath $script:SubirGithubRoot).Path.TrimEnd('\')
		if (Test-GitRepo) {
			$foreignTop = (git rev-parse --show-toplevel 2>$null).TrimEnd('\')
			if ($foreignTop -and ($foreignTop -ine $projNorm)) {
				Write-Host ""
				Write-Host "  IMPORTANTE: Git tenía la raíz en otra carpeta (repositorio muy grande):" -ForegroundColor Yellow
				Write-Host "    $foreignTop" -ForegroundColor Yellow
				Write-Host "  Eso hacía que 'git status' mostrara miles de archivos y el commit fallara o fuera peligroso." -ForegroundColor Yellow
				Write-Host "  Se crea un repositorio NUEVO solo en tu carpeta del proyecto:" -ForegroundColor Green
				Write-Host "    $projNorm" -ForegroundColor Cyan
				Write-Host ""
			}
		}
		Write-Step "Inicializar repositorio (git init en esta carpeta)"
		Invoke-GitVisible @('init')
		$ec = $script:SubirGithubLastGitExit
		if ($ec -ne 0) {
			Write-Host "  Error en git init." -ForegroundColor Red
			Read-Host "  Pulsa Enter"
			return
		}
	}

	Write-Step "Quitar remoto 'origin' anterior (si existía)"
	Write-Host "  === git remote remove origin ===" -ForegroundColor Cyan
	$null = git remote remove origin 2>&1
	Write-Host "  === fin ===" -ForegroundColor DarkGray

	Write-Step "Añadir remoto GitHub"
	Invoke-GitVisible @('remote', 'add', 'origin', $remoteUrl)
	$ec = $script:SubirGithubLastGitExit
	if ($ec -ne 0) {
		Write-Host "  Error al añadir remote. ¿Ya existe 'origin'? Prueba opción 2 o elimina .git (3)." -ForegroundColor Red
		Read-Host "  Pulsa Enter"
		return
	}
	Write-Host "  Remoto guardado:" -ForegroundColor DarkGray
	& git remote -v

	Write-Step "Añadir archivos al área de preparación (git add .)"
	Invoke-GitVisible @('add', '.')
	$ec = $script:SubirGithubLastGitExit
	if ($ec -ne 0) {
		Write-Host "  Error en git add." -ForegroundColor Red
		Read-Host "  Pulsa Enter"
		return
	}
	Write-Host "  Estado del repo (rama y archivos listos para commit):" -ForegroundColor DarkGray
	& git status -sb
	Write-Host ""

	Write-Step "Crear commit"
	Invoke-GitVisible @('commit', '-m', $commitMsg)
	$ec = $script:SubirGithubLastGitExit
	if ($ec -ne 0) {
		Write-Host "  No hay cambios para commitear o hubo error (¿nada que añadir?)." -ForegroundColor Yellow
		Read-Host "  Pulsa Enter"
		return
	}
	Write-Host "  Último commit creado:" -ForegroundColor DarkGray
	& git log -1 --oneline
	Write-Host ""

	Write-Step "Renombrar rama local a main"
	Invoke-GitVisible @('branch', '-M', 'main')

	Write-Step "Subir a GitHub (push)"
	Invoke-GitVisible @('push', '-u', 'origin', 'main')
	$ec = $script:SubirGithubLastGitExit
	if ($ec -ne 0) {
		Write-Host "  Error en push. Revisa credenciales, rama remota y que el repo en GitHub esté vacío o permita push." -ForegroundColor Red
		Read-Host "  Pulsa Enter"
		return
	}

	$webUrl = $remoteUrl.Trim()
	if ($webUrl -match '^git@github\.com:(.+)\.git$') {
		$webUrl = 'https://github.com/' + $Matches[1]
	} elseif ($webUrl -match '^git@github\.com:(.+)$') {
		$webUrl = 'https://github.com/' + $Matches[1]
	} else {
		$webUrl = $webUrl -replace '\.git$', ''
	}
	Write-Host ""
	Write-Host "  -----------------------------------------" -ForegroundColor Green
	Write-Host "  Subida correcta (procedimiento terminado)." -ForegroundColor Green
	Write-Host "  Repositorio en GitHub: $webUrl" -ForegroundColor Green
	Write-Host "  Rama subida: main" -ForegroundColor Green
	Write-Host "  -----------------------------------------" -ForegroundColor Green
	Write-Host "  Si GitHub mostraba 'empty', recarga la página del repo para ver los archivos." -ForegroundColor DarkGray
	Write-Host ""
	Read-Host "  Pulsa Enter para volver al menú"
}

function Existing-RepoFlow {
	Enter-ProjectRoot
	if (-not (Assert-NotUserProfileRoot)) {
		return
	}
	if (-not (Test-LocalGitMetadata)) {
		if (Test-GitRepo) {
			Write-Host "  No hay archivo .git en esta carpeta; solo estás dentro de un repositorio en una carpeta superior." -ForegroundColor Red
			Write-Host "  Usa la opción 1 para crear un repo solo en esta carpeta del proyecto." -ForegroundColor Yellow
		} else {
			Write-Host "  No hay repositorio Git aquí. Usa la opción 1." -ForegroundColor Red
		}
		Read-Host "  Pulsa Enter"
		return
	}

	Write-Host ""
	Write-Host "  --- Repositorio actual ---" -ForegroundColor Green
	Write-Host "  === git remote -v ===" -ForegroundColor Cyan
	& git remote -v
	Write-Host "  === fin ===" -ForegroundColor DarkGray
	Write-Host ""

	Write-Host "  === git branch -a ===" -ForegroundColor Cyan
	& git branch -a
	Write-Host "  === fin ===" -ForegroundColor DarkGray
	Write-Host ""

	$currentBranch = ''
	try {
		$currentBranch = (git rev-parse --abbrev-ref HEAD 2>$null).Trim()
	} catch { }
	if ([string]::IsNullOrWhiteSpace($currentBranch)) {
		$currentBranch = 'main'
	}
	if ($currentBranch -eq 'HEAD') {
		Write-Host "  Aviso: HEAD detached (sin rama con nombre). Elige una rama de la lista o créala antes de subir." -ForegroundColor Yellow
	}
	Write-Host "  Rama actual detectada: $currentBranch" -ForegroundColor DarkGray
	$branch = Read-Host "  Escribe el nombre de la rama a subir (Enter = $currentBranch)"
	if ([string]::IsNullOrWhiteSpace($branch)) {
		$branch = $currentBranch
	}
	$branch = $branch.Trim()

	$commitMsg = Read-Host "  Mensaje del commit"
	if (-not [string]::IsNullOrWhiteSpace($commitMsg)) {
		$commitMsg = $commitMsg.Trim()
	}
	if ([string]::IsNullOrWhiteSpace($commitMsg)) {
		Write-Host "  El commit no puede estar vacío." -ForegroundColor Red
		Read-Host "  Pulsa Enter"
		return
	}

	Write-Step "Añadir cambios (git add .)"
	Invoke-GitVisible @('add', '.')
	$ec = $script:SubirGithubLastGitExit
	if ($ec -ne 0) {
		Write-Host "  Error en git add." -ForegroundColor Red
		Read-Host "  Pulsa Enter"
		return
	}
	Write-Host "  Estado:" -ForegroundColor DarkGray
	& git status -sb
	Write-Host ""

	Write-Step "Crear commit"
	Invoke-GitVisible @('commit', '-m', $commitMsg)
	$ec = $script:SubirGithubLastGitExit
	if ($ec -ne 0) {
		Write-Host "  Sin cambios nuevos o error en commit. Si no hay nada que commitear, puedes hacer solo push (ejecuta manualmente: git push origin $branch)." -ForegroundColor Yellow
		$doPush = Read-Host "  ¿Intentar push igual? (s/N)"
		if ($null -ne $doPush) {
			$doPush = $doPush.Trim()
		}
		if ($doPush -notmatch '^[sSyY]') {
			Read-Host "  Pulsa Enter"
			return
		}
	} else {
		Write-Host "  Último commit:" -ForegroundColor DarkGray
		& git log -1 --oneline
		Write-Host ""
	}

	Write-Step "Subir rama a GitHub (push)"
	Invoke-GitVisible @('push', 'origin', $branch)
	$ec = $script:SubirGithubLastGitExit
	if ($ec -ne 0) {
		Write-Host "  Error en push." -ForegroundColor Red
		Read-Host "  Pulsa Enter"
		return
	}

	$originUrl = git remote get-url origin 2>$null
	$webUrl = if ($originUrl) { $originUrl.Trim() } else { '' }
	if ($webUrl -match '^git@github\.com:(.+)\.git$') {
		$webUrl = 'https://github.com/' + $Matches[1]
	} elseif ($webUrl -match '^git@github\.com:(.+)$') {
		$webUrl = 'https://github.com/' + $Matches[1]
	} elseif ($webUrl) {
		$webUrl = $webUrl -replace '\.git$', ''
	}
	Write-Host ""
	Write-Host "  -----------------------------------------" -ForegroundColor Green
	Write-Host "  Subida correcta." -ForegroundColor Green
	if ($webUrl) {
		Write-Host "  Repositorio: $webUrl" -ForegroundColor Green
	}
	Write-Host "  Rama subida: $branch" -ForegroundColor Green
	Write-Host "  -----------------------------------------" -ForegroundColor Green
	Write-Host ""
	Read-Host "  Pulsa Enter para volver al menú"
}

function Test-GitLinkedWorkTree {
	$p = Join-Path (Get-Location) '.git'
	if (-not (Test-Path -LiteralPath $p)) {
		return $false
	}
	return -not (Test-Path -LiteralPath $p -PathType Container)
}

function Remove-RepoFlow {
	Enter-ProjectRoot
	if (-not (Test-LocalGitMetadata)) {
		Write-Host "  No hay .git en esta carpeta del proyecto (quizá el repo está solo en una carpeta superior)." -ForegroundColor Yellow
		Read-Host "  Pulsa Enter"
		return
	}
	if (Test-GitLinkedWorkTree) {
		Write-Host "  Esta carpeta es un worktree de Git (.git es un archivo enlace)." -ForegroundColor Yellow
		Write-Host "  La opción 3 no borra el repositorio completo; ve a la carpeta principal del repo o usa 'git worktree remove'." -ForegroundColor Yellow
		Read-Host "  Pulsa Enter"
		return
	}

	Write-Host ""
	Write-Host "  ATENCIÓN: se borrará solo el historial Git local (.git)." -ForegroundColor Red
	Write-Host "  Tus archivos del proyecto NO se borran." -ForegroundColor DarkYellow
	$confirm = Read-Host "  Escribe SI en mayúsculas para confirmar"
	if ($null -ne $confirm) {
		$confirm = $confirm.Trim()
	}
	if ($confirm -ne 'SI') {
		Write-Host "  Cancelado." -ForegroundColor Gray
		Read-Host "  Pulsa Enter"
		return
	}

	$gitPath = Join-Path (Get-Location) '.git'
	Write-Step "Eliminando .git ..."
	try {
		Remove-Item -LiteralPath $gitPath -Recurse -Force -ErrorAction Stop
	} catch {
		Write-Host "  No se pudo borrar .git (permisos o archivo en uso): $_" -ForegroundColor Red
		Read-Host "  Pulsa Enter"
		return
	}
	if (Test-Path -LiteralPath $gitPath) {
		Write-Host "  .git sigue existiendo; revisa permisos o procesos que lo usen." -ForegroundColor Red
		Read-Host "  Pulsa Enter"
		return
	}
	Write-Host ""
	Write-Host "  Repositorio Git local eliminado. Puedes usar la opción 1 para enlazar un repo nuevo." -ForegroundColor Green
	Read-Host "  Pulsa Enter para volver al menú"
}

# --- Carpeta del script ---
$scriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptDir)) {
	$scriptDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
}
if ([string]::IsNullOrWhiteSpace($scriptDir) -or -not (Test-Path -LiteralPath $scriptDir)) {
	Write-Host "No se pudo determinar la carpeta del script." -ForegroundColor Red
	exit 1
}
Set-Location -LiteralPath $scriptDir
$script:SubirGithubRoot = (Get-Location).Path

if (-not (Test-GitAvailable)) {
	Write-Host "Git no está instalado o no está en el PATH. Instálalo y vuelve a ejecutar este script." -ForegroundColor Red
	exit 1
}

function Assert-NotUserProfileRoot {
	$userProfileDir = [Environment]::GetFolderPath('UserProfile')
	if ([string]::IsNullOrWhiteSpace($userProfileDir)) {
		return $true
	}
	$root = $script:SubirGithubRoot.TrimEnd('\')
	$userProfileNorm = $userProfileDir.TrimEnd('\')
	if ($root -ieq $userProfileNorm) {
		Write-Host ""
		Write-Host "  Este script no puede estar en la raíz de tu usuario ($userProfileDir)." -ForegroundColor Red
		Write-Host "  Git intentaría procesar toda la carpeta (Cookies, Configuración local...) y fallará." -ForegroundColor Yellow
		Write-Host "  Copia SubirGithub.ps1 y SubirGithub.cmd a la carpeta DEL PROYECTO, por ejemplo:" -ForegroundColor Yellow
		Write-Host "    C:\Users\User\Downloads\Msg" -ForegroundColor Cyan
		Write-Host "  y ejecútalos desde esa carpeta (o doble clic ahí)." -ForegroundColor Yellow
		Write-Host ""
		Read-Host "  Pulsa Enter"
		return $false
	}
	return $true
}

function Enter-ProjectRoot {
	Set-Location -LiteralPath $script:SubirGithubRoot
}

while ($true) {
	Enter-ProjectRoot
	Show-Menu
	Write-Host "  Carpeta del proyecto: $script:SubirGithubRoot" -ForegroundColor DarkGray
	$choice = Read-Host "  Elige (1-4)"
	if ($null -ne $choice) {
		$choice = $choice.Trim()
	}

	switch ($choice) {
		'1' { New-RepoFlow }
		'2' { Existing-RepoFlow }
		'3' { Remove-RepoFlow }
		'4' {
			Write-Host "  Hasta luego." -ForegroundColor Cyan
			exit 0
		}
		Default {
			Write-Host "  Opción no válida." -ForegroundColor Red
			Start-Sleep -Seconds 1
		}
	}
}
