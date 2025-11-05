import os
import json
import boto3
import requests
import logging
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_secret(secret_name):
    """Retrieve Databricks token from AWS Secrets Manager"""
    region = os.environ["AWS_REGION"]
    client = boto3.client("secretsmanager", region_name=region)
    try:
        response = client.get_secret_value(SecretId=secret_name)
        secret_dict = json.loads(response["SecretString"])
        return secret_dict.get("DATABRICKS_TOKEN")
    except ClientError as e:
        logger.error(f"Secrets Manager error: {e}")
        raise

def lambda_handler(event, context):
    """Trigger Databricks job"""
    host = os.environ["DATABRICKS_HOST"]
    job_id = os.environ["JOB_ID"]
    secret_name = os.environ["DATABRICKS_SECRET_NAME"]

    # Get token
    token = get_secret(secret_name)
    if not token:
        raise ValueError("Databricks token missing in Secrets Manager")

    # Build request
    url = f"{host}/api/2.1/jobs/run-now"
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    payload = {"job_id": job_id}

    # Log what’s happening
    logger.info(f"Triggering Databricks Job {job_id} at {host}")

    # Call Databricks API
    try:
        response = requests.post(url, headers=headers, json=payload, timeout=30)
        response.raise_for_status()
        data = response.json()
        logger.info(f"Databricks job triggered successfully: {data}")
        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Job triggered", "response": data})
        }
    except requests.exceptions.RequestException as e:
        logger.error(f"Databricks API call failed: {e}")
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}
