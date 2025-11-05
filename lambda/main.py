import os
import json
import boto3
import logging
import requests
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_secret(secret_arn):
    """
    Retrieve Databricks secret from AWS Secrets Manager.
    The secret should contain JSON with key 'DATABRICKS_TOKEN'.
    """
    try:
        client = boto3.client("secretsmanager", region_name=os.environ["AWS_REGION"])
        secret_value = client.get_secret_value(SecretId=secret_arn)
        secret_string = secret_value.get("SecretString")

        if not secret_string:
            raise ValueError("Empty secret value returned from Secrets Manager")

        secret_dict = json.loads(secret_string)
        token = secret_dict.get("DATABRICKS_TOKEN")

        if not token:
            raise KeyError("Missing 'DATABRICKS_TOKEN' in secret JSON")

        return token

    except ClientError as e:
        logger.error(f"Error retrieving secret: {e}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error reading secret: {e}")
        raise

def lambda_handler(event, context):
    """
    Lambda entry point.
    Securely triggers a Databricks job using REST API with token from AWS Secrets Manager.
    """

    try:
        # --- Step 1: Read environment configuration ---
        databricks_host = os.environ.get("DATABRICKS_HOST")
        job_id = os.environ.get("JOB_ID")
        secret_arn = os.environ.get("DATABRICKS_TOKEN_SECRET_ARN")

        if not databricks_host or not job_id or not secret_arn:
            missing = [k for k, v in {
                "DATABRICKS_HOST": databricks_host,
                "JOB_ID": job_id,
                "DATABRICKS_TOKEN_SECRET_ARN": secret_arn
            }.items() if not v]
            logger.error(f"Missing required environment variables: {missing}")
            return {
                "statusCode": 400,
                "body": json.dumps({"error": f"Missing environment variables: {missing}"})
            }

        # --- Step 2: Get Databricks token from AWS Secrets Manager ---
        databricks_token = get_secret(secret_arn)

        # --- Step 3: Build Databricks API request ---
        api_url = f"{databricks_host}/api/2.1/jobs/run-now"
        headers = {
            "Authorization": f"Bearer {databricks_token}",
            "Content-Type": "application/json"
        }

        # Allow passing parameters dynamically from API Gateway or ServiceNow
        job_parameters = event.get("parameters") if isinstance(event, dict) else None
        payload = {"job_id": job_id}
        if job_parameters:
            payload["notebook_params"] = job_parameters

        logger.info(f"Triggering Databricks Job ID: {job_id}")

        # --- Step 4: Call Databricks REST API ---
        response = requests.post(api_url, headers=headers, json=payload, timeout=30)
        response.raise_for_status()
        result = response.json()

        run_id = result.get("run_id", "unknown")
        logger.info(f"Job triggered successfully. Run ID: {run_id}")

        # --- Step 5: Return structured response ---
        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Databricks job triggered successfully",
                "run_id": run_id,
                "response": result
            })
        }

    except requests.exceptions.HTTPError as errh:
        logger.error(f"HTTP error: {errh.response.text}")
        return {
            "statusCode": errh.response.status_code,
            "body": json.dumps({"error": errh.response.text})
        }

    except requests.exceptions.RequestException as err:
        logger.error(f"Network or timeout error: {err}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(err)})
        }

    except Exception as e:
        logger.error(f"Unhandled exception: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
