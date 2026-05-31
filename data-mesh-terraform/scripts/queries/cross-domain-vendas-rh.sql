-- Cross-domínio: Vendas (vendas_db) × RH (rh_db)
-- Athena engine version 3 | Workgroup: wg-analytics
--
-- Schema (Glue Catalog + Parquet refined):
--   vendas_por_categoria: product_category_name, total_receita, qtd_itens (partições ano, mes)
--   funcionarios: departamento, satisfacao, employee_id (sem faixa_salarial via LF)

WITH mapa_departamento_categoria AS (
    SELECT departamento, categoria FROM (
        VALUES
            ('Sales', 'perfumaria'),
            ('Sales', 'health_beauty'),
            ('Sales', 'bed_bath_table'),
            ('Sales', 'furniture_decor'),
            ('Sales', 'sports_leisure'),
            ('Sales', 'cool_stuff'),
            ('Research & Development', 'informatica_acessorios'),
            ('Research & Development', 'telefonia'),
            ('Human Resources', 'housewares'),
            ('Human Resources', 'garden_tools'),
            ('Human Resources', 'pet_shop'),
            ('Human Resources', 'office_furniture')
    ) AS t(departamento, categoria)
),

vendas_por_departamento AS (
    SELECT
        m.departamento,
        v.product_category_name AS categoria,
        SUM(v.total_receita) AS total_receita,
        SUM(v.qtd_itens)     AS qtd_itens
    FROM vendas_db.vendas_por_categoria v
    INNER JOIN mapa_departamento_categoria m
        ON v.product_category_name = m.categoria
    GROUP BY
        m.departamento,
        v.product_category_name
),

satisfacao_por_departamento AS (
    SELECT
        f.departamento,
        AVG(CAST(f.satisfacao AS DOUBLE)) AS media_satisfacao,
        COUNT(DISTINCT f.employee_id)    AS total_funcionarios
    FROM rh_db.funcionarios f
    GROUP BY f.departamento
)

SELECT
    v.categoria,
    v.departamento,
    v.total_receita,
    v.qtd_itens,
    s.media_satisfacao,
    s.total_funcionarios
FROM vendas_por_departamento v
LEFT JOIN satisfacao_por_departamento s
    ON v.departamento = s.departamento
ORDER BY v.total_receita DESC;
