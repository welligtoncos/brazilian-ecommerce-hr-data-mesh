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

cols = set(raw.columns)


def pick(*candidates, default=None):
    for name in candidates:
        if name in cols:
            return F.col(name)
    if default is not None:
        return F.lit(default)
    return F.lit(None)


if "EmployeeNumber" in cols:
    employee_id = pick("EmployeeNumber").cast("string")
else:
    employee_id = F.sha2(
        F.concat_ws(
            "|",
            pick("Age", default=""),
            pick("Department", default=""),
            pick("MonthlyIncome", default=""),
            pick("YearsAtCompany", default=""),
            pick("Attrition", default=""),
        ),
        256,
    )

cargo_expr = pick("JobRole", "EducationField", default="N/D")

funcionarios = (
    raw.withColumn("employee_id", employee_id)
    .withColumn("departamento", pick("Department", default="N/D"))
    .withColumn("cargo", cargo_expr)
    .withColumn("idade", pick("Age").cast("int"))
    .withColumn("genero", pick("Gender", default="N/D"))
    .withColumn("anos_empresa", pick("YearsAtCompany").cast("int"))
    .withColumn("satisfacao", pick("JobSatisfaction").cast("int"))
    .withColumn("rotatividade", pick("Attrition", default="No"))
    .withColumn(
        "faixa_salarial",
        F.when(pick("MonthlyIncome").cast("int") < 5000, "baixa")
        .when(pick("MonthlyIncome").cast("int") < 10000, "media")
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
