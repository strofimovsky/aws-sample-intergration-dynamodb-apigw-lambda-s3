#!/usr/bin/env python

"""
Imports data from CSV URL to DynamoDB table
"""

import boto3
from botocore.exceptions import ClientError
from boto3.dynamodb.conditions import Key, Attr
from urllib import urlopen
import csv
import sys

dataurl = 'https://fred.stlouisfed.org/graph/fredgraph.csv?id=DCOILWTICO&fgsnd=2009-06-01&fq=Daily'
ddbtable = 'FREDdata'

def get_table(name):
    dynamodb = boto3.resource('dynamodb')
    # use an existing table or create one
    try:
        table = dynamodb.Table(name)
        status = table.table_status
    except ClientError as err:
        if err.response['Error']['Code'] == 'ResourceNotFoundException':
            print "Creating table"
            table = dynamodb.create_table(
                TableName=name,
                KeySchema=[
                    {'AttributeName': 'date', 'KeyType': 'HASH'},
                    {'AttributeName': 'DCOILWTICO', 'KeyType': 'RANGE'},
                ],
                AttributeDefinitions=[
                    {'AttributeName': 'date', 'AttributeType': 'S'},
                    {'AttributeName': 'DCOILWTICO', 'AttributeType': 'S'},
                ],
                ProvisionedThroughput={'ReadCapacityUnits': 5, 'WriteCapacityUnits': 100}
            )
            table.meta.client.get_waiter('table_exists').wait(TableName=name)

    return table

def main():
    table = get_table(ddbtable)
    csvfile = urlopen(dataurl)
    data = csv.reader(csvfile, delimiter=',', skipinitialspace=True)
    with table.batch_writer() as batch:
        for row in data:
            batch.put_item(Item={'date': row[0], 'DCOILWTICO': row[1],})
    print "Done"
    return 0

def lambda_handler(event, context):
    return main()

if __name__ == '__main__':
        sys.exit(main())
