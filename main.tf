
# adding the DynamoDB table resource
resource "aws_dynamodb_table" "resume_table" {
  name           = "ResumeData"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# Adding the Lambda function resource

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/src/lambda_function.py"
  output_path = "${path.module}/src/lambda_function.zip"
}

resource "aws_lambda_function" "resume_api" {
  filename      = "${path.module}/src/lambda_function.zip"
  function_name = "resume-api"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

# Adding the IAM role for the Lambda function

resource "aws_iam_role" "lambda_role" {
  name = "resume_api_lambda_role"

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

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_role.name
}

resource "aws_iam_role_policy" "dynamodb_policy" {
  name = "dynamodb_access_policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.resume_table.arn
      }
    ]
  })
}

# Adding the API Gateway Resources

resource "aws_apigatewayv2_api" "resume_api" {
  name          = "resume-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "resume_api" {
  api_id = aws_apigatewayv2_api.resume_api.id
  name   = "prod"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "resume_api" {
  api_id           = aws_apigatewayv2_api.resume_api.id
  integration_type = "AWS_PROXY"

  connection_type    = "INTERNET"
  description        = "Lambda integration"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.resume_api.invoke_arn
}

resource "aws_apigatewayv2_route" "resume_api" {
  api_id    = aws_apigatewayv2_api.resume_api.id
  route_key = "GET /resume"
  target    = "integrations/${aws_apigatewayv2_integration.resume_api.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resume_api.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.resume_api.execution_arn}/*/*"
}

