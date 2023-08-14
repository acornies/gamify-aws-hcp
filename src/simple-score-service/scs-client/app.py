'''
Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
'''
import json
import logging
import os
import boto3
import random

SCORE_RESOURCE_TYPES = [
    "AWS::RDS::DBInstance",
    "AWS::ECR::Repository",
    "AWS::Lambda::Function",
    "AWS::IAM::OIDCProvider"
]
SCORE_CONFIG = {}
AWS_ACCOUNT_ID = False

session = boto3.Session()
ccapi_client = session.client('cloudcontrol')
ssm_client = session.client('ssm')
sqs_client = session.client('sqs')
s3_client = session.client('s3')

logger = logging.getLogger()
if 'log_level' in os.environ:
    logger.setLevel(os.environ['log_level'])
    logger.info("Log level set to %s" % logger.getEffectiveLevel())
else:
    logger.setLevel(logging.INFO)

def get_score_config():
    global SCORE_CONFIG
    if 'score_config_bucket' in os.environ and 'score_config_key' in os.environ:
        try:
            logger.debug("Load score config from: {} - {}".format(os.environ['score_config_bucket'], os.environ['score_config_key']))
            response = s3_client.get_object(
                Bucket = os.environ['score_config_bucket'],
                Key = os.environ['score_config_key']
            )
            SCORE_CONFIG = json.loads(response["Body"].read().decode())
            logger.debug("Score config found : {}".format(SCORE_CONFIG))
            return True
        except Exception as e:
            logger.exception("Failed to fetch score config: {}".format(e))
            logger.warning("Score config not found, all scores will be discarded")
            return False
    else:
        logger.warning("Score config not found, all scores will be discarded")
        return True

def get_score_resource_type():
    global SCORE_RESOURCE_TYPES
    try:
        if len(SCORE_CONFIG["score_criteria"].keys()) > 0 :
            SCORE_RESOURCE_TYPES = list(SCORE_CONFIG["score_criteria"].keys())
            logger.debug("Score resource type retrieved from config: {}".format(SCORE_RESOURCE_TYPES))
        else:
            logger.debug("Using default score resource type: {}".format(SCORE_RESOURCE_TYPES))

    except Exception as e:
        logger.exception("Failed to fetch score resource type from config: {}".format(e))
        logger.debug("Using default score resource type: {}".format(SCORE_RESOURCE_TYPES))

def get_resource_by_type(resourceType):
    try:
        paginator = ccapi_client.get_paginator('list_resources')

        response_iterator = paginator.paginate(
            TypeName=resourceType
        )
        resource_by_type = []
        for page in response_iterator:
            resource_by_type.extend(page["ResourceDescriptions"])

        if resourceType == "AWS::Lambda::Function":
            # Skip counting the first Lambda function to exclude itself
            if len(resource_by_type) >= 1:
                resource_by_type.pop()

        logger.debug("Resource type {} - {} found".format(resourceType, len(resource_by_type)))
        return resource_by_type
        
    except Exception as e:
        logger.exception("Failed to list resource type: {} due to {}".format(resourceType,e))
        return False

def get_resource():
    resource_model = []
    for type in SCORE_RESOURCE_TYPES:
        resources_by_type = get_resource_by_type(type)
        if resources_by_type:            
            resource_model.append(
                {
                    "type": type,
                    "resources": resources_by_type
                }
            )            
    return resource_model

def calculate_score_by_type(resourceType, resourceList):
    global SCORE_CONFIG
    if resourceType in SCORE_CONFIG["score_criteria"]:
        item_score = int(SCORE_CONFIG["score_criteria"][resourceType]["basic_score"])
    else:
        item_score = 1
    resource_type_score = len(resourceList) * item_score
    return resource_type_score

def calculate_score(resource_model):
    total_score = 0
    for item in resource_model:
        logger.debug("Calculating score for type: {}".format(item["type"]))
        resource_type_score = calculate_score_by_type(item["type"], item["resources"])
        logger.debug("Sub-total score for type: {} = {}".format(item["type"], resource_type_score))
        total_score = total_score + resource_type_score
    random_boost = random.uniform(0.0, 0.1)
    logger.debug("Total boost : {}".format(random_boost))
    total_score = total_score + int(random_boost * total_score)
    logger.debug("Total score : {}".format(total_score))
    return total_score

# Expected payload 
# {
#   "function_arn": "x"
#   "function_name": "x"
#   "account_id": "x",
#   "points": 1
# }
def send_score(targetQueueUrl, payload):
    logger.debug("Sending score : {}".format(payload))
    try:
        response = sqs_client.send_message(
            QueueUrl=targetQueueUrl,
            MessageBody=json.dumps(payload)
        )
        logger.debug("Sent score response: {}".format(response))
        return response
    except Exception as e:
        logger.exception("Failed to send score to queue: {} due to {}".format(targetQueueUrl, e))
        return False

def lambda_handler(event, context):
    global AWS_ACCOUNT_ID 
    AWS_ACCOUNT_ID = str(context.invoked_function_arn).split(":")[4]

    get_score_config()
    get_score_resource_type()
    resource_model = get_resource()
    total_score = calculate_score(resource_model)
    payload = {
        "function_arn" : context.invoked_function_arn,
        "function_name" : context.function_name,
        "account_id" : AWS_ACCOUNT_ID,
        "points" : total_score
    }
    if SCORE_CONFIG["score_queue_url"] != "":
        send_score(SCORE_CONFIG["score_queue_url"], payload)
    else:
        logger.warning("Payload discarded because score queue was not found : {}".format(payload))