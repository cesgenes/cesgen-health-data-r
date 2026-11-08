# Revisión independiente del repositorio `cesgen-health-data-r`

Fecha de revisión: 8 de noviembre de 2026.  Alcance: revisión de solo lectura del código, plantillas, pruebas, `CHECKLOG.md` y contenidos en inglés del curso. Las ejecuciones se hicieron en una copia temporal, con R 4.6.1; no se modificó ningún archivo del repositorio salvo este informe.

## Resumen ejecutivo

El repositorio está razonablemente estructurado para docencia: los 90 ficheros R inspeccionados se analizaron sintácticamente sin errores, los datos son simulados, las advertencias de privacidad son consistentes y no encontré secretos ni datos de personas reales versionados. Las seis variantes ancla, los códigos ICD usados como ICD-10 y las advertencias de que OMOP y los conceptos son simplificados están documentados con bastante cuidado.

No obstante, hay un fallo reproducible en el motor PheWAS ante celdas escasas o separadas: oculta las advertencias y puede publicar una OR infinita o prácticamente cero. Además, los ejemplos espaciales ajustan tasas de recuento con regresión lineal no ponderada, sin un *offset* de población, de modo que los intervalos y las razones de tasa que enseñan no corresponden al proceso generador Poisson. Finalmente, faltan CI y una política robusta para invalidar datos simulados ya generados. No encontré discrepancias numéricas inequívocas entre los resultados que ejecuté y las diapositivas/notas/tareas en inglés.

## Hallazgos

### Alto — PheWAS: las celdas cero y la separación se silencian en vez de excluirse o tratarse

**Ubicación:** `lessons/L21_phewas_run.R`, líneas 82–97, en especial 87–93; también afecta a la solución y a cualquier reutilización de `run_phewas()`.

**Problema.** El filtro solo exige `n_exposed >= min_exposed`; no exige eventos y no eventos en los dos grupos, ni comprueba convergencia. A continuación envuelve `glm()` en `suppressWarnings()`. En datos escasos, una separación completa produce estimaciones e intervalos degenerados sin aviso. El propio bloque de metaanálisis posterior sí reconoce que los ceros vuelven un fenotipo «no usable», pero esa protección no se aplica al análisis por centro que se enseña y exporta.

**Evidencia / reproducción mínima.** En la copia temporal, después de cargar el script, ejecuté:

```r
d <- data.frame(
  ade = c(rep(0, 10), rep(c(0, 1), 15)),
  age = rep(40:59, 2), sex = rep(c("F", "M"), 20),
  PHX = c(rep(1, 10), rep(0, 30))
)
run_phewas(d, "PHX", min_exposed = 10)
```

La única fila devuelta fue `or = 6.03e-23`, `lower = 0`, `upper = Inf`, `p_value = 0.9996575`, aunque hay diez expuestos y ninguno tuvo el evento. No hubo advertencia por la supresión global. Una covariable constante hace además que `glm()` aborte el barrido entero en vez de marcar ese fenotipo como no estimable.

**Corrección propuesta.** Antes de ajustar, construir la tabla 2×2 y requerir un número mínimo predefinido de eventos y no eventos en expuestos y no expuestos; devolver `NA` junto con el motivo de exclusión. No suprimir advertencias sin registrarlas, comprobar `fit$converged` y coeficientes/errores estándar finitos. Para la lección, explicar la corrección de continuidad como demostración separada y no como sustituto de una regla de exclusión; si se desea estimar datos escasos, usar un método penalizado o exacto y decirlo explícitamente. Añadir una prueba de regresión con la reproducción anterior.

### Medio — Los modelos espaciales no respetan que el desenlace simulado es un recuento Poisson con denominador variable

**Ubicación:** generación en `R/simulate_areas.R`, líneas 21–23; análisis en `lessons/L29_spatial_autocorrelation_regression.R`, líneas 27–29 y 79–119, y `lessons/L30_integrated_case.R`, líneas 30–31 y 63–87; explicación asociada en `content_en_m4.py`.

**Problema.** La simulación genera `cases` como Poisson con media `population / 1000 * rate`, y las poblaciones varían entre 800 y 4.000. Las lecciones transforman la tasa suavizada como `log((cases + 0.5) / population * 1000)` y la modelan con `lm`, `errorsarlm` y `lagsarlm` sin ponderación ni *offset*. Esto trata tasas con precisiones muy diferentes como observaciones de igual varianza y presenta intervalos de Wald como si fueran intervalos válidos de razones de tasa.

**Evidencia.** El proceso generador está explícito en las líneas citadas (`rpois(n, population / 1000 * rate)`), mientras que `lm(log_rate ~ pm25 + deprivation)` es el modelo que alimenta las tablas y conclusiones. La discrepancia no depende de una semilla concreta.

**Corrección propuesta.** Para el efecto principal, enseñar un GLM de recuentos, por ejemplo `glm(cases ~ pm25 + deprivation + offset(log(population)), family = quasipoisson)` (o binomial/Poisson negativo según el desenlace y la sobredispersión), y extraer de él las razones de tasa. Si se mantienen SEM/SAR como introducción a dependencia espacial, etiquetarlos como aproximación exploratoria de una tasa transformada y no presentar sus intervalos como inferencia del proceso Poisson; idealmente añadir un modelo espacial de recuento apropiado o una nota de limitación visible.

### Medio — No hay integración continua para las comprobaciones que se afirman reproducibles

**Ubicación:** raíz del repositorio; `.gitignore`; `tests/run_all_lessons.R`; `tests/testthat/`.

**Problema.** No existe `.github/workflows/` ni otro fichero de CI versionado. Las pruebas y el ejecutor de las 70 lecciones existen, pero solo se ejecutan manualmente. Un cambio que rompa una dependencia, una lección o las plantillas puede llegar al repositorio sin que la batería se ejecute en una plataforma limpia.

**Evidencia.** `git ls-files .github '.github/*'` no devolvió ningún fichero y solo existe `.gitignore` en la raíz. El PITS local que se usa como caso de estudio sí contiene `.github/workflows/R-CMD-check.yaml`, por lo que la comparación didáctica deja patente la ausencia.

**Corrección propuesta.** Añadir una GitHub Action que restaure `renv`, ejecute `Rscript data-sim/00_generate_all.R`, `Rscript tests/run_all_lessons.R` y `testthat::test_dir("tests/testthat")`; fijar al menos una versión de R compatible con el curso. Dejar el renderizado Quarto en un trabajo separado si el tiempo lo exige, pero no omitirlo de manera indefinida.

### Medio — `ensure_sim_data()` admite conjuntos obsoletos después de cambiar un generador

**Ubicación:** `R/helpers_general.R`, líneas 61–68; documentado también como incidencia abierta en `CHECKLOG.md`, sección 7.2.

**Problema.** Solo se comprueba la existencia de `patients_clean.csv`. Si se modifica un generador de genotipos, EHR o áreas, una mezcla de productos viejos y código nuevo se considera válida. Esto ya ocurrió, según el propio registro, al corregir la posición de rs1805007.

**Evidencia.** Basta con que exista ese único marcador para que la función no regenere ninguno de los demás ficheros. No hay versión de esquema, manifiesto ni huella de los generadores.

**Corrección propuesta.** Escribir y validar un manifiesto de datos (versión, semilla, lista de productos y quizá hash del código generador), o exigir una regeneración explícita y atómica de `data-sim/out/` cuando cambie la versión. Probar que quitar o desactualizar cualquiera de los productos fuerza una generación coherente.

### Bajo — `.gitignore` contiene una entrada duplicada

**Ubicación:** `.gitignore`, líneas 8–11.

**Problema y evidencia.** `renv/library/` aparece dos veces (líneas 9 y 11). No cambia el comportamiento, pero es ruido en un fichero que forma parte de la enseñanza de reproducibilidad.

**Corrección propuesta.** Conservar una sola entrada y añadir, junto a ella, una breve explicación de qué partes de `renv` se versionan (`renv.lock`) y cuáles no.

## Hallazgos transversales

- La revisión estática de los 90 ficheros R de `R/`, `data-sim/`, lecciones, soluciones, plantillas y pruebas no encontró errores de análisis sintáctico.
- Ejecuté L13, L14, L20 y L21 en una copia temporal. Las salidas observadas concuerdan con las expectativas cualitativas del material: conversión OR-riesgo, AUC lejos de 1, peor precisión en el grupo pequeño y control de falsos positivos con Bonferroni/BH. La discrepancia del PheWAS descrita arriba aparece al probar una entrada válida pero escasa, no con los datos semilla distribuidos.
- La salida de L14 con la semilla publicada muestra intervalos mucho más anchos para G3 y una R² de rasgo inferior a la de G1; no hallé contradicción inequívoca con el «puede/normalmente» de las notas.
- Las advertencias de privacidad son sólidas: no se detectaron secretos en texto versionado, los productos simulados están ignorados y las plantillas prohíben datos reales, genomas reales, credenciales y envíos a servicios externos. Los ejemplos de MIMIC, ClinVar, gnomAD, GWAS Catalog y Eunomia se presentan como fuentes que requieren revisar acceso y licencia, no como ficheros para subir a un asistente.
- No se detectaron rutas por defecto al directorio personal ni escrituras fuera del proyecto en las lecciones revisadas. Las escrituras ordinarias se dirigen a `output/`, que está ignorado.
- La cobertura no equivale a una prueba de integración completa: las pruebas sí cubren generadores, calibración nula, cobertura, metaanálisis, Moran, doble *dipping* y L40; pero no ejecutan automáticamente desde CI todas las lecciones ni el render Quarto. `CHECKLOG.md` declara que Quarto no estaba instalado y que el render quedó omitido.
- El paquete docente `riskkit` se documentó y sus pruebas `testthat` pasaron en una copia temporal. La comprobación completa no se pudo cerrar independientemente en esta sesión: `R CMD check` sobre directorios fuente, tanto en `riskkit` como en la copia local de PITS, falló inmediatamente en R 4.6.1 alegando `Author`/`Maintainer` pese a `Authors@R`; el intento de `devtools::check()` excedió el límite de 30 s de la sesión. Por ello no trato ese mensaje como defecto específico de `riskkit`, pero tampoco pude confirmar de forma independiente la afirmación de `CHECKLOG.md` de «0 errores, 0 advertencias, 0 notas». Debe repetirse `devtools::check()` en una sesión sin ese límite y conservar el log.

## Contraste factual y con el curso

- La copia local de PITS concuerda con los principales hechos usados en L36–L39: versión 0.1.1, licencia MIT, 22 exportaciones, tres métodos S3, 47 bloques `test_that`, tres viñetas, CI para macOS/Windows/Ubuntu (devel/release/oldrel-1) y exigencia de directorio explícito al escribir resultados. `cran-comments.md` declara 0 errores, 0 advertencias y una nota esperada para el envío nuevo. No hallé contradicción en esos puntos.
- La búsqueda en fuentes oficiales de NCBI corroboró la posición GRCh37 de rs1801133 (1:11856378) y la de rs429358 (19:45411941); el segundo ejemplo coincide además con la documentación de Variation Viewer. Las tablas y comentarios dejan claro que los alelos son de hebra directa y que los códigos ICD-9 simulados son marcadores inventados, no ICD-9 reales. También se explica que los conceptos OMOP son inventados y que el modelo no es el CDM completo.
- No encontré una discrepancia numérica o textual demostrable entre las diapositivas/notas/tareas en inglés consultadas y lo que imprimen L13, L14, L20 o L21. Sí debe corregirse o matizarse cualquier afirmación futura de que el PheWAS es seguro ante datos escasos hasta resolver el hallazgo alto.

## Lista priorizada de correcciones propuestas

1. Hacer que `run_phewas()` clasifique y reporte los estratos no estimables; no silenciar separación ni falta de convergencia, y probarlo.
2. Sustituir o delimitar con claridad la regresión lineal de tasas por modelos de recuentos con denominador/*offset*; actualizar las conclusiones e intervalos de L29/L30.
3. Añadir CI con restauración `renv` y pruebas/lecciones completas; añadir render Quarto en un trabajo adecuado.
4. Versionar los datos simulados mediante manifiesto y regeneración atómica.
5. Ejecutar y archivar un `devtools::check()` completo de `riskkit` en un entorno sin el límite de esta revisión.
6. Eliminar la entrada duplicada de `.gitignore`.

## Lo que no pude verificar

- No se renderizaron `templates/report_template.qmd` ni `templates/final_project/report_skeleton.qmd`: el ejecutable Quarto no estaba disponible, tal como también registra `CHECKLOG.md`.
- No se completó de modo independiente `devtools::check()` de `riskkit` por el límite de duración de la sesión; véase el detalle transversal. Sí se ejecutaron `devtools::document()` y `devtools::test()` en la copia temporal.
- No comprobé individualmente en línea las seis coordenadas/alelos de las variantes ancla ni el estado actual en CRAN/GWAS Catalog/ClinVar/ACMG; solo contrasté de forma directa las dos variantes indicadas y usé la copia local de PITS para las afirmaciones sobre PITS. Las demás deben verificarse de nuevo contra sus fuentes primarias fechadas antes de cualquier publicación clínica o actualización del curso.
- No audité el historial completo de Git ni servicios remotos, ni evalué cumplimiento jurídico o regulatorio. Esta revisión técnica no constituye asesoramiento médico, legal ni de protección de datos.
