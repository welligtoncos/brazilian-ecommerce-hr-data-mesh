-- Queries para o time de negócios
-- Workgroup: wg-analytics | Role: data-mesh-role-analytics-dev
-- Tabelas: vendas_db.vendas_por_categoria, rh_db.funcionarios
-- Cross-domínio completo: cross-domain-vendas-rh.sql

-- =============================================================================
-- 1. Painel executivo — KPIs da empresa
-- Objetivo: visão única vendas + RH para diretoria
-- =============================================================================
SELECT
  (SELECT COUNT(*) FROM vendas_db.vendas_por_categoria) AS categorias_vendidas,
  (SELECT CAST(SUM(total_receita) AS DECIMAL(18, 2)) FROM vendas_db.vendas_por_categoria) AS receita_total,
  (SELECT SUM(qtd_itens) FROM vendas_db.vendas_por_categoria) AS itens_vendidos,
  (SELECT COUNT(*) FROM rh_db.funcionarios) AS total_funcionarios,
  (SELECT ROUND(AVG(satisfacao), 2) FROM rh_db.funcionarios) AS satisfacao_media_empresa;

-- =============================================================================
-- 2. Vendas — top categorias por receita e ticket médio
-- Objetivo: priorizar categorias e entender receita por item
-- =============================================================================
SELECT
  product_category_name AS categoria,
  total_receita,
  qtd_itens,
  ROUND(total_receita / NULLIF(qtd_itens, 0), 2) AS ticket_medio_item
FROM vendas_db.vendas_por_categoria
ORDER BY total_receita DESC
LIMIT 20;

-- =============================================================================
-- 3. Vendas — % da receita nas top 10 categorias
-- Objetivo: medir concentração do faturamento
-- =============================================================================
WITH tot AS (
  SELECT SUM(total_receita) AS receita_empresa
  FROM vendas_db.vendas_por_categoria
),
top10 AS (
  SELECT SUM(total_receita) AS receita_top10
  FROM (
    SELECT total_receita
    FROM vendas_db.vendas_por_categoria
    ORDER BY total_receita DESC
    LIMIT 10
  )
)
SELECT
  receita_top10,
  receita_empresa,
  ROUND(100.0 * receita_top10 / receita_empresa, 1) AS pct_receita_top10
FROM top10, tot;

-- =============================================================================
-- 4. RH — satisfação e anos de empresa por departamento
-- Objetivo: comparar engajamento e retenção entre áreas
-- =============================================================================
SELECT
  departamento,
  COUNT(*) AS funcionarios,
  ROUND(AVG(satisfacao), 2) AS media_satisfacao,
  ROUND(AVG(anos_empresa), 1) AS media_anos_empresa
FROM rh_db.funcionarios
GROUP BY departamento
ORDER BY funcionarios DESC;

-- =============================================================================
-- 5. RH — taxa de rotatividade por departamento
-- Objetivo: identificar áreas com mais saídas
-- =============================================================================
SELECT
  departamento,
  COUNT(*) AS funcionarios,
  SUM(total_saidas) AS saidas,
  ROUND(100.0 * SUM(total_saidas) / COUNT(*), 1) AS pct_rotatividade
FROM rh_db.funcionarios
GROUP BY departamento
ORDER BY pct_rotatividade DESC;

-- =============================================================================
-- 6. RH — alertas de baixa satisfação (cargo/departamento)
-- Objetivo: priorizar ações de people analytics
-- =============================================================================
SELECT
  departamento,
  cargo,
  COUNT(*) AS qtd,
  ROUND(AVG(satisfacao), 2) AS media_satisfacao
FROM rh_db.funcionarios
GROUP BY departamento, cargo
HAVING AVG(satisfacao) <= 2
ORDER BY media_satisfacao, qtd DESC;

-- =============================================================================
-- 7. Cross-domínio — ver scripts/queries/cross-domain-vendas-rh.sql
-- Objetivo: cruzar receita por categoria com satisfação por departamento
-- =============================================================================
