import json, os
from databricks import sql

def lambda_handler(event, context):
    try:
        with sql.connect(
            server_hostname=os.environ['DATABRICKS_HOST'],
            http_path=os.environ['DATABRICKS_HTTP_PATH'],
            access_token=os.environ['DATABRICKS_TOKEN']
        ) as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM vehicle_age_view LIMIT 10")
            rows = cursor.fetchall()
        return {'statusCode': 200, 'body': json.dumps(rows)}
    except Exception as e:
        return {'statusCode': 500, 'body': str(e)}

