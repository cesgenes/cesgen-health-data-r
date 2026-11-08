# cesgen-health-data-r

**EN** · Code that accompanies the CESGEN online course *Health Data Analysis with R* (40 lessons, 6 modules).
**ES** · Código que acompaña al curso online de CESGEN *Análisis de datos de salud con R* (40 lecciones, 6 módulos).

> **Status / Estado:** 08/11/2026. All 70 lesson scripts and solutions have been run in R 4.6.1 and the automated tests pass; an independent review is in progress. See `CHECKLOG.md`. / Los 70 scripts y soluciones se han ejecutado en R 4.6.1 y las pruebas automáticas pasan; hay una revisión independiente en curso. Ver `CHECKLOG.md`.
> **Data / Datos:** everything in this repository is **simulated for teaching purposes**. There are no data from real people. / Todo lo de este repositorio son **datos simulados con fin didáctico**. No hay datos de personas reales.
> Educational material; it does not replace a health professional. / Material formativo; no sustituye a un profesional sanitario.

## Quick start / Primeros pasos

1. Install R (4.3 or later; the course was verified with R 4.6.1) and RStudio. / Instala R (4.3 o posterior; el curso se ha verificado con R 4.6.1) y RStudio.
2. Open `cesgen-health-data-r.Rproj` in RStudio. Always run scripts from the repository root. / Abre la carpeta como proyecto y ejecuta siempre desde la raíz.
3. Install the packages: `source("install_packages.R")`.
3b. Optional, exact versions: `install.packages("renv"); renv::restore()` uses `renv.lock` (versions used to verify the course). `install_packages.R` installs the latest versions instead. / Opcional, versiones exactas: `renv::restore()` usa `renv.lock`; `install_packages.R` instala las últimas versiones.
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

## Where it lives / Dónde está

The code is published in CESGEN's GitHub organisation for course code: https://github.com/cesgenes/cesgen-health-data-r / El código está publicado en la organización de GitHub de CESGEN para el código de los cursos: https://github.com/cesgenes/cesgen-health-data-r

## Licence / Licencia

The code and the simulated-data scripts in this repository are released under the MIT licence (see `LICENSE`). The text and figures (README files, guides, templates written as text, diagrams and the figures the lessons produce) are released under CC BY 4.0 (see `LICENSE-CONTENT.md`). The template package in `templates/mini_health_package/` carries its own `LICENSE` file, which is a stub for you to complete with your own name. / El código y los scripts de datos simulados de este repositorio se publican con licencia MIT (ver `LICENSE`). Los textos y las figuras (README, guías, plantillas escritas como texto, diagramas y las figuras que generan las lecciones) se publican con licencia CC BY 4.0 (ver `LICENSE-CONTENT.md`). El paquete de plantilla de `templates/mini_health_package/` lleva su propio archivo `LICENSE`, un borrador que debes completar con tu nombre.

