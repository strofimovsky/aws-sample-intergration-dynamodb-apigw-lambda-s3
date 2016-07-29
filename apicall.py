#!/usr/bin/env python

"""
API endpoint, queries and returns data from DynamoDB
"""

import boto3
from botocore.exceptions import ClientError
from boto3.dynamodb.conditions import Key, Attr
import sys

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('FREDdata')

def get_item(val):
    response = table.query(KeyConditionExpression=Key('date').eq(val))
    return response['Items']

def main(val):
    return get_item(val)

def lambda_handler(event, context):
    val = event['params']['path']['val']
    if val:
        return main(val)
    else:
        return "{'error': 'No query string'}"

if __name__ == '__main__':
    if len(sys.argv) > 1:
        val = sys.argv[1]
        sys.exit(main(val))
    else:
        print('Usage: {} <val>')
        sys.exit(1)
