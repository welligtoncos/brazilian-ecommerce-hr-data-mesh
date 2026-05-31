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

order_items = spark.read.option("header", True).csv(
    f"{input_path}order_items/olist_order_items_dataset.csv"
)
products = spark.read.option("header", True).csv(
    f"{input_path}products/olist_products_dataset.csv"
)

vendas = (
    order_items.join(products, on="product_id", how="inner")
    .withColumn("price", F.col("price").cast("double"))
    .groupBy("product_category_name")
    .agg(
        F.sum("price").alias("total_receita"),
        F.count("order_item_id").alias("qtd_itens"),
    )
)

vendas.write.mode("overwrite").parquet(output_path)

job.commit()
