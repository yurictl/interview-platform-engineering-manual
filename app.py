"""Collect inventory, store an audit record, and publish a report."""

import json
import os
import time

import boto3
import psycopg
from botocore.config import Config
from botocore.exceptions import ClientError


sdk_config = Config(retries={"mode": "standard", "total_max_attempts": 3})
s3 = boto3.client("s3", config=sdk_config)
secrets = boto3.client("secretsmanager", config=sdk_config)


def handler(event, context):
    run_id = event["run_id"]
    secret = json.loads(secrets.get_secret_value(
        SecretId=os.environ["DB_SECRET_ARN"]
    )["SecretString"])
    connection = psycopg.connect(
        host=os.environ["DB_HOST"],
        port=int(os.environ["DB_PORT"]),
        dbname="inventory",
        user=secret["username"],
        password=secret["password"],
        sslmode="disable",
        connect_timeout=20,
    )
    try:
        for attempt in range(3):
            try:
                response = s3.list_objects_v2(
                    Bucket=os.environ["SOURCE_BUCKET"],
                    Prefix=os.environ["SOURCE_PREFIX"],
                )
                objects = response.get("Contents", [])
                report = {
                    "run_id": run_id,
                    "objects": len(objects),
                    "bytes": sum(item["Size"] for item in objects),
                }
                connection.execute(
                    "INSERT INTO inventory_runs (run_id, object_count, total_bytes) "
                    "VALUES (%s, %s, %s)",
                    (run_id, report["objects"], report["bytes"]),
                )
                connection.commit()
                s3.put_object(
                    Bucket=os.environ["REPORT_BUCKET"],
                    Key=f"reports/{run_id}.json",
                    Body=json.dumps(report).encode("utf-8"),
                    ContentType="application/json",
                )
                return {"statusCode": 200, "body": json.dumps(report)}
            except (ClientError, psycopg.Error) as error:
                print(f"Attempt {attempt + 1} failed: {type(error).__name__}")
                time.sleep(3)
        report = {"run_id": run_id, "objects": 0, "bytes": 0}
        return {"statusCode": 200, "body": json.dumps(report)}
    finally:
        connection.close()
