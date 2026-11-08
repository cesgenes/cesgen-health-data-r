# Final project / Proyecto final

CESGEN · reviewed 08/11/2026 · Educational material; it does not replace a health professional.
Simulated data for teaching purposes / Datos simulados con fin didáctico.

English first, Castellano below (section "Versión en castellano").

---

## 1. Brief

**Goal.** Pose one health question, choose one dataset from the closed list below, analyse it
with R, audit your work for privacy, equity and analytical integrity, and deliver a
reproducible report that says what the data can and cannot support.

**What you deliver.**

1. `report.qmd`: your report, created by copying `report_skeleton.qmd` in this folder.
2. `report.html`: the rendered, self-contained report (one step: `quarto::quarto_render("report.qmd")`
   from this folder, or `quarto render report.qmd` in a terminal).
3. `CHECKLIST.md`: the checklist in this folder, completed (tick each item or write why it does
   not apply).

**Rules.**

- Use only the simulated data of this repository (list below). Do not add real patient data of
  any kind. Label every table and figure "Simulated data for teaching purposes".
- Files named `*_truth.csv` hold the planted truth. Do not use them to build your analysis; open
  them only at the end to compare with what you found.
- Observational data support association, not cause. A statistical result is not a clinical
  conclusion: state the assumption, the alternative explanation and the source of each claim.
- If you test many things (many SNPs, many phenotypes, many areas), correct for multiple
  comparisons. If you select variables or tune a threshold, do it inside a training part and
  report performance on data not used for that choice.
- Report results by group where the data contain groups, with sample size and uncertainty.

**Report structure** (the skeleton already contains these headings).

1. Question and scope (one paragraph; what a "yes" and a "no" would look like).
2. Data: source, licence, privacy statement, and a short description (rows, columns, groups).
3. Methods: steps, partitions, corrections, software versions (session information).
4. Results: tables and figures with captions.
5. Equity and bias audit: who is represented, how things were measured, results by group.
6. Conclusions and limits: what you can claim, what you cannot, and what would change your mind.
7. Reproducibility: how to regenerate the report; seed; session information.

## 2. Closed list of datasets

Generate the data once from the repository root with `source("R/helpers_general.R"); ensure_sim_data()`
(files are written to `data-sim/out/`). For D7 also run `source("data-sim/extra_5.R"); ensure_extra_5_data()`.

| Id | Dataset | Files in `data-sim/out/` | Example questions |
|---|---|---|---|
| D1 | Population with genotypes and traits (three simulated groups G1-G3) | `population_pheno.csv`, `population_genotypes.csv` (check only: `population_truth.csv`) | Which SNPs associate with the trait after correcting for multiple tests? How does a score built on one part perform by group in another part? |
| D2 | Electronic health records of two sites, with an adverse drug event | `ehr_A_patients.csv`, `ehr_A_diagnoses.csv`, `ehr_B_patients.csv`, `ehr_B_diagnoses.csv`, `phenotype_map.csv` (check only: `ehr_truth.csv`) | Which phenotypes associate with the event at site A, and do they replicate at site B? |
| D3 | Small areas with exposure, deprivation and case counts | `areas_sim_attributes.csv` and `areas_sim.gpkg` (written only if the sf package is installed) | How does the exposure relate to the rate after accounting for deprivation? Is there spatial clustering? |
| D4 | Common-data-model style tables for two sites | `omop_site_A/` and `omop_site_B/` (`person.csv`, `condition_occurrence.csv`, `concept.csv`) | Define a cohort with explicit criteria and compare it between the two sites. |
| D5 | A simulated consumer genotyping file | `genotype_consumer_sim.txt` | Read it, assess its quality (no-calls, build, strand) and describe what it can and cannot tell you. |
| D6 | A deliberately messy patient table | `patients_messy.csv` (reference: `patients_clean.csv`) | Clean dates, units, codes and missing values, and document every decision. |
| D7 | A "de-identified" release and an identified register (lesson 31) | `reid_release_sim.csv`, `reid_register_sim.csv` | How risky is the release? Propose and justify a generalisation that gives k >= 5 and state what you lose. |

**Ideas to explore afterwards (not part of this project).** Public real resources such as the
MIMIC-IV demo (PhysioNet), Synthea synthetic patients, the Eunomia OMOP sample (OHDSI), the GWAS
Catalog, gnomAD or ClinVar. Check access and licence before use, and follow the privacy rules of
lesson 7.

## 3. Rubric (100 points)

Score each criterion with the level that best fits: Strong (full points), Adequate (about
two thirds), Needs work (about one third or less). Use it to self-assess or to review a peer.

| Criterion | Points | Strong | Adequate | Needs work |
|---|---|---|---|---|
| 1. Question and scope | 10 | Specific, answerable with the data, and says what would count as a yes or a no | Clear but broad, or the link with the data is loose | Vague, or not answerable with the chosen dataset |
| 2. Data source and licence | 10 | Source, file names, how it was generated and its status as simulated data are stated, with the label on every output | Source stated; some labels or details missing | Source unclear or label missing |
| 3. Privacy | 10 | States that no real data are used, checks identifiers and, where relevant, reports k for any table that would be shared | Privacy mentioned but not checked | Not addressed |
| 4. Method and analysis | 20 | Right method for the question, assumptions stated, multiple comparisons or partitions handled correctly, code runs | Method reasonable; one assumption or correction missing | Method does not fit the question, or selection and evaluation use the same data |
| 5. Equity and bias audit | 15 | Representation and measurement checked; results by group with n and uncertainty; limits of the audit stated | Groups reported without uncertainty, or only representation checked | No group analysis |
| 6. Honest conclusions | 15 | Claims match the evidence; association is not presented as cause; alternatives and limits are explicit | Mostly matched; one over-reach | Conclusions go beyond the data, or results are cherry-picked |
| 7. Reproducibility | 15 | Renders in one step from a clean session; seed, relative paths and session information included | Renders, but needs manual steps | Does not render, or results are pasted by hand |
| 8. Communication | 5 | Clear structure, captions, plain language | Readable; some captions missing | Hard to follow |

Pass suggestion for the course: 60 points or more, with at least some points in criteria 3, 5 and 7.

---

## Versión en castellano

CESGEN · revisado 08/11/2026 · Material formativo; no sustituye a un profesional sanitario.

### 1. Enunciado

**Objetivo.** Plantea una pregunta de salud, elige un conjunto de datos de la lista cerrada de
abajo, analízalo con R, revisa tu trabajo en privacidad, equidad e integridad del análisis y
entrega un informe reproducible que diga qué respaldan los datos y qué no.

**Qué entregas.**

1. `report.qmd`: tu informe, creado a partir de una copia de `report_skeleton.qmd`.
2. `report.html`: el informe generado y autocontenido (en un paso: `quarto::quarto_render("report.qmd")`
   desde esta carpeta, o `quarto render report.qmd` en una terminal).
3. `CHECKLIST.md`: la lista de comprobación de esta carpeta, completada (marca cada punto o
   escribe por qué no aplica).

**Reglas.**

- Usa solo los datos simulados de este repositorio (lista de abajo). No añadas datos reales de
  pacientes. Rotula cada tabla y figura «Datos simulados con fin didáctico».
- Los archivos `*_truth.csv` contienen la verdad plantada. No los uses para construir el análisis;
  ábrelos solo al final para compararlos con lo que encontraste.
- Los datos observacionales respaldan asociación, no causa. Un resultado estadístico no es una
  conclusión clínica: indica el supuesto, la explicación alternativa y la fuente de cada afirmación.
- Si contrastas muchas cosas (muchos SNP, fenotipos o zonas), corrige por comparaciones
  múltiples. Si seleccionas variables o ajustas un umbral, hazlo dentro de una parte de
  entrenamiento y comunica el rendimiento en datos no usados para esa elección.
- Comunica los resultados por grupo cuando los datos tengan grupos, con tamaño de muestra e incertidumbre.

**Estructura del informe** (el esqueleto ya incluye estos apartados): 1) pregunta y alcance;
2) datos: fuente, licencia, declaración de privacidad y descripción breve; 3) métodos;
4) resultados; 5) auditoría de equidad y sesgo; 6) conclusiones y límites; 7) reproducibilidad.

### 2. Lista cerrada de conjuntos de datos

Genera los datos una vez desde la raíz del repositorio con `source("R/helpers_general.R"); ensure_sim_data()`.
Para D7 ejecuta además `source("data-sim/extra_5.R"); ensure_extra_5_data()`. Los archivos están
en la tabla en inglés de arriba (mismos identificadores D1 a D7):

- D1 población con genotipos y rasgos (tres grupos simulados G1-G3);
- D2 historias clínicas electrónicas de dos centros, con un evento adverso a un fármaco;
- D3 áreas pequeñas con exposición, privación y casos;
- D4 tablas con un modelo de datos común para dos centros;
- D5 un archivo simulado de genotipado de consumo;
- D6 una tabla de pacientes deliberadamente desordenada;
- D7 una publicación «desidentificada» y un registro identificado (lección 31).

**Ideas para explorar después (fuera de este proyecto).** Recursos públicos reales como la demo de
MIMIC-IV (PhysioNet), los pacientes sintéticos de Synthea, la muestra OMOP de Eunomia (OHDSI), el
GWAS Catalog, gnomAD o ClinVar. Comprueba el acceso y la licencia antes de usarlos y aplica las
reglas de privacidad de la lección 7.

### 3. Rúbrica (100 puntos)

Puntúa cada criterio con el nivel que mejor encaje: Sólido (puntos completos), Adecuado (unos dos
tercios), A mejorar (un tercio o menos). Sirve para autoevaluarte o para revisar a un compañero.

| Criterio | Puntos | Qué se valora |
|---|---|---|
| 1. Pregunta y alcance | 10 | Concreta, contestable con los datos, y dice qué contaría como un sí o un no |
| 2. Fuente de datos y licencia | 10 | Fuente, archivos, cómo se generaron y su condición de simulados, con el rótulo en cada salida |
| 3. Privacidad | 10 | Declara que no hay datos reales, revisa identificadores y, si procede, indica k de cualquier tabla que se compartiría |
| 4. Método y análisis | 20 | Método adecuado, supuestos explícitos, comparaciones múltiples o particiones bien tratadas, el código se ejecuta |
| 5. Auditoría de equidad y sesgo | 15 | Representación y medición revisadas; resultados por grupo con n e incertidumbre; límites de la auditoría |
| 6. Conclusiones honestas | 15 | Las afirmaciones se ajustan a la evidencia; asociación no presentada como causa; alternativas y límites explícitos |
| 7. Reproducibilidad | 15 | Se genera en un paso desde una sesión limpia; semilla, rutas relativas e información de sesión |
| 8. Comunicación | 5 | Estructura clara, pies de figura y tabla, lenguaje sencillo |

Sugerencia de aprobado: 60 puntos o más, con alguna puntuación en los criterios 3, 5 y 7.
