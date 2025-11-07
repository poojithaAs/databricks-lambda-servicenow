import os
import json
import boto3
import requests


def lambda_handler(event, context):
    """
    Trigger a Databricks job securely from AWS Lambda.
    Retrieves Databricks token from Secrets Manager and triggers a Databricks job via REST API.
    """

    try:
        # --- Environment Variables ---
        databricks_url = os.environ.get("DATABRICKS_URL", "").rstrip("/")
        job_id = os.environ.get("DATABRICKS_JOB_ID")
        secret_name = os.environ.get("DATABRICKS_SECRET_NAME")
        region = os.environ.get("region") or os.environ.get("AWS_REGION", "us-east-1")

        if not databricks_url or not job_id or not secret_name:
            raise ValueError("Missing required environment variables.")

        # --- Get token from Secrets Manager ---
        sm = boto3.client("secretsmanager", region_name=region)
        secret_value = sm.get_secret_value(SecretId=secret_name)
        creds = json.loads(secret_value["SecretString"])
        token = creds.get("token")

        if not token:
            raise ValueError("Token key missing in secret value.")

        # --- Trigger Databricks Job ---
        headers = {"Authorization": f"Bearer {token}"}
        payload = {"job_id": job_id}

        response = requests.post(
            f"{databricks_url}/api/2.1/jobs/run-now",
            json=payload,
            headers=headers,
            timeout=30,
        )

        print(f"[INFO] Databricks Response: {response.status_code} - {response.text}")

        return {
            "statusCode": response.status_code,
            "body": response.text
        }

    except sm.exceptions.ResourceNotFoundException:
        print(f"[ERROR] Secret {secret_name} not found in region {region}.")
        return {
            "statusCode": 404,
            "body": json.dumps({"error": f"Secret {secret_name} not found."})
        }

    except requests.exceptions.RequestException as req_err:
        print(f"[ERROR] Request to Databricks failed: {req_err}")
        return {
            "statusCode": 502,
            "body": json.dumps({"error": "Databricks API call failed."})
        }

    except Exception as e:
        print(f"[ERROR] Lambda execution failed: {e}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
