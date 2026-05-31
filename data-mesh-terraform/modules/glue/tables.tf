resource "aws_glue_catalog_table" "vendas_por_categoria" {
  name          = "vendas_por_categoria"
  database_name = aws_glue_catalog_database.vendas.name
  description   = "Vendas agregadas por categoria (camada refined)"
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL            = "TRUE"
    "parquet.compression" = "SNAPPY"
  }

  storage_descriptor {
    location      = "s3://${var.bucket_name}/dominio=vendas/refined/vendas_por_categoria/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "ParquetHiveSerDe"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "product_category_name"
      type = "string"
    }
    columns {
      name = "total_receita"
      type = "double"
    }
    columns {
      name = "qtd_itens"
      type = "bigint"
    }
  }

}

resource "aws_glue_catalog_table" "funcionarios" {
  name          = "funcionarios"
  database_name = aws_glue_catalog_database.rh.name
  description   = "Funcionarios RH (camada refined, column-level security via Lake Formation)"
  table_type    = "EXTERNAL_TABLE"

  parameters = {
    EXTERNAL            = "TRUE"
    "parquet.compression" = "SNAPPY"
  }

  storage_descriptor {
    location      = "s3://${var.bucket_name}/dominio=rh/refined/funcionarios/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      name                  = "ParquetHiveSerDe"
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1"
      }
    }

    columns {
      name = "employee_id"
      type = "string"
    }
    columns {
      name = "departamento"
      type = "string"
    }
    columns {
      name = "cargo"
      type = "string"
    }
    columns {
      name = "idade"
      type = "int"
    }
    columns {
      name = "genero"
      type = "string"
    }
    columns {
      name = "anos_empresa"
      type = "int"
    }
    columns {
      name = "satisfacao"
      type = "int"
    }
    columns {
      name = "rotatividade"
      type = "string"
    }
    columns {
      name = "faixa_salarial"
      type = "string"
    }
    columns {
      name = "total_funcionarios"
      type = "int"
    }
    columns {
      name = "total_saidas"
      type = "int"
    }
    columns {
      name = "media_satisfacao"
      type = "double"
    }
    columns {
      name = "media_anos_empresa"
      type = "double"
    }
    columns {
      name = "data_carga"
      type = "date"
    }
  }
}
