# cesgen-health-data-r

**EN** · Code that accompanies the CESGEN online course *Health Data Analysis with R* (40 lessons, 6 modules).
**ES** · Código que acompaña al curso online de CESGEN *Análisis de datos de salud con R* (40 lecciones, 6 módulos).

> **Status / Estado:** first local version, 08/11/2026. The scripts have been written but **not yet executed**; see `CHECKLOG.md` once the test pass is done. / Primera versión local, 08/11/2026. Los scripts están escritos pero **aún no se han ejecutado**; ver `CHECKLOG.md` cuando se haga la prueba.
> **Data / Datos:** everything in this repository is **simulated for teaching purposes**. There are no data from real people. / Todo lo de este repositorio son **datos simulados con fin didáctico**. No hay datos de personas reales.
> Educational material; it does not replace a health professional. / Material formativo; no sustituye a un profesional sanitario.

## Quick start / Primeros pasos

1. Install R (4.3 or later) and RStudio. / Instala R (4.3 o posterior) y RStudio.
2. Open `cesgen-health-data-r.Rproj` in RStudio. Always run scripts from the repository root. / Abre la carpeta como proyecto y ejecuta siempre desde la raíz.
3. Install the packages: `source("install_packages.R")`.
4. Generate the simulated data (once; scripts also do it automatically when needed): `source("data-sim/00_generate_all.R")`.
5. Open a lesson script from `lessons/` and run it line by line. / Abre el script de una lección y ejecútalo línea a línea.

## Structure / Estructura

| Folder | Contents |
|---|---|
| `R/` | Shared functions: simulated-data generators, ggplot2 theme, risk helpers, privacy checks |
| `data-sim/` | Seeded generator of all simulated datasets (`out/` is created locally, not committed) |
| `lessons/` | One script per practical lesson, `L<nn>_<topic>.R`; worked solutions in `lessons/solutions/` |
| `templates/` | Quarto report template, final-project template (lessons 34 and 35) and a mini R package (lessons 37 to 39) |
| `tests/` | Automated tests (`testthat`) and a runner for all lesson scripts |

## Course map / Mapa del curso

| Module | Lessons | Topic |
|---|---|---|
| 1 | L1–L7 | Health analytics and R from scratch; privacy rules |
| 2 | L8–L14 | Consumer genetic data: files, traits, annotation, risk, diversity |
| 3 | L15–L23 | Clinical data: quality, cohorts, PheWAS, common data models |
| 4 | L24–L30 | Environment and social determinants: maps and spatial models |
| 5 | L31–L35 | Ethics, equity and reproducible reporting; final project |
| 6 | L36–L40 | From script to package: building R packages for health (case study: PITS) and AI-assisted development |

## Rules for contributors / Normas

- Code, comments and file names in English. / Código, comentarios y nombres de archivo en inglés.
- No real patient data and no real person's genome, ever. / Nunca datos de pacientes reales ni el genoma de una persona real.
- Every figure from simulated data carries the caption "Simulated data for teaching purposes". / Toda figura con datos simulados lleva el pie «Datos simulados con fin didáctico».
- A statistical result is not a clinical conclusion: state the assumption, the alternative and the source. / Un resultado estadístico no es una conclusión clínica.

## Where it lives / Dónde estará

CESGEN's GitHub account for course code: https://github.com/cesgenes. The repository name is **to be confirmed**; until then this folder is a local draft. / Cuenta de GitHub de CESGEN para el código de los cursos: https://github.com/cesgenes. El nombre del repositorio está **por confirmar**; hasta entonces esta carpeta es un borrador local.

## Licence / Licencia

**Pending decision** (see `LICENSE_PENDING.md`). Until a licence is chosen, all rights are reserved by CESGEN. / **Pendiente de decisión.** Hasta entonces, todos los derechos reservados por CESGEN.
