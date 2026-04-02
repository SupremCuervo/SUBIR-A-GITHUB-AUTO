# SubirGithub

Menú interactivo para **subir un proyecto a GitHub** sin tener que recordar la secuencia de comandos: nuevo repositorio, actualizar el remoto o **eliminar solo el historial Git local** (`.git`) y empezar de cero.

Hay dos implementaciones con el **mismo menú**:

- **Windows:** PowerShell (`SubirGithub.ps1`) y acceso rápido con `SubirGithub.cmd`.
- **Linux / macOS / Git Bash:** Bash (`SubirGithub.sh`).

Los scripts **siempre trabajan en la carpeta donde están** (útil si copias los archivos a la raíz de otro proyecto).

**Resumen rápido — cómo ejecutar**

| Sistema | Qué hacer |
|---------|-----------|
| **Windows** | Doble clic en `SubirGithub.cmd` **o** abre PowerShell en esa carpeta y ejecuta `.\SubirGithub.ps1`. |
| **Linux / macOS** | En la terminal: `cd` a la carpeta del proyecto, luego `./SubirGithub.sh` (tras `chmod +x SubirGithub.sh` la primera vez) o `bash SubirGithub.sh`. |
| **Git Bash (Windows)** | Abre Git Bash, `cd` a la carpeta del proyecto, ejecuta `bash SubirGithub.sh`. |

---

## Requisitos

- **Git** instalado y en el `PATH` (`git --version`).
- Cuenta en **GitHub** y forma de autenticarte al hacer `push` (SSH, **token personal** HTTPS, `gh auth login`, etc.).

**Por plataforma**

| Plataforma | Necesitas |
|------------|-----------|
| **Windows** | PowerShell 5.1+ (incluido en Windows 10/11). |
| **Linux / macOS** | Bash (casi siempre `/bin/bash` o `bash` del sistema). |

---

## Cómo ejecutar (paso a paso)

### 1. Coloca los scripts en tu proyecto

Copia `SubirGithub.cmd`, `SubirGithub.ps1` y/o `SubirGithub.sh` en la **carpeta raíz** del repositorio (donde quieres el `.git`). El menú operará **siempre sobre esa carpeta**, aunque ejecutes el script desde otro sitio (el propio script hace `cd` a su ubicación).

### 2. Elige tu sistema y ejecuta

#### Windows — forma más simple

1. Abre la carpeta del proyecto en el Explorador de archivos.
2. **Doble clic** en **`SubirGithub.cmd`**.  
   Se abrirá una ventana con el menú (1–4).

#### Windows — PowerShell

1. Abre **PowerShell**.
2. Ve a la carpeta donde está el script (cambia la ruta por la tuya):

```powershell
cd C:\Users\User\Downloads\Msg
```

3. Ejecuta:

```powershell
.\SubirGithub.ps1
```

4. Si sale *no se pueden cargar scripts porque la ejecución está deshabilitada*, ejecuta **una vez** (solo tu usuario):

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

Vuelve a lanzar `.\SubirGithub.ps1`.

#### Linux y macOS — Terminal

1. Abre la terminal.
2. Ve a la carpeta del proyecto:

```bash
cd /ruta/a/tu/proyecto
```

3. **Primera vez solamente**, permiso de ejecución:

```bash
chmod +x SubirGithub.sh
```

4. Ejecuta:

```bash
./SubirGithub.sh
```

**Sin** `chmod` (también válido):

```bash
bash SubirGithub.sh
```

#### Git Bash en Windows

1. Abre **Git Bash**.
2. Navega a la carpeta (ejemplo con ruta típica bajo `C:`):

```bash
cd /c/Users/User/Downloads/Msg
```

3. Ejecuta:

```bash
bash SubirGithub.sh
```

### 3. Usar el menú

Escribe **1**, **2**, **3** o **4** y pulsa **Enter**. Sigue las preguntas en pantalla (commit, URL de GitHub, rama, etc.).

---

## Menú

| Opción | Descripción |
|--------|-------------|
| **1 — Subir a nuevo repositorio** | Pide el **mensaje del commit** y la **URL HTTPS** del repo en GitHub. Si no existe `.git`, ejecuta `git init`. Quita `origin` si ya existía, añade el remoto, `git add .`, `git commit`, renombra la rama a **`main`** y hace `git push -u origin main`. Cada paso se muestra con `>>` en pantalla. |
| **2 — Subir a repositorio actual** | Muestra `git remote -v` y `git branch -a`. Pides en qué **rama** subir (Enter = rama actual) y el **mensaje del commit**. Luego `git add .`, `git commit` y `git push origin <rama>`. Si no hay cambios que commitear, pregunta si quieres intentar el **push** igual. |
| **3 — Eliminar repositorio actual** | Borra la carpeta **`.git`** (tus archivos del proyecto **no** se eliminan). Pide escribir **`SI`** en mayúsculas para confirmar. Después puedes usar la opción **1** para enlazar un repo nuevo. |
| **4 — Salir** | Cierra el menú. |

---

## Problemas frecuentes

### Avisos de `Permission denied` con `Cookies`, `Configuración local`, `Mis documentos`…

Significa que **Git estaba actuando sobre tu carpeta de usuario** (`C:\Users\Usuario`), no sobre la carpeta del proyecto. Suele pasar si **`SubirGithub.ps1` está en la raíz del usuario** o lo ejecutas desde ahí.

**Qué hacer:**

1. Copia **`SubirGithub.ps1`** y **`SubirGithub.cmd`** a la carpeta del repo (por ejemplo `C:\Users\User\Downloads\Msg`).
2. Abre PowerShell o doble clic en `.cmd` **desde esa carpeta**.
3. El menú muestra **«Carpeta del proyecto: …»**; debe ser la ruta de tu proyecto, **no** solo `C:\Users\…` sin subcarpeta de proyecto.

Si en algún momento hiciste `git init` en el perfil de usuario por error, entra en esa carpeta, borra la carpeta **`.git`** (o usa la opción **3** del script colocándolo con cuidado) y vuelve a usar la opción **1** solo dentro de la carpeta del proyecto.

### `git status` enseña miles de archivos (`Downloads`, `.android`, etc.)

Tu **repositorio Git está en una carpeta demasiado grande** (a veces en `C:\Users\Usuario`), no solo en la carpeta del proyecto. El script ahora **crea un `.git` propio** en la carpeta donde están `SubirGithub.*` si ahí no había uno, y te avisa con el mensaje **«IMPORTANTE: Git tenía la raíz en otra carpeta»**.

Después de subir bien, puedes valorar **eliminar el `.git` equivocado del perfil** solo si sabes lo que haces (copias de seguridad antes). La opción **3** solo borra el `.git` de la carpeta del proyecto.

---

## Notas

- Durante las opciones **1** y **2** verás en la consola cada paso como bloques `=== git … ===` con la **salida real de Git** y el **código de salida** (`0` = bien). Al terminar bien un `push`, aparece un recuadro **«Subida correcta»** con el **enlace web** del repo (por ejemplo [https://github.com/SupremCuervo/SUBIR-A-GITHUB-AUTO](https://github.com/SupremCuervo/SUBIR-A-GITHUB-AUTO)) para comprobarlo en el navegador. Si GitHub seguía mostrando el repo vacío, **recarga la página**.
- El menú **ya no borra toda la pantalla** al volver: el historial del procedimiento queda arriba en la terminal para poder revisarlo.
- El script **no guarda contraseñas**; GitHub usará tu configuración de Git (credenciales, SSH, token).
- En la opción **1**, la rama que se sube es siempre **`main`**. Si el remoto ya tiene historial en otra rama, puede que necesites `pull` o fusión manual.
- Coloca los scripts en la **raíz del proyecto** que quieras versionar.

---

## Archivos del proyecto

| Archivo | Rol |
|---------|-----|
| `SubirGithub.ps1` | Menú y `git` (Windows / PowerShell). |
| `SubirGithub.cmd` | Lanza PowerShell con el `.ps1` en la misma carpeta. |
| `SubirGithub.sh` | Mismo menú en **Bash** (Linux, macOS, Git Bash). |
| `README.md` | Esta documentación. |

---

## Licencia

Úsalo y adáptalo como prefieras para proyectos personales o académicos.
