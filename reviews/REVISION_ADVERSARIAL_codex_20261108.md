# Revisión adversarial de la validación — 2026-11-08

## Resumen ejecutivo

La validación demuestra que el estado concreto ejecutado funciona en este equipo: en una copia temporal reproduje L21 y L25, los 92 ficheros R analizan sintácticamente y las pruebas disponibles pasan. No demuestra con la misma solidez que las correcciones estén protegidas contra regresiones ni que el material sea reproducible fuera de esa combinación de R y paquetes.

Hay tres problemas principales. Primero, el conjunto de pruebas no ejecuta ni verifica la corrección múltiple que usa L21: al sustituir Bonferroni y BH por los valores p crudos en una copia temporal, todas las pruebas de estadística y de regresión de Codex pasaron. Segundo, la regla de estimabilidad del PheWAS es un corte arbitrario, posterior a los datos y dependiente del desenlace; reduce el denominador de Bonferroni sin una justificación estadística. Tercero, L25 acepta hasta 100 m de desplazamiento tras una transformación de coordenadas, porque sitúa una cuadrícula ficticia fuera del ámbito geográfico apropiado de EPSG:27700. Eso oculta, en vez de resolver, el ejemplo de transformación que se enseña.

La adición cuasi-Poisson es útil como contraste, pero no convierte L29/L30 en un análisis espacial de recuentos: sus residuos siguen autocorrelacionados. El uso de versiones no fijadas y la CI de una única plataforma/version de R dejan sin demostrar la promesa de reproducibilidad.

## Hallazgos

### Alta

#### A1. Las pruebas no protegen la corrección múltiple real de L21

**Ficheros:** `lessons/L21_phewas_run.R:120-127`, `tests/testthat/test-statistics.R:1-15`, `tests/testthat/test-codex-regressions.R`.

**Evidencia.** `test-statistics.R` ajusta sus propios GLM y decide los hallazgos con `p_value < bonferroni_threshold(nrow(res))`; no llama a `run_phewas()` ni a `add_corrections()`. Las pruebas de regresión sólo comprueban el filtro de celdas y que el OR sea finito. Tampoco ejecutan la parte final de L21 que contiene el único `stopifnot()` sobre `p_bonferroni >= p_value`.

**Reproducción mínima.** En una copia temporal reemplacé las dos llamadas de `p.adjust()` de `add_corrections()` por `res$p_value[valid]`. Ejecuté:

```r
testthat::test_file("tests/testthat/test-statistics.R")
testthat::test_file("tests/testthat/test-codex-regressions.R")
```

Ambos archivos terminaron con `DONE`, sin fallo. Por tanto, la afirmación de que los tests protegen Bonferroni/BH y el PheWAS completo no está probada por esos tests.

**Corrección propuesta.** Extraer `add_corrections()` y el flujo de L21 a funciones importables y probarlas directamente con una tabla de p conocida, incluidos `NA`. Añadir una prueba de integración que ejecute `run_phewas() |> add_corrections()` sobre datos simulados y confirme: número de hipótesis, valores ajustados idénticos a `p.adjust`, y que un cambio a p crudos falle.

#### A2. El filtro PheWAS de “3 eventos/no-eventos por celda” es una decisión no justificada y altera la familia de hipótesis a partir de los resultados

**Ficheros:** `lessons/L21_phewas_run.R:85-113`; `reviews/VALORACION_informe_codex.md`, sección 1; `CHECKLOG.md`, secciones 9 y 13; `../../content_es_m3.py:935, 947, 1010-1015`.

**Evidencia.** La regla exige `min(cells) >= 3`, es decir, al menos tres eventos y no eventos tanto en expuestos como no expuestos. No se aporta referencia, cálculo de potencia, simulación de sesgo/cobertura ni análisis de sensibilidad que justifique 3 frente a 1, 5, 10 o un método para datos escasos. El conjunto de pruebas que entra en Bonferroni se decide con la tabla observada de ADE, no sólo con un criterio fijado antes de mirar el desenlace. En la semilla distribuida, L21 pasó de 38 a 28 hipótesis en A y el umbral pasó de 0,0013 a 0,00179; lo reproduje al ejecutar L21 en una copia temporal.

Eso puede ser una decisión operativa razonable para no imprimir OR infinitos, pero no es una demostración de control del error familiar de la nueva regla. Excluir selectivamente fenotipos raros también sesga qué enfermedades llegan a ser “testeables”, precisamente un aspecto que la explicación didáctica debería hacer visible.

**Reproducción mínima.** Ejecutar `Rscript --vanilla lessons/L21_phewas_run.R`; imprime `Tests run in site A: 28 - Bonferroni threshold: 0.00179`. Cambiar `min_events` modifica tanto la selección como el denominador; no hay prueba de su efecto sobre FWER, potencia o cobertura.

**Corrección propuesta.** Fijar la familia de 40 fenotipos y su regla de inclusión antes del análisis (por ejemplo, prevalencia/exposición basada sólo en covariables o en una fase de diseño), informar todos los excluidos y mantener 40 —o la familia preespecificada— en Bonferroni. Para estratos escasos, enseñar penalización de Firth, exacta o intervalos de perfil como alternativas, no presentar 3 como regla de estimabilidad general. Añadir simulaciones sobre una rejilla de prevalencias que evalúen convergencia, sesgo, cobertura y FWER para cada política.

#### A3. L25 encubre una localización espacial inválida mediante una tolerancia de 100 m

**Ficheros:** `R/simulate_areas.R:10`; `lessons/L25_spatial_basics_sf.R:47-60`; `CHECKLOG.md:5.2`; `../../content_es_m4.py:114-175`.

**Evidencia.** La cuadrícula EPSG:27700 se crea entre (0, 0) y (14.000, 14.000), junto al falso origen y fuera de la zona para la que la transformación británica de precisión es apropiada. La propia lección admite que PROJ recurre a una aproximación. En mi ejecución el ida/vuelta produjo 72,8 m; la nueva aserción permite hasta 100 m. El mensaje pedagógico de la lección es que `st_transform()` conserva el lugar; aceptar una diferencia de decenas de metros para hacer pasar el ejemplo contradice esa garantía, aunque sea pequeña respecto de una celda de 1 km.

**Reproducción mínima.** En una copia temporal: `Rscript --vanilla lessons/L25_spatial_basics_sf.R`. Salida: `Largest round-trip shift (metres): 72.8`; la aserción pasa por ser menor que 100.

**Corrección propuesta.** Crear la cuadrícula cerca de un punto real dentro de Gran Bretaña (por ejemplo, alrededor de E/N 530000/180000), o emplear un CRS local ficticio apropiado y explicar que no debe transformarse como si fuera una localización real. Mantener una tolerancia de orden milimétrico/numérico si el ejemplo pretende probar conservación geométrica. Si se quiere enseñar la degradación de una conversión fuera de dominio, convertirlo en un caso explícitamente separado y esperado como fallo/advertencia.

### Media

#### M1. `ensure_sim_data()` no cumple su propia interfaz y su huella no demuestra frescura completa

**Fichero:** `R/helpers_general.R:62-81`; prueba `tests/testthat/test-codex-regressions.R:43-64`.

**Evidencia.** La función acepta `dir` y `seed`, pero, si necesita regenerar, siempre ejecuta `data-sim/00_generate_all.R`, que escribe en `data-sim/out` con semilla fija 2026. Por tanto, el argumento `dir` no funciona y `seed` no se usa. La prueba sólo usa el directorio por defecto y no detecta esto. Además, la huella cubre `R/simulate_*.R` y scripts de `data-sim`, pero no todos los ficheros R que `00_generate_all.R` carga; el comentario “a change in any of them” es más amplio que su implementación.

**Reproducción mínima.** En una copia temporal:

```r
source("R/helpers_general.R")
ensure_sim_data(dir = tempfile("custom-out-"), quiet = TRUE)
```

Se crea `data-sim/out`; el directorio solicitado no existe. Resultado observado: `exists_custom=FALSE exists_default=TRUE`.

**Corrección propuesta.** Hacer que el generador sea una función con argumentos `out` y `seed`, llamarla desde `ensure_sim_data()`, e incluir esos parámetros en un manifiesto JSON/texto con hashes, R, paquetes y CRS/PROJ. Alternativamente retirar los argumentos que no se soportan. Probar un directorio no predeterminado y una semilla distinta.

#### M2. La validación cuasi-Poisson está calibrada de forma demasiado laxa y deja autocorrelación espacial significativa

**Ficheros:** `lessons/L29_spatial_autocorrelation_regression.R:122-138`; `R/simulate_areas.R:22-24`; `tests/testthat/test-statistics.R:120-131`; `CHECKLOG.md:13`.

**Evidencia.** El test declara recuperación de 0,04 con tolerancia absoluta 0,25: aceptaría una media entre -0,21 y 0,29. En una copia, cambié el coeficiente generador de privación de 0,25 a 0,20; el test completo de estadística siguió pasando (la tolerancia de privación es 0,1). Es, por tanto, una comprobación de que el modelo devuelve números finitos y vagamente orientados, no de recuperación del valor plantado.

Al ejecutar L29, la salida de la nueva comparación fue I de Moran de residuos cuasi-Poisson = 0,0677, p = 0,0268. El GLM de recuentos no elimina la dependencia espacial; mostrarlo junto a SEM/SAR sin un modelo espacial de recuentos ni advertencia visible puede sugerir una solución que no da.

**Reproducción mínima.** Cambiar en una copia `0.25 * deprivation` por `0.20 * deprivation` en `R/simulate_areas.R` y ejecutar `test-statistics.R`: pasa. Ejecutar L29 sin cambios y leer `Quasi-Poisson residuals`.

**Corrección propuesta.** Justificar tolerancias a partir del error Monte Carlo esperado y usar bandas que rechacen cambios relevantes (por ejemplo, error absoluto pequeño predefinido con suficientes réplicas). Probar explícitamente que el coeficiente generador cambia la estimación. Explicar que el GLM es sólo referencia de distribución/offset; para inferencia espacial de recuentos, añadir un modelo apropiado o declarar y medir la autocorrelación residual como limitación en L29 y L30.

#### M3. La prueba de calibración de Bonferroni permite tres veces el error familiar afirmado

**Fichero:** `tests/testthat/test-statistics.R:18-33`; `CHECKLOG.md:4`.

**Evidencia.** El comentario afirma que Bonferroni deja la probabilidad de algún falso positivo “at or below about 5 %”, pero la expectativa es `mean(any_fp) <= 0.15`. Con 60 simulaciones, observar hasta 9 familias falsas sigue pasando. No se calcula un intervalo binomial ni se contrasta el 0,05 teórico. Además es otra simulación manual de `p.adjust`, no de la selección PheWAS ni de `add_corrections()`.

**Reproducción mínima.** Leer la expectativa anterior; no hay intervención del código de L21 en ese bloque.

**Corrección propuesta.** Separar una prueba determinista de implementación de una validación estocástica. Para la segunda, usar más réplicas, una semilla fijada, un intervalo de confianza o tolerancia preespecificada alrededor de 0,05, y simular el flujo real incluida la política de exclusión.

#### M4. La CI no prueba la ruta reproducible anunciada ni la compatibilidad que promete el README

**Ficheros:** `.github/workflows/check.yaml`; `README.md:12-16`; `install_packages.R:1-24`; `renv.lock`; `CHECKLOG.md:8, 12, 14`.

**Evidencia.** El workflow instala el R `release` y las últimas versiones disponibles mediante `install_packages.R`; no ejecuta `renv::restore()`, no prueba R 4.3 pese a que el README lo admite, ni macOS/Windows, ni una versión anterior de R. Por diseño, una pasada verde sólo prueba Linux y el estado de CRAN de ese día. Tampoco hay prueba de que el `renv.lock` se pueda restaurar en un clon limpio. La decisión de mantener ambos caminos sin CI de la ruta exacta deja sin evidencia la afirmación de reproducibilidad exacta.

El disparador `push` sólo cubre `main`; un push a otra rama sin pull request no se ejecuta. Quarto se renderiza, pero no se inspecciona visualmente ni se guarda un artefacto para revisión humana.

**Corrección propuesta.** Hacer una matriz mínima con R 4.3 y release, Linux y al menos macOS; añadir un trabajo de restauración `renv` desde cero o declarar inequívocamente que no es una ruta soportada. Fijar versiones de acciones y, si se mantiene la instalación “latest”, tratarla como prueba de compatibilidad separada. Publicar los HTML como artefactos y someterlos a revisión visual/semántica.

#### M5. La cobertura de IC, las verdades plantadas y el metaanálisis se validan en casos favorables, no en el caso que se enseña

**Ficheros:** `tests/testthat/test-statistics.R:1-67`; `lessons/L21_phewas_run.R:230-279`; `R/simulate_ehr.R:29-60`.

**Evidencia.** La cobertura (400 réplicas, 0,92--0,98) sólo cubre un GLM binario simple sin edad, sexo, filtro de celdas, selección de fenotipos ni rareza. El test de verdades plantadas usa 20.000 pacientes y su propio bucle GLM, cuando la lección distribuye 1.000 por centro y L21 deja PH05 sin recuperación. El metaanálisis se compara con una fórmula manual para dos errores estándar elegidos a mano y una tabla 2x2 aislada; no prueba el filtrado de `combined`, el ajuste múltiple agrupado, heterogeneidad o la decisión de modelo de efecto común. En los datos generados B tiene mezcla de prevalencias y edades distinta de A, por lo que la ausencia de heterogeneidad simulada/diagnosticada no se ha demostrado.

**Corrección propuesta.** Validar el pipeline real a n=1.000 y n=20.000, registrar sensibilidad/potencia/FWER/coverage por fenotipo y sitio, y justificar qué afirmación didáctica se espera en cada tamaño. Incluir pruebas de los filtros de metaanálisis, ajuste de sus p y comportamiento ante heterogeneidad conocida; mostrar una advertencia sobre el supuesto de efecto común.

### Baja

#### B1. La afirmación de “tests nuevos” se confunde con ejecución de scripts; la mayoría de lecciones no tiene prueba unitaria directa

**Ficheros:** `tests/testthat/`; `tests/run_all_lessons.R`; `CHECKLOG.md:3-4`.

**Evidencia.** Sólo hay referencias directas desde tests a L14, L21, L23, L28, L32 y L40. L02--L13 (salvo L14), L15--L20, L25--L27, L29--L31 y L34--L39 dependen principalmente de que el script complete con la semilla actual. Eso detecta errores de ejecución, no resultados invertidos, gráficos equivocados, interpretaciones erróneas ni regresiones en rutas alternativas.

**Corrección propuesta.** Convertir los cálculos sustantivos de cada módulo en funciones pequeñas y probar invariantes/resultados conocidos. Mantener el runner de scripts como smoke test, pero no contabilizarlo como validación estadística.

#### B2. La mutación comunicada para `tidy_or()` no basta para sostener todas las afirmaciones sobre IC

**Ficheros:** `R/helpers_general.R:30-40`; `tests/testthat/test-helpers.R:26-39`; `CHECKLOG.md:4`.

**Evidencia.** La mutación de 1,96 a 1,64 sí debe fallar las comprobaciones de `tidy_or`, pero no cubre intervalos en separación, covariables, estimadores penalizados o la interpretación de IC de modelos espaciales. El informe extrapola demasiado de esta mutación puntual a “95 percent interval coverage”.

**Corrección propuesta.** Delimitar la afirmación a IC Wald de un GLM regular y añadir escenarios difíciles, o enseñar explícitamente que esos IC no son una garantía bajo separación/escasez.

## Decisiones previas cuestionadas

- **Aceptar la regla PheWAS:** aceptar que no se impriman estimaciones infinitas era correcto, pero aceptar el corte de 3 como solución estadística completa no lo era. Falta preespecificación, sensibilidad y una política de multiplicidad que no se adapte al desenlace observado.
- **Diferir el modelo de recuentos y después añadir cuasi-Poisson:** añadirlo mejoró el material, pero la decisión sigue incompleta. La ejecución muestra autocorrelación residual significativa y L30 conserva las conclusiones de modelos log-rate/SEM/SAR; no se debe presentar la comparación como validación del modelo espacial de recuentos.
- **Aceptar la huella de datos obsoletos:** mejora el caso habitual, pero sin respetar `dir`/`seed` y sin manifiesto completo no satisface la interfaz ni prueba una regeneración reproducible general.
- **Relajar L25 a 100 m:** es una solución de disponibilidad de PROJ, no de diseño del dato espacial; normaliza una transformación inexacta justo en la lección que enseña a no desplazar datos.
- **Mantener paquetes sin fijar:** puede ser una política deliberada de compatibilidad, pero no puede simultáneamente respaldar la promesa de resultados reproducibles. Deben distinguirse “compatible con CRAN actual” y “reproduce la versión verificada”, y probar ambos.

## Afirmaciones que no pude reproducir o que quedaron sin evidencia reproducible

1. Que los nuevos tests detectan la retirada de Bonferroni/BH de L21: la mutación descrita en A1 pasó todas las pruebas relevantes.
2. Que el test cuasi-Poisson “recupera” los valores plantados: sus tolerancias aceptan cambios sustanciales, como el 0,25 a 0,20 reproducido en A2/M2.
3. Que Bonferroni mantiene el FWER “en torno al 5 %”: el test permite 15 % y no ejecuta el pipeline PheWAS.
4. Que el filtro de tres eventos/no-eventos está validado o es el umbral apropiado: no hallé justificación ni simulación para ello.
5. Que la ruta `renv::restore()` reproduce las versiones verificadas en un clon limpio: no está ejercitada por la CI ni por los tests locales revisados.
6. Que la ejecución CI concreta indicada en CHECKLOG (incluidos 123 expectations y los HTML) prueba la calidad visual de ambos informes: no hubo artefacto ni revisión visual disponible en esta revisión.
7. Que “todas las rutas son relativas” y que nada escribe fuera del proyecto: los scripts se ejecutan desde raíz y crean `output/`; no se sometieron a prueba directorios de trabajo alternativos. El bug de `ensure_sim_data(dir=...)` demuestra que esa generalización es frágil.

## Lo que no se verificó

- Aspecto visual, enlaces, accesibilidad, contenido y estabilidad entre versiones de los HTML Quarto; que existan archivos HTML no valida el informe que prometen L34/L35.
- Restauración real de `renv.lock`, instalación desde una máquina sin paquetes, R 4.3, Windows, macOS limpio y cambios futuros de CRAN/PROJ/GDAL.
- Las afirmaciones didácticas de la mayoría de las 35 lecciones, soluciones, ejercicios, gráficos y salidas: no tienen test unitario directo. El runner sólo confirma que la semilla y el entorno actual no abortan.
- Las promesas de contenido fuera de este repositorio (diapositivas, notas, cuestionarios y vídeos). Se leyeron las fuentes `content_es.py`, `content_en.py` y los módulos pertinentes sólo para cotejar L14, L21, L25, L29 y Quarto; no se renderizaron diapositivas ni se validaron los cuestionarios, enlaces o fuentes bibliográficas.
- Validez externa: los datos son simulados y las verdades plantadas sólo confirman que el generador y el estimador coinciden bajo supuestos favorables; no validan PheWAS, privacidad, equidad, OMOP, modelos espaciales ni predicción sobre datos clínicos reales.
- Riesgos de seguridad, licencias de dependencias/datos, compatibilidad de paquetes opcionales (incluido PITS), rendimiento/memoria con tamaños realistas y tratamiento de errores/interrupciones durante la regeneración.

## Comprobaciones efectuadas

Se comparó el primer commit (`3883260`) con `HEAD`, se leyeron íntegramente `CHECKLOG.md` y `reviews/VALORACION_informe_codex.md`, y se trabajó en copias temporales. Reproducciones positivas relevantes: los 92 R parsean; L21 imprime 28 pruebas y umbral 0,00179; L25 imprime 72,8 m; L29 imprime la autocorrelación residual cuasi-Poisson indicada arriba. No se modificó ningún fichero del repositorio aparte de este informe.
