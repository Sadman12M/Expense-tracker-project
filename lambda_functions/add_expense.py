import json
import os
import uuid
import boto3
from decimal import Decimal, InvalidOperation
from datetime import datetime, timezone

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])

ALLOWED_CATEGORIES = {"Food", "Transport", "Rent", "Utilities", "Other"}
MAX_AMOUNT = Decimal("10000000")
MAX_DESCRIPTION_LENGTH = 200


def lambda_handler(event, context):
    try:
        user_id = event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"]
    except KeyError:
        print("Missing JWT claims in request context")
        return _response(401, {"error": "Unauthorized"})

    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Invalid JSON in request body"})

    category = body.get("category")
    if category not in ALLOWED_CATEGORIES:
        return _response(400, {"error": f"category must be one of {sorted(ALLOWED_CATEGORIES)}"})

    try:
        amount = Decimal(str(body.get("amount")))
    except InvalidOperation:
        return _response(400, {"error": "amount must be a number"})
    if not amount.is_finite() or amount <= 0 or amount > MAX_AMOUNT:
        return _response(400, {"error": "amount must be greater than 0 and at most 10,000,000"})
    amount = amount.quantize(Decimal("0.01"))

    date = body.get("date") or datetime.now(timezone.utc).strftime("%Y-%m-%d")
    try:
        datetime.strptime(date, "%Y-%m-%d")
    except (ValueError, TypeError):
        return _response(400, {"error": "date must be in YYYY-MM-DD format"})

    description = str(body.get("description") or "")[:MAX_DESCRIPTION_LENGTH]

    expense_id = str(uuid.uuid4())
    item = {
        "userId": user_id,
        "expenseId": expense_id,
        "amount": amount,
        "category": category,
        "description": description,
        "date": date,
        "createdAt": datetime.now(timezone.utc).isoformat(),
    }

    try:
        table.put_item(Item=item)
    except Exception as e:
        print(f"Error adding expense: {str(e)}")
        return _response(500, {"error": "Internal server error"})

    return _response(201, {
        "expenseId": expense_id,
        "message": "Expense added successfully"
    })


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body)
    }