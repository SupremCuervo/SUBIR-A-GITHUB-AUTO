#!/usr/bin/env bash
# SubirGithub — menú para subir a GitHub (nuevo remoto, actual o borrar .git)
# Linux / macOS / Git Bash en Windows

set -u

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
DARK_YELLOW='\033[0;33m'
DARK_GRAY='\033[0;90m'
NC='\033[0m'

cd_to_script_dir() {
	local dir
	dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	cd "$dir" || exit 1
}

require_git() {
	if ! command -v git >/dev/null 2>&1; then
		printf '%bGit no está instalado o no está en el PATH. Instálalo y vuelve a ejecutar este script.%b\n' "$RED" "$NC" >&2
		exit 1
	fi
}

# Raíz del proyecto = carpeta donde está este script (ruta absoluta)
SUBIR_ROOT=""

enter_project_root() {
	cd "$SUBIR_ROOT" || exit 1
}

assert_not_home_root() {
	local here home
	here="$(pwd -P)"
	home="$(cd ~ && pwd -P)"
	if [[ "$here" == "$home" ]]; then
		printf '\n  %bEste script no puede estar solo en la raíz de tu usuario (%s).%b\n' "$RED" "$home" "$NC"
		printf '  %bGit intentaría procesar toda la carpeta y fallará (permisos, Cookies, etc.).%b\n' "$YELLOW" "$NC"
		printf '  %bCopia SubirGithub.sh a la carpeta DEL PROYECTO y ejecútalo ahí.%b\n' "$YELLOW" "$NC"
		printf '\n'
		read -r -p '  Pulsa Enter ' _
		return 1
	fi
	return 0
}

write_step() {
	printf '\n  %b>> %s%b\n' "$YELLOW" "$1" "$NC"
}

# Muestra la etiqueta del paso, ejecuta git y el código de salida
git_run_visible() {
	local label="$1"
	shift
	local ec=0
	printf '\n  %b=== %s ===%b\n' "$CYAN" "$label" "$NC"
	"$@"
	ec=$?
	if [[ $ec -eq 0 ]]; then
		printf '  %b=== fin (código salida: %s) ===%b\n' "$DARK_GRAY" "$ec" "$NC"
	else
		printf '  %b=== fin (código salida: %s) ===%b\n' "$RED" "$ec" "$NC"
	fi
	return $ec
}

to_github_web_url() {
	local u="$1"
	u="${u%.git}"
	case "$u" in
		git@github.com:*)
			u="https://github.com/${u#git@github.com:}"
			;;
	esac
	printf '%s' "$u"
}

is_git_repo() {
	git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

# ¿Hay .git en la carpeta del proyecto? (no basta con estar dentro de un repo padre)
has_local_git() {
	[[ -d "$SUBIR_ROOT/.git" ]] || [[ -f "$SUBIR_ROOT/.git" ]]
}

show_menu() {
	printf '\n  %b_______________________________________%b\n' "$DARK_GRAY" "$NC"
	printf '\n  %b========== SubirGithub ==========%b\n' "$CYAN" "$NC"
	printf '  1) Subir a nuevo repositorio\n'
	printf '  2) Subir a repositorio actual\n'
	printf '  3) Eliminar repositorio actual (.git)\n'
	printf '  4) Salir\n'
	printf '  %b=================================%b\n\n' "$CYAN" "$NC"
}

trim() {
	local s="$1"
	s="${s#"${s%%[![:space:]]*}"}"
	s="${s%"${s##*[![:space:]]}"}"
	printf '%s' "$s"
}

new_repo_flow() {
	local commit_msg remote_url ec

	enter_project_root
	assert_not_home_root || return

	printf '\n  %bCarpeta de trabajo: %s%b\n' "$DARK_GRAY" "$(pwd -P)" "$NC"
	printf '\n  %b--- Nuevo repositorio (como primer subida) ---%b\n' "$GREEN" "$NC"
	printf '  Mensaje del commit: '
	read -r commit_msg
	commit_msg="$(trim "$commit_msg")"
	if [[ -z "$commit_msg" ]]; then
		printf '  %bEl commit no puede estar vacío.%b\n' "$RED" "$NC"
		read -r -p '  Pulsa Enter para volver ' _
		return
	fi

	printf '  Enlace del repositorio GitHub (HTTPS): '
	read -r remote_url
	remote_url="$(trim "$remote_url")"
	if [[ -z "$remote_url" ]]; then
		printf '  %bEl enlace no puede estar vacío.%b\n' "$RED" "$NC"
		read -r -p '  Pulsa Enter para volver ' _
		return
	fi

	if ! has_local_git; then
		if is_git_repo; then
			foreign="$(git rev-parse --show-toplevel 2>/dev/null || true)"
			foreign="$(trim "$foreign")"
			here="$(cd "$SUBIR_ROOT" && pwd -P)"
			if [[ -n "$foreign" && "$foreign" != "$here" ]]; then
				printf '\n  %bIMPORTANTE: Git tenía la raíz en otra carpeta (repo muy grande):%b\n' "$YELLOW" "$NC"
				printf '    %s\n' "$foreign"
				printf '  %bSe crea un repositorio NUEVO solo en tu proyecto:%b\n' "$GREEN" "$NC"
				printf '    %s\n\n' "$here"
			fi
		fi
		write_step "Inicializar repositorio (git init en esta carpeta)"
		if ! git_run_visible "git init" git init; then
			printf '  %bError en git init.%b\n' "$RED" "$NC"
			read -r -p '  Pulsa Enter ' _
			return
		fi
	fi

	write_step "Quitar remoto origin (si existía)"
	printf '\n  %b=== git remote remove origin ===%b\n' "$CYAN" "$NC"
	git remote remove origin 2>/dev/null || true
	printf '  %b=== fin ===%b\n' "$DARK_GRAY" "$NC"

	write_step "Añadir remoto GitHub"
	if ! git_run_visible "git remote add origin <url>" git remote add origin "$remote_url"; then
		printf '  %bError al añadir remote. ¿Ya existe '\''origin'\''? Prueba opción 2 o elimina .git (3).%b\n' "$RED" "$NC"
		read -r -p '  Pulsa Enter ' _
		return
	fi
	printf '  %bRemoto guardado:%b\n' "$DARK_GRAY" "$NC"
	git remote -v

	write_step "Añadir archivos (git add .)"
	if ! git_run_visible "git add ." git add .; then
		printf '  %bError en git add.%b\n' "$RED" "$NC"
		read -r -p '  Pulsa Enter ' _
		return
	fi
	printf '  %bEstado del repo:%b\n' "$DARK_GRAY" "$NC"
	git status -sb
	printf '\n'

	write_step "Crear commit"
	if ! git_run_visible "git commit -m \"...\"" git commit -m "$commit_msg"; then
		printf '  %bNo hay cambios para commitear o hubo error (¿nada que añadir?).%b\n' "$YELLOW" "$NC"
		read -r -p '  Pulsa Enter ' _
		return
	fi
	printf '  %bÚltimo commit:%b\n' "$DARK_GRAY" "$NC"
	git log -1 --oneline
	printf '\n'

	write_step "Renombrar rama local a main"
	git_run_visible "git branch -M main" git branch -M main

	write_step "Subir a GitHub (push)"
	if ! git_run_visible "git push -u origin main" git push -u origin main; then
		printf '  %bError en push. Revisa credenciales, rama remota y que el repo en GitHub esté vacío o permita push.%b\n' "$RED" "$NC"
		read -r -p '  Pulsa Enter ' _
		return
	fi

	web_url="$(to_github_web_url "$remote_url")"
	printf '\n  %b-----------------------------------------%b\n' "$GREEN" "$NC"
	printf '  %bSubida correcta (procedimiento terminado).%b\n' "$GREEN" "$NC"
	printf '  %bRepositorio en GitHub: %s%b\n' "$GREEN" "$web_url" "$NC"
	printf '  %bRama subida: main%b\n' "$GREEN" "$NC"
	printf '  %b-----------------------------------------%b\n' "$GREEN" "$NC"
	printf '  %bSi GitHub mostraba vacío, recarga la página del repo.%b\n' "$DARK_GRAY" "$NC"
	printf '\n'
	read -r -p '  Pulsa Enter para volver al menú ' _
}

existing_repo_flow() {
	local current_branch branch commit_msg do_push

	enter_project_root
	assert_not_home_root || return

	if ! has_local_git; then
		if is_git_repo; then
			printf '  %bNo hay .git en esta carpeta; solo estás dentro de un repo en una carpeta superior.%b\n' "$RED" "$NC"
			printf '  %bUsa la opción 1 para crear un repo solo aquí.%b\n' "$YELLOW" "$NC"
		else
			printf '  %bNo hay repositorio Git aquí. Usa la opción 1.%b\n' "$RED" "$NC"
		fi
		read -r -p '  Pulsa Enter ' _
		return
	fi

	printf '\n  %b--- Repositorio actual ---%b\n' "$GREEN" "$NC"
	printf '\n  %b=== git remote -v ===%b\n' "$CYAN" "$NC"
	git remote -v
	printf '  %b=== fin ===%b\n\n' "$DARK_GRAY" "$NC"

	printf '  %b=== git branch -a ===%b\n' "$CYAN" "$NC"
	git branch -a
	printf '  %b=== fin ===%b\n\n' "$DARK_GRAY" "$NC"

	current_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
	current_branch="$(trim "$current_branch")"
	[[ -z "$current_branch" ]] && current_branch="main"

	if [[ "$current_branch" == "HEAD" ]]; then
		printf '  %bAviso: HEAD detached (sin rama con nombre). Elige una rama de la lista o créala antes de subir.%b\n' "$YELLOW" "$NC"
	fi
	printf '  %bRama actual detectada: %s%b\n' "$DARK_GRAY" "$current_branch" "$NC"
	printf '  Escribe el nombre de la rama a subir (Enter = %s): ' "$current_branch"
	read -r branch
	branch="$(trim "$branch")"
	[[ -z "$branch" ]] && branch="$current_branch"

	printf '  Mensaje del commit: '
	read -r commit_msg
	commit_msg="$(trim "$commit_msg")"
	if [[ -z "$commit_msg" ]]; then
		printf '  %bEl commit no puede estar vacío.%b\n' "$RED" "$NC"
		read -r -p '  Pulsa Enter ' _
		return
	fi

	write_step "Añadir cambios (git add .)"
	if ! git_run_visible "git add ." git add .; then
		printf '  %bError en git add.%b\n' "$RED" "$NC"
		read -r -p '  Pulsa Enter ' _
		return
	fi
	printf '  %bEstado:%b\n' "$DARK_GRAY" "$NC"
	git status -sb
	printf '\n'

	write_step "Crear commit"
	if ! git_run_visible "git commit -m \"...\"" git commit -m "$commit_msg"; then
		printf '  %bSin cambios nuevos o error en commit. Si no hay nada que commitear, puedes hacer solo push (manual: git push origin %s).%b\n' "$YELLOW" "$branch" "$NC"
		read -r -p '  ¿Intentar push igual? (s/N) ' do_push
		do_push="$(trim "$do_push")"
		if [[ ! "$do_push" =~ ^[sSyY] ]]; then
			read -r -p '  Pulsa Enter ' _
			return
		fi
	else
		printf '  %bÚltimo commit:%b\n' "$DARK_GRAY" "$NC"
		git log -1 --oneline
		printf '\n'
	fi

	write_step "Subir rama a GitHub (push)"
	if ! git_run_visible "git push origin $branch" git push origin "$branch"; then
		printf '  %bError en push.%b\n' "$RED" "$NC"
		read -r -p '  Pulsa Enter ' _
		return
	fi

	origin_url="$(git remote get-url origin 2>/dev/null || true)"
	web_url=""
	if [[ -n "$origin_url" ]]; then
		web_url="$(to_github_web_url "$origin_url")"
	fi
	printf '\n  %b-----------------------------------------%b\n' "$GREEN" "$NC"
	printf '  %bSubida correcta.%b\n' "$GREEN" "$NC"
	if [[ -n "$web_url" ]]; then
		printf '  %bRepositorio: %s%b\n' "$GREEN" "$web_url" "$NC"
	fi
	printf '  %bRama subida: %s%b\n' "$GREEN" "$branch" "$NC"
	printf '  %b-----------------------------------------%b\n' "$GREEN" "$NC"
	printf '\n'
	read -r -p '  Pulsa Enter para volver al menú ' _
}

is_linked_worktree() {
	[[ -f .git ]]
}

remove_repo_flow() {
	local confirm

	enter_project_root

	if ! has_local_git; then
		printf '  %bNo hay .git en esta carpeta del proyecto (quizá el repo está solo arriba).%b\n' "$YELLOW" "$NC"
		read -r -p '  Pulsa Enter ' _
		return
	fi
	if is_linked_worktree; then
		printf '  %bEsta carpeta es un worktree de Git (.git es un archivo enlace).%b\n' "$YELLOW" "$NC"
		printf '  %bLa opción 3 no borra el repositorio completo; usa la carpeta principal o: git worktree remove%b\n' "$YELLOW" "$NC"
		read -r -p '  Pulsa Enter ' _
		return
	fi

	printf '\n  %bATENCIÓN: se borrará solo el historial Git local (.git).%b\n' "$RED" "$NC"
	printf '  %bTus archivos del proyecto NO se borran.%b\n' "$DARK_YELLOW" "$NC"
	read -r -p '  Escribe SI en mayúsculas para confirmar: ' confirm
	confirm="$(trim "$confirm")"
	if [[ "$confirm" != "SI" ]]; then
		printf '  Cancelado.\n'
		read -r -p '  Pulsa Enter ' _
		return
	fi

	write_step "Eliminando .git ..."
	if ! rm -rf .git; then
		printf '  %bNo se pudo borrar .git (permisos o error del sistema).%b\n' "$RED" "$NC"
		read -r -p '  Pulsa Enter ' _
		return
	fi
	if [[ -e .git ]]; then
		printf '  %b.git sigue existiendo; revisa permisos o procesos que lo usen.%b\n' "$RED" "$NC"
		read -r -p '  Pulsa Enter ' _
		return
	fi
	printf '\n  %bRepositorio Git local eliminado. Puedes usar la opción 1 para enlazar un repo nuevo.%b\n' "$GREEN" "$NC"
	read -r -p '  Pulsa Enter para volver al menú ' _
}

# --- Carpeta del script ---
cd_to_script_dir
SUBIR_ROOT="$(pwd -P)"
require_git

while true; do
	enter_project_root
	show_menu
	printf '  %bCarpeta del proyecto: %s%b\n' "$DARK_GRAY" "$SUBIR_ROOT" "$NC"
	printf '  Elige (1-4): '
	read -r choice
	choice="$(trim "$choice")"

	case "$choice" in
		1) new_repo_flow ;;
		2) existing_repo_flow ;;
		3) remove_repo_flow ;;
		4)
			printf '  %bHasta luego.%b\n' "$CYAN" "$NC"
			exit 0
			;;
		*)
			printf '  %bOpción no válida.%b\n' "$RED" "$NC"
			sleep 1
			;;
	esac
done
