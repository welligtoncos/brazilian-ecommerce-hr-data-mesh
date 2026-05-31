# Preserva state ao renomear recursos de permissões LF
moved {
  from = aws_lakeformation_permissions.produtor_vendas_db
  to   = aws_lakeformation_permissions.glue_vendas_db
}

moved {
  from = aws_lakeformation_permissions.analytics_select_vendas
  to   = aws_lakeformation_permissions.analytics_vendas_view
}

moved {
  from = aws_lakeformation_permissions.column_security_rh
  to   = aws_lakeformation_permissions.analytics_rh_columns
}
