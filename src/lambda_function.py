import json
import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('ResumeData')

def lambda_handler(event, context):
    try:
        response = table.get_item(Key={'id': 'resume'})
        item = response.get('Item', {})
        
        return {
            'statusCode': 200,
            'body': json.dumps(item),
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            }
        }
    except Exception as e:
        print(e)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal Server Error'}),
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            }
        }
