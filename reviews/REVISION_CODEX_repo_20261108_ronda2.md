# Revisión independiente — `cesgen-health-data-r`

Fecha de revisión: 08/11/2026.  
Alcance: revisión de solo lectura del código, plantillas, pruebas y contenidos `content_en*.py` / `content_es*.py`; las ejecuciones se hicieron en una copia temporal fuera del repositorio.

## Resumen ejecutivo

No he encontrado un hallazgo de severidad **alta**, ni datos personales reales, secretos, rutas absolutas operativas o escrituras por defecto fuera del proyecto. Los datos versionados son código y las carpetas generadas `data-sim/out/` y `output/` están ignoradas.

El núcleo estadístico revisado es coherente con la simulación: los efectos PH01/PH03/PH05 se plantan en `simulate_ehr()`, L21 corrige los p-valores sobre los análisis válidos y protege frente a celdas degeneradas; L13 separa descubrimiento, calibración y prueba; L32 ilustra la doble inmersión sin usar la evaluación para seleccionar. Las afirmaciones cuantitativas comprobadas coinciden con la salida: L32 produjo AUC aparente 0,862 y honesta 0,517; L20 dio 5 % de estudios con falso positivo familiar tras Bonferroni; L21 recuperó PH01 y PH03 con Bonferroni en el centro A y PH05 quedó, como se advierte, con potencia insuficiente.

Hay dos mejoras necesarias para que la promesa de reproducibilidad sea completa: el proyecto contiene un `renv.lock`, pero ni la guía ni la integración continua lo restauran, y los generadores públicos no validan sus tamaños mínimos. La plantilla de paquete pasó `document()`, `test()` y `check()` en la copia temporal.

## Hallazgos

### Media — El `renv.lock` no es el mecanismo que usan ni el alumnado ni la CI

**Ubicación:** `README.md:14`, `install_packages.R:3-4`, `.github/workflows/check.yaml:29-30`.

**Problema:** existe un `renv.lock` con R 4.6.1 y las dependencias fijadas, pero la instrucción principal es `source("install_packages.R")`, que instala la última versión disponible de CRAN. La CI hace lo mismo y no ejecuta `renv::restore()`. El comentario describe renv como una opción que habría que inicializar, pese a que ya hay un lockfile. Por tanto, una instalación limpia no reproduce necesariamente las versiones con las que se verificó el curso.

**Evidencia / reproducción mínima:** el lockfile contiene todos los paquetes declarados, pero ninguna de las rutas de arranque o de CI menciona `renv::restore()`. Ejecutar la CI hoy instala paquetes actuales, no las versiones del lockfile. Esta diferencia puede cambiar resultados, APIs o el comportamiento de dependencias espaciales.

**Corrección propuesta:** decidir una única ruta reproducible: añadir `.Rprofile`/activación de renv, documentar `renv::restore()` como paso principal y usarlo en CI; o retirar `renv.lock` si se pretende deliberadamente probar siempre contra versiones recientes. Si se conservan ambas rutas, etiquetar la instalación no fijada como «últimas versiones, no reproducible bit a bit».

### Baja — Los generadores parametrizables fallan o devuelven datos no válidos con tamaños pequeños

**Ubicación:** `R/simulate_genotypes.R:19-24, 62-75`; `R/simulate_areas.R:6-26`.

**Problema:** las firmas exponen parámetros de tamaño, pero no validan sus límites. `simulate_consumer_file(n_snps = 5)` falla con `invalid 'size' argument`, porque hay seis anclas. `simulate_population(n = 10, n_snps = 7)` falla al intentar seleccionar ocho SNP causales sin reemplazo. `simulate_areas(nx = 1, ny = 1)` termina con el aviso `NAs produced` al escalar un único valor y puede generar tasas/casos no finitos.

**Evidencia / reproducción mínima:**

```r
source("R/simulate_genotypes.R")
simulate_consumer_file(tempfile(), n_snps = 5)
simulate_population(n = 10, n_snps = 7)
source("R/simulate_areas.R")
simulate_areas(1, 1)
```

**Corrección propuesta:** validar explícitamente `n_snps >= nrow(anchor_variants())`, `n_snps >= 8`, `n >= 1` y `nx, ny >= 2`, con mensajes didácticos. Alternativamente, hacer que el número de SNP causales sea `min(8, n_snps)` y documentarlo. Añadir pruebas de esos límites y de una llamada pequeña válida.

### Baja — Las anclas de variantes simplifican variantes multialélicas sin decirlo

**Ubicación:** `R/simulate_genotypes.R:3-14`.

**Problema:** se presentan `ref` y `alt` como las alelas de las anclas, aunque algunas entradas de dbSNP/Ensembl GRCh37 son multialélicas: por ejemplo rs1801133 es `G/A/C`, rs4988235 `G/A/C/T`, rs12913832 `A/C/G` y rs1805007 `C/A/G/T`. El par elegido en el código es compatible con una alternativa real y las seis posiciones/cromosomas fueron verificadas, pero el formato actual puede hacer creer que se ha enumerado el conjunto completo de alelas.

**Evidencia:** consulta de la API GRCh37 de Ensembl para los seis rsID; las coordenadas del repositorio coinciden (incluido rs1805007, chr16:89986117), mientras que las cadenas de alelas de los cuatro rsID anteriores contienen alternativas adicionales.

**Corrección propuesta:** renombrar a `simulated_ref` / `simulated_alt` o añadir una nota junto a la tabla: «para docencia se escoge un par de alelas del registro multialélico; no es una anotación clínica completa». Conservar la advertencia actual de que los genotipos son simulados.

## Comprobaciones transversales

- **Ejecución y pruebas.** En R 4.6.1, la generación de datos terminó correctamente. La suite `tests/testthat` terminó sin fallos; la única prueba omitida fue el renderizado Quarto porque el ejecutable de línea de comandos no estaba instalado. Se ejecutaron además L20 (19 s), L21 (4 s), L29 (5 s), L30, L32, L38 (2,59 s) y L40 en la copia temporal; todos terminaron correctamente y ninguno de los medidos superó 60 s. No afirmo haber podido certificar el tiempo de cada uno de los 70 scripts individualmente.
- **Paquete de las lecciones 36–40.** En una copia temporal, `devtools::document()`, `testthat::test_local()` y `devtools::check(document = FALSE, manual = FALSE, cran = FALSE)` terminaron con 0 errores, 0 avisos y 0 notas. PITS concuerda con lo dicho: su `DESCRIPTION` declara licencia MIT, y su copia local contiene tres viñetas; L36 y L38 lo tratan correctamente como demostración opcional.
- **Estadística.** La corrección Bonferroni/BH de L21 se aplica solo a las pruebas ajustadas realmente ejecutadas; los estratos con pocos eventos/no-eventos se etiquetan y no producen OR infinitos. La combinación de dos centros usa log(OR), error estándar e inversa de la varianza y se contrasta con el cálculo manual. L13 no reutiliza el conjunto de prueba en selección/calibración. L29/L30 se califican correctamente de ecológicos y no causales; su modelo de tasa logarítmica es una aproximación didáctica, no una inferencia individual.
- **Contenido frente a salida.** Comprobé las referencias `script_file`: las 70 referencias existentes en los módulos EN/ES apuntan a scripts presentes. Las cifras verificadas de L13 (OR 1,3: incremento ≈0,58 puntos con riesgo basal 2 % y ≈5,71 con 30 %) y las de L20/L32 coinciden con el código/salida. No identifiqué otro desajuste concreto entre las diapositivas/notas/tareas revisadas y el código.
- **Hechos externos.** La explicación de OMOP deja claro que las tablas y conceptos son didácticos y no el CDM completo; esto es coherente con la documentación de OHDSI sobre `concept_id`. La lección ClinVar/ACMG usa explícitamente tablas de juguete y exige verificar la versión real antes de uso. La documentación del GWAS Catalog confirma que sus asociaciones superiores se seleccionan con p < 1e-5 y que los rsID/ensamblaje deben comprobarse contra la fuente y el build.
- **Privacidad y seguridad.** No encontré secretos por patrón, ni ficheros de datos simulados generados bajo control de versiones. Las reglas de no cargar datos reales en las plantillas de asistencia por IA están presentes. Las escrituras observadas usan `output/`, `data-sim/out/` o `tempdir()`; `output/` y `data-sim/out/` están en `.gitignore`.

## Lista priorizada de correcciones

1. Hacer efectivo el lockfile en README y CI, o eliminarlo y declarar que se prueba contra paquetes actuales.
2. Añadir validación de dominios y pruebas de borde a los tres generadores señalados.
3. Etiquetar los pares de alelas de las anclas como una simplificación didáctica de registros potencialmente multialélicos.
4. En un entorno que incluya el ejecutable Quarto, ejecutar y registrar la prueba de renderizado de `templates/report_template.qmd`.

## Lo que no pude verificar

- El renderizado Quarto: está instalado el paquete R `quarto`, pero no el binario Quarto requerido por la prueba.
- La ejecución integral cronometrada de los 70 scripts/soluciones uno por uno; sí se completaron la suite unitaria y las lecciones de mayor carga seleccionadas arriba.
- La disponibilidad actual en CRAN de PITS, porque la lección prudentemente la condiciona a que esté instalado; la revisión se hizo contra la copia local indicada.
- La clasificación clínica actual de ClinVar y la lista ACMG vigente para una variante concreta: el curso no las presenta como datos reales ni las descarga, y sus propias instrucciones piden comprobar versión, fecha y procedencia antes de usarlas.

## Fuentes externas consultadas

- Ensembl REST, variaciones GRCh37: `https://grch37.rest.ensembl.org/variation/human/rs1801133` (y las consultas equivalentes para los otros cinco rsID).
- OHDSI, convenciones del Common Data Model: `https://ohdsi.github.io/CommonDataModel/dataModelConventions.html`.
- GWAS Catalog, criterios de inclusión y API: `https://www.ebi.ac.uk/gwas/docs/methods/criteria/` y `https://www.ebi.ac.uk/gwas/docs/programmatic-access/rest-api/`.
