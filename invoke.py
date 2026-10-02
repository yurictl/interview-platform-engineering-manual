"""Submit a logical inventory run and print its result."""

import json
import sys
import time

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError


def main():
    function_name, run_id = sys.argv[1:]
    client = boto3.client("lambda", config=Config(
        connect_timeout=3,
        read_timeout=5,
        retries={"mode": "standard", "total_max_attempts": 3},
    ))
    for attempt in range(3):
        try:
            response = client.invoke(
                FunctionName=function_name,
                InvocationType="RequestResponse",
                Payload=json.dumps({"run_id": run_id}).encode("utf-8"),
            )
            result = json.loads(response["Payload"].read())
            if response.get("FunctionError") or result.get("statusCode") != 200:
                raise RuntimeError("Inventory invocation did not succeed")
            print(result)
            return 0
        except (BotoCoreError, ClientError, RuntimeError) as error:
            print(f"Invocation attempt {attempt + 1}: {type(error).__name__}")
            time.sleep(1)
    return 1


if __name__ == "__main__":
    sys.exit(main())
