import json
import os
import boto3
from decimal import Decimal
from datetime import datetime, timezone
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    try:
        user_id = event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]
    except KeyError:
        print("Missing JWT claims in request context")
        return _response(401, {"error": "Unauthorized"})

    category_filter = (event.get("queryStringParameters") or {}).get("category")

    try:
        response = table.query(KeyConditionExpression=Key("userId").eq(user_id))
        items = response.get("Items", [])

        while "LastEvaluatedKey" in response:
            response = table.query(
                KeyConditionExpression=Key("userId").eq(user_id),
                ExclusiveStartKey=response["LastEvaluatedKey"]
            )
            items.extend(response.get("Items", []))
    except Exception as e:
        print(f"Error fetching expenses: {str(e)}")
        return _response(500, {"error": "Internal server error"})

    if category_filter:
        items = [i for i in items if i.get("category") == category_filter]

    items.sort(key=lambda x: (x.get("date", ""), x.get("createdAt", "")), reverse=True)

    this_month = datetime.now(timezone.utc).strftime("%Y-%m")
    total = sum((i.get("amount", Decimal(0)) for i in items), Decimal(0))
    month_total = sum(
        (i.get("amount", Decimal(0)) for i in items if i.get("date", "").startswith(this_month)),
        Decimal(0)
    )

    return _response(200, {
        "expenses": items,
        "count": len(items),
        "total": str(total),
        "monthTotal": str(month_total)
    })


def _decimal_default(obj):
    if isinstance(obj, Decimal):
        return str(obj)
    raise TypeError(f"Cannot serialize {type(obj)}")


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body, default=_decimal_default)
    }