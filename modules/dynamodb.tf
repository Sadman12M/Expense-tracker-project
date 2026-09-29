resource "aws_dynamodb_table" "expenses" {
  name         = "${var.project_name}-expenses"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "userId"
  range_key = "expenseId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "expenseId"
    type = "S"
  }

  tags = {
    Project = var.project_name
  }
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.expenses.name
}

output "dynamodb_table_arn" {
  value = aws_dynamodb_table.expenses.arn
}