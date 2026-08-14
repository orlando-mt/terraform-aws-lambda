"""Minimal handler used to demonstrate zip packaging."""

import json
import os


def lambda_handler(event, context):
    records = event.get("Records", [])
    print(f"Processing {len(records)} record(s) in {os.environ.get('STAGE', 'unknown')}")

    return {
        "statusCode": 200,
        "body": json.dumps({"processed": len(records)}),
    }
