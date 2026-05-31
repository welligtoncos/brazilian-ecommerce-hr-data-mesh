import sys

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext

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

funcionarios = spark.read.option("header", True).csv(
    f"{input_path}funcionarios/WA_Fn-UseC_-HR-Employee-Attrition.csv"
)

funcionarios.write.mode("overwrite").parquet(output_path)

job.commit()
