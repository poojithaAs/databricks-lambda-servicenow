import json
import os
import boto3
import requests

def lambda_handler(event, context):
    try:
        # Debug: incoming event
        print("Received event:", json.dumps(event))

        # Example: extracting Databricks Job ID and payload from event
        job_id = event.get("job_id") or os.environ.get("DATABRICKS_JOB_ID")
        token = os.environ.get("DATABRICKS_TOKEN")
        workspace_url = os.environ.get("DATABRICKS_WORKSPACE_URL")

        if not all([job_id, token, workspace_url]):
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "Missing required configuration"})
            }

        # Construct Databricks API endpoint
        api_url = f"{workspace_url}/api/2.1/jobs/run-now"

        # Trigger Databricks Job
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }

        payload = {"job_id": job_id}
        print("Triggering Databricks Job:", payload)

        response = requests.post(api_url, headers=headers, json=payload, timeout=30)

        # Check response
        if response.status_code != 200:
            print("Error Response:", response.text)
            return {
                "statusCode": response.status_code,
                "body": json.dumps({"error": response.text})
            }

        # Success
        result = response.json()
        print("Databricks Job triggered:", result)

        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Databricks Job triggered successfully",
                "run_id": result.get("run_id")
            })
        }

    except Exception as e:
        print("Exception:", str(e))
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
