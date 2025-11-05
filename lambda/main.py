import json
import os
import urllib3

http = urllib3.PoolManager()

def lambda_handler(event, context):
    try:
        databricks_url = os.environ['DATABRICKS_URL']
        databricks_token = os.environ['DATABRICKS_TOKEN']
        job_id = os.environ['JOB_ID']

        headers = {
            'Authorization': f'Bearer {databricks_token}',
            'Content-Type': 'application/json'
        }

        body = {
            "job_id": job_id
        }

        response = http.request(
            'POST',
            f"{databricks_url}/api/2.1/jobs/run-now",
            body=json.dumps(body).encode('utf-8'),
            headers=headers
        )

        return {
            'statusCode': response.status,
            'body': response.data.decode('utf-8')
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
