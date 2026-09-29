resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "${var.project_name}-lambda-dynamodb-policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:DeleteItem"
        ]
        Resource = aws_dynamodb_table.expenses.arn
      }
    ]
  })
}

data "archive_file" "add_expense_zip" {
  type        = "zip"
  source_file = "${path.root}/lambda_functions/add_expense.py"
  output_path = "${path.module}/build/add_expense.zip"
}

data "archive_file" "get_expenses_zip" {
  type        = "zip"
  source_file = "${path.root}/lambda_functions/get_expenses.py"
  output_path = "${path.module}/build/get_expenses.zip"
}

data "archive_file" "delete_expense_zip" {
  type        = "zip"
  source_file = "${path.root}/lambda_functions/delete_expense.py"
  output_path = "${path.module}/build/delete_expense.zip"
}

resource "aws_lambda_function" "add_expense" {
  function_name    = "${var.project_name}-add-expense"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "add_expense.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.add_expense_zip.output_path
  source_code_hash = data.archive_file.add_expense_zip.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.expenses.name
    }
  }
}

resource "aws_lambda_function" "get_expenses" {
  function_name    = "${var.project_name}-get-expenses"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "get_expenses.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.get_expenses_zip.output_path
  source_code_hash = data.archive_file.get_expenses_zip.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.expenses.name
    }
  }
}

resource "aws_lambda_function" "delete_expense" {
  function_name    = "${var.project_name}-delete-expense"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "delete_expense.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.delete_expense_zip.output_path
  source_code_hash = data.archive_file.delete_expense_zip.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.expenses.name
    }
  }
}

output "add_expense_function_name" {
  value = aws_lambda_function.add_expense.function_name
}

output "get_expenses_function_name" {
  value = aws_lambda_function.get_expenses.function_name
}

output "delete_expense_function_name" {
  value = aws_lambda_function.delete_expense.function_name
}

output "add_expense_invoke_arn" {
  value = aws_lambda_function.add_expense.invoke_arn
}

output "get_expenses_invoke_arn" {
  value = aws_lambda_function.get_expenses.invoke_arn
}

output "delete_expense_invoke_arn" {
  value = aws_lambda_function.delete_expense.invoke_arn
}