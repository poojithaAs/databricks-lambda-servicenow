import json, os, urllib3

def lambda_handler(event, context):
    http = urllib3.PoolManager()
    try:
        databricks_url = os.environ["DATABRICKS_URL"]
        token = os.environ["DATABRICKS_TOKEN"]
        job_id = os.environ["JOB_ID"]

        resp = http.request(
            "POST",
            f"{databricks_url}/api/2.1/jobs/run-now",
            headers={"Authorization": f"Bearer {token}"},
            body=json.dumps({"job_id": job_id})
        )

        return {
            "statusCode": 200,
            "body": resp.data.decode("utf-8")
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
