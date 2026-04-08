Mi TFG trata sobre la **predicción temprana de lesión renal aguda (AKI)** usando **datos clínicos hospitalarios reales**. La idea principal fue comprobar si, a partir de variables estructuradas que ya existen en un hospital, como edad, sexo, creatinina, sodio, potasio y ciertos fármacos, se podía construir un modelo de inteligencia artificial capaz de detectar qué ingresos tenían más riesgo de desarrollar AKI en las siguientes 48 horas.

Lo que hice fue, primero, trabajar con la base de datos clínica **Doctoris** en **SQL Server** para construir una cohorte de estudio. A partir de ahí definí una variable objetivo binaria: si el paciente desarrollaba o no AKI en 48 horas según el aumento de creatinina respecto al valor basal. Luego exporté esos datos, limpié el dataset en Python, resolví problemas de importación y formato, seleccioné las variables útiles y preparé un dataset final con una fila por ingreso hospitalario.

Después entrené dos modelos baseline: una **regresión logística** y un **Random Forest**. Los comparé porque quería ver un modelo más interpretable frente a uno más flexible. Los evalué con métricas adecuadas para datasets desbalanceados, porque había muy pocos casos positivos de AKI. El resultado principal fue que sí había **señal predictiva útil**, aunque el problema era difícil por el tamaño y el desbalanceo de la cohorte.

A nivel de hallazgos, la **creatinina basal** fue la variable más importante y consistente en ambos modelos. También aparecieron como relevantes la **edad** y la **carga farmacológica**. La regresión logística fue más sensible para detectar positivos bajo configuración estándar, mientras que el Random Forest tuvo mejor capacidad global de discriminación, pero necesitó revisar el umbral de clasificación para ser útil.

Y al final hice una **demo práctica** del sistema con casos clínicos simulados. La idea no era hacer una app clínica real, sino demostrar que el pipeline completo funcionaba: tú introduces un perfil clínico estructurado y el modelo devuelve una **probabilidad de riesgo** de desarrollar AKI. Esa demo me sirvió para mostrar de forma muy clara cómo se traducía todo el trabajo técnico en una predicción individual.

La conclusión general es que **sí es viable construir una prueba de concepto de predicción temprana de AKI con datos hospitalarios estructurados**, pero todavía **no está listo para producción clínica**. Haría falta más muestra, más casos positivos, validación externa y una optimización más profunda del modelo. Si quieres, te preparo también una versión de **1 minuto hablada**, como para decírselo directamente.

============================================================================================================================================

La regresión logística es un modelo lineal y más simple e interpretable. Lo que hace es calcular cómo cada variable empuja la predicción hacia mayor o menor probabilidad del evento, en este caso AKI. Sirve muy bien como baseline porque se entiende fácil y permite ver el peso de cada predictor.

El Random Forest es un modelo no lineal basado en muchos árboles de decisión. En lugar de buscar una relación lineal entre variables y resultado, combina muchas reglas y particiones de los datos. Eso le permite captar patrones más complejos, pero a cambio es menos transparente que la regresión logística.

En mi trabajo, la diferencia principal fue esta:

La regresión logística detectó mejor los casos positivos con la configuración estándar. O sea, tuvo mejor recall y fue más útil como modelo sensible, aunque generó muchos falsos positivos.
El Random Forest tuvo mejor ROC-AUC, es decir, mejor capacidad global para distinguir entre pacientes de mayor y menor riesgo. Pero con el umbral estándar de 0,5 no detectó ningún positivo, así que parecía peor en clasificación binaria directa.

Entonces, dicho sencillo:

la regresión logística fue más útil para detectar,
el Random Forest fue mejor para ordenar riesgo,
pero al Random Forest hubo que ajustarle el umbral para que empezara a servir en la práctica.
