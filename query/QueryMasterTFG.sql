------- QUERY MAESTRA TFG --------
WITH LabPivot AS (
    SELECT
        lo.IdPaciente,
        lr.FechaMuestra,
        MAX(CASE WHEN lr.codigoPrueba = 'CREA' THEN TRY_CAST(lr.resultado AS FLOAT) END) AS Creatinina_mg_dL,
        MAX(CASE WHEN lr.codigoPrueba = 'U'    THEN TRY_CAST(lr.resultado AS FLOAT) END) AS Urea_mg_dL,
        MAX(CASE WHEN lr.codigoPrueba = 'K'    THEN TRY_CAST(lr.resultado AS FLOAT) END) AS Potasio_mmol_L,
        MAX(CASE WHEN lr.codigoPrueba = 'NA'   THEN TRY_CAST(lr.resultado AS FLOAT) END) AS Sodio_mmol_L
    FROM Laboratorio_Orden lo
    INNER JOIN LaboratorioResultados_lab lr
        ON lo.Muestra = lr.numMuestra
    WHERE lr.codigoPrueba IN ('CREA', 'U', 'K', 'NA')
      AND lr.FechaMuestra IS NOT NULL
      AND TRY_CAST(lr.resultado AS FLOAT) IS NOT NULL
    GROUP BY
        lo.IdPaciente,
        lr.FechaMuestra
),

BaseIngresos AS (
    SELECT
        I.IdIngreso,
        I.IdPaciente,
        P.UUIdPaciente,
        P.Sexo,
        DATEDIFF(YEAR, P.FechaNac, I.FechaIngreso) AS EdadAproxIngreso,
        I.FechaIngreso,
        I.FechaAlta,
        I.IdHospital,
        I.IdSociedad,
        I.IdDoctor
    FROM Ingresos I
    INNER JOIN Pacientes P
        ON I.IdPaciente = P.IdPaciente
    WHERE I.FechaIngreso IS NOT NULL
      AND P.UUIdPaciente IS NOT NULL
      AND I.FechaIngreso >= '2024-01-01'
),

IngresosConLab AS (
    SELECT DISTINCT
        B.IdIngreso
    FROM BaseIngresos B
    INNER JOIN LabPivot L
        ON B.IdPaciente = L.IdPaciente
       AND L.FechaMuestra >= B.FechaIngreso
       AND (
            B.FechaAlta IS NULL
            OR L.FechaMuestra <= B.FechaAlta
       )
),

Cohorte AS (
    SELECT
        B.*
    FROM BaseIngresos B
    INNER JOIN IngresosConLab C
        ON B.IdIngreso = C.IdIngreso
),

PrimerLab AS (
    SELECT
        x.IdIngreso,
        x.FechaMuestra AS PrimeraFechaLab,
        x.Creatinina_mg_dL,
        x.Urea_mg_dL,
        x.Potasio_mmol_L,
        x.Sodio_mmol_L
    FROM (
        SELECT
            C.IdIngreso,
            L.FechaMuestra,
            L.Creatinina_mg_dL,
            L.Urea_mg_dL,
            L.Potasio_mmol_L,
            L.Sodio_mmol_L,
            ROW_NUMBER() OVER (
                PARTITION BY C.IdIngreso
                ORDER BY L.FechaMuestra
            ) AS rn
        FROM Cohorte C
        INNER JOIN LabPivot L
            ON C.IdPaciente = L.IdPaciente
           AND L.FechaMuestra >= C.FechaIngreso
           AND (
                C.FechaAlta IS NULL
                OR L.FechaMuestra <= C.FechaAlta
           )
    ) x
    WHERE x.rn = 1
),

CreatininaIngreso AS (
    SELECT
        C.IdIngreso,
        C.IdPaciente,
        C.FechaIngreso,
        C.FechaAlta,
        lr.FechaMuestra,
        TRY_CAST(lr.resultado AS FLOAT) AS Creatinina_mg_dL
    FROM Cohorte C
    INNER JOIN Laboratorio_Orden lo
        ON C.IdPaciente = lo.IdPaciente
    INNER JOIN LaboratorioResultados_lab lr
        ON lo.Muestra = lr.numMuestra
    WHERE lr.codigoPrueba = 'CREA'
      AND lr.FechaMuestra IS NOT NULL
      AND TRY_CAST(lr.resultado AS FLOAT) IS NOT NULL
      AND lr.FechaMuestra >= C.FechaIngreso
      AND (
            C.FechaAlta IS NULL
            OR lr.FechaMuestra <= C.FechaAlta
      )
),

PrimeraCreatinina AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY IdIngreso
            ORDER BY FechaMuestra
        ) AS rn
    FROM CreatininaIngreso
),

Baseline AS (
    SELECT
        IdIngreso,
        IdPaciente,
        FechaIngreso,
        FechaAlta,
        FechaMuestra AS BaselineFecha,
        Creatinina_mg_dL AS BaselineCreatinina
    FROM PrimeraCreatinina
    WHERE rn = 1
),

AKI48h AS (
    SELECT
        b.IdIngreso,
        b.BaselineFecha,
        b.BaselineCreatinina,
        MAX(c.Creatinina_mg_dL) AS MaxCreatinina48h
    FROM Baseline b
    LEFT JOIN CreatininaIngreso c
        ON b.IdIngreso = c.IdIngreso
       AND c.FechaMuestra > b.BaselineFecha
       AND c.FechaMuestra <= DATEADD(HOUR, 48, b.BaselineFecha)
    GROUP BY
        b.IdIngreso,
        b.BaselineFecha,
        b.BaselineCreatinina
),

Medicacion AS (
    SELECT
        I.IdIngreso,

        MAX(CASE 
            WHEN E3.Name LIKE '%IBUPROFENO%'
              OR E3.Name LIKE '%DEXKETOPROFENO%'
              OR E3.Name LIKE '%DICLOFENACO%'
              OR E3.Name LIKE '%NAPROXENO%'
              OR E3.Name LIKE '%KETOROLACO%'
            THEN 1 ELSE 0
        END) AS AINE,

        MAX(CASE 
            WHEN E3.Name LIKE '%ENALAPRIL%'
              OR E3.Name LIKE '%LISINOPRIL%'
              OR E3.Name LIKE '%RAMIPRIL%'
              OR E3.Name LIKE '%CAPTOPRIL%'
            THEN 1 ELSE 0
        END) AS IECA,

        MAX(CASE 
            WHEN E3.Name LIKE '%LOSARTAN%'
              OR E3.Name LIKE '%VALSARTAN%'
              OR E3.Name LIKE '%CANDESARTAN%'
              OR E3.Name LIKE '%IRBESARTAN%'
            THEN 1 ELSE 0
        END) AS ARAII,

        MAX(CASE 
            WHEN E3.Name LIKE '%FUROSEMIDA%'
              OR E3.Name LIKE '%TORASEMIDA%'
              OR E3.Name LIKE '%HIDROCLOROTIAZIDA%'
              OR E3.Name LIKE '%ESPIRONOLACTONA%'
            THEN 1 ELSE 0
        END) AS DIURETICO,

        MAX(CASE 
            WHEN E3.Name LIKE '%VANCOMICINA%'
            THEN 1 ELSE 0
        END) AS VANCOMICINA,

        MAX(CASE 
            WHEN E3.Name LIKE '%GENTAMICINA%'
              OR E3.Name LIKE '%AMIKACINA%'
              OR E3.Name LIKE '%TOBRAMICINA%'
            THEN 1 ELSE 0
        END) AS AMINOGLUCOSIDO

    FROM TratamientoFarm T
    INNER JOIN Ingresos I
        ON T.IdEpisodio = I.IdIngreso
       AND T.Tipo = 'I'
    INNER JOIN eo_drugs_comercial_drugs E2
        ON T.IdPaEo = E2.drug_comercial_drug_id
    INNER JOIN eo_drugs E3
        ON E2.drug_id = E3.drug_id
    GROUP BY
        I.IdIngreso
)

SELECT
    C.IdIngreso,
    C.UUIdPaciente,
    C.Sexo,
    C.EdadAproxIngreso,
    C.FechaIngreso,
    C.FechaAlta,
    C.IdHospital,
    C.IdSociedad,
    C.IdDoctor,

    PL.PrimeraFechaLab,
    PL.Creatinina_mg_dL,
    PL.Urea_mg_dL,
    PL.Potasio_mmol_L,
    PL.Sodio_mmol_L,

    A.BaselineFecha,
    A.BaselineCreatinina,
    A.MaxCreatinina48h,
    CASE
        WHEN A.MaxCreatinina48h IS NOT NULL
         AND A.MaxCreatinina48h >= A.BaselineCreatinina + 0.3
        THEN 1
        ELSE 0
    END AS AKI_48h,

    COALESCE(M.AINE, 0) AS AINE,
    COALESCE(M.IECA, 0) AS IECA,
    COALESCE(M.ARAII, 0) AS ARAII,
    COALESCE(M.DIURETICO, 0) AS DIURETICO,
    COALESCE(M.VANCOMICINA, 0) AS VANCOMICINA,
    COALESCE(M.AMINOGLUCOSIDO, 0) AS AMINOGLUCOSIDO

FROM Cohorte C
LEFT JOIN PrimerLab PL
    ON C.IdIngreso = PL.IdIngreso
LEFT JOIN AKI48h A
    ON C.IdIngreso = A.IdIngreso
LEFT JOIN Medicacion M
    ON C.IdIngreso = M.IdIngreso
ORDER BY
    C.FechaIngreso,
    C.IdIngreso;