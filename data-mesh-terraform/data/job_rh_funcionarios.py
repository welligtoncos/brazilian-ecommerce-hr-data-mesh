import sys

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import functions as F

args = getResolvedOptions(
    sys.argv,
    ["JOB_NAME", "INPUT_PATH", "OUTPUT_PATH"],
)

sc = SparkContext()
glue_context = GlueContext(sc)
spark = glue_context.spark_session
job = Job(glue_context)
job.init(args["JOB_NAME"], args)

input_path = args["INPUT_PATH"]
output_path = args["OUTPUT_PATH"]

raw = spark.read.option("header", True).csv(
    f"{input_path}funcionarios/WA_Fn-UseC_-HR-Employee-Attrition.csv"
)

funcionarios = (
    raw.withColumnRenamed("EmployeeNumber", "employee_id")
    .withColumnRenamed("Department", "departamento")
    .withColumnRenamed("JobRole", "cargo")
    .withColumnRenamed("Age", "idade")
    .withColumnRenamed("Gender", "genero")
    .withColumnRenamed("YearsAtCompany", "anos_empresa")
    .withColumnRenamed("JobSatisfaction", "satisfacao")
    .withColumnRenamed("Attrition", "rotatividade")
    .withColumn(
        "faixa_salarial",
        F.when(F.col("MonthlyIncome").cast("int") < 5000, "baixa")
        .when(F.col("MonthlyIncome").cast("int") < 10000, "media")
        .otherwise("alta"),
    )
    .withColumn("total_funcionarios", F.lit(1))
    .withColumn(
        "total_saidas",
        F.when(F.col("rotatividade") == "Yes", F.lit(1)).otherwise(F.lit(0)),
    )
    .withColumn("media_satisfacao", F.col("satisfacao").cast("double"))
    .withColumn("media_anos_empresa", F.col("anos_empresa").cast("double"))
    .withColumn("data_carga", F.current_date())
    .select(
        "employee_id",
        "departamento",
        "cargo",
        "idade",
        "genero",
        "anos_empresa",
        "satisfacao",
        "rotatividade",
        "faixa_salarial",
        "total_funcionarios",
        "total_saidas",
        "media_satisfacao",
        "media_anos_empresa",
        "data_carga",
    )
)

funcionarios.write.mode("overwrite").parquet(output_path)

job.commit()
