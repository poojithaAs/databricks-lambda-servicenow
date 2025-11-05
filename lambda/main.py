import json
import os
import urllib3
import boto3

def lambda_handler(event, context):
    http = urllib3.PoolManager()
    secrets_client = boto3.client("secretsmanager")

    try:
        secret_name = os.environ["DATABRICKS_SECRET_NAME"]
        secret_value = secrets_client.get_secret_value(SecretId=secret_name)
        secrets = json.loads(secret_value["SecretString"])

        databricks_url = secrets["DATABRICKS_URL"]
        databricks_token = secrets["DATABRICKS_TOKEN"]
        databricks_job_id = secrets["DATABRICKS_JOB_ID"]

        response = http.request(
            "POST",
            f"{databricks_url}/api/2.1/jobs/run-now",
            headers={"Authorization": f"Bearer {databricks_token}"},
            body=json.dumps({"job_id": databricks_job_id})
        )

        return {"statusCode": 200, "body": response.data.decode("utf-8")}

    except Exception as e:
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}
