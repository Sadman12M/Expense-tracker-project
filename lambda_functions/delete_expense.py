import json
import os
import uuid
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    try:
        user_id = event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]
    except KeyError:
        print("Missing JWT claims in request context")
        return _response(401, {"error": "Unauthorized"})

    expense_id = (event.get("pathParameters") or {}).get("id")
    if not expense_id:
        return _response(400, {"error": "expense id is required in the path"})

    try:
        uuid.UUID(expense_id)
    except ValueError:
        return _response(400, {"error": "invalid expense id"})

    try:
        table.delete_item(
            Key={"userId": user_id, "expenseId": expense_id},
            ConditionExpression="attribute_exists(expenseId)"
        )
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return _response(404, {"error": "Expense not found"})
        print(f"DynamoDB error: {str(e)}")
        return _response(500, {"error": "Internal server error"})
    except Exception as e:
        print(f"Error deleting expense: {str(e)}")
        return _response(500, {"error": "Internal server error"})

    return _response(200, {"message": "Expense deleted successfully"})


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body)
    }