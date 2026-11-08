# Final project checklist / Lista de comprobación del proyecto final

CESGEN · reviewed 08/11/2026 · Educational material; it does not replace a health professional.
Tick each item `[x]` or write why it does not apply. / Marca cada punto `[x]` o escribe por qué no aplica.

## Data source and licence / Fuente de datos y licencia

- [ ] The dataset id (D1-D7) and the files used are named in the report. / El identificador (D1-D7) y los archivos usados constan en el informe.
- [ ] The report states that the data are simulated and says how they were generated (script and seed). / El informe indica que los datos son simulados y cómo se generaron (script y semilla).
- [ ] Every table and figure carries the label "Simulated data for teaching purposes". / Cada tabla y figura lleva el rótulo «Datos simulados con fin didáctico».
- [ ] Any real public resource mentioned is marked "check access and licence before use" and is not used in the analysis. / Todo recurso público real mencionado lleva «comprobar acceso y licencia antes de usarlo» y no se usa en el análisis.

## Privacy / Privacidad

- [ ] No real patient data and no real person's genome were used or uploaded anywhere. / No se usaron ni subieron datos de pacientes reales ni el genoma de ninguna persona real.
- [ ] I listed the columns that would identify someone if the data were real (direct and quasi-identifiers). / Listé las columnas que identificarían a alguien si los datos fueran reales (identificadores directos y cuasi-identificadores).
- [ ] For any table I would share, I computed k with `k_anonymity()` and I did not publish small cells. / En toda tabla que compartiría calculé k con `k_anonymity()` y no publiqué celdas pequeñas.
- [ ] The report does not depend on the `*_truth.csv` files. / El informe no depende de los archivos `*_truth.csv`.

## Equity and bias / Equidad y sesgo

- [ ] I showed who is in the data (share by group) and who is missing. / Mostré quién está en los datos (proporción por grupo) y quién falta.
- [ ] I considered how each variable was measured and whether that could differ by group. / Consideré cómo se midió cada variable y si podría diferir por grupo.
- [ ] Results by group include the sample size, the number of events and an interval. / Los resultados por grupo incluyen tamaño de muestra, número de eventos e intervalo.
- [ ] I state what the audit cannot show (small groups, unmeasured differences). / Indico lo que la auditoría no puede mostrar (grupos pequeños, diferencias no medidas).

## Analytical integrity / Integridad del análisis

- [ ] The question was written before looking at the results (no HARKing). / La pregunta se escribió antes de mirar los resultados (sin HARKing).
- [ ] Data were split before selecting variables or tuning anything; the evaluation part was used once. / Los datos se dividieron antes de seleccionar variables o ajustar nada; la parte de evaluación se usó una vez.
- [ ] I report how many analyses I ran and corrected for multiple comparisons where needed. / Indico cuántos análisis hice y corregí las comparaciones múltiples cuando hacía falta.
- [ ] I show the results that did not support my expectation, not only the ones that did. / Muestro también los resultados que no respaldaron lo esperado.

## Reproducibility / Reproducibilidad

- [ ] The report renders in one step from a clean R session, from the project folder. / El informe se genera en un paso desde una sesión limpia de R, desde la carpeta del proyecto.
- [ ] Paths are relative; a seed is set; there are no results pasted by hand. / Las rutas son relativas; hay semilla; no hay resultados pegados a mano.
- [ ] The report ends with `sessionInfo()`. / El informe termina con `sessionInfo()`.
- [ ] Conclusions say "associated with", not "causes", and they are not presented as clinical advice. / Las conclusiones dicen «se asocia con», no «causa», y no se presentan como consejo clínico.
