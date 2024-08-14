import boto3
from datetime import datetime

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    all_instances = ec2.describe_instances()
    preserved_instance_ids = []
    for reservation in all_instances['Reservations']:
        for instance in reservation['Instances']:
            instance_id = instance['InstanceId']
            for tag in instance['Tags']:
                if str(tag['Key']).lower() == 'stopinator:always-on' and str(tag['Value']).lower() == 'true':
                    preserved_instance_ids.append(instance_id)

    for reservation in all_instances['Reservations']:
        for instance in reservation['Instances']:
            instance_id = instance['InstanceId']
            if instance_id not in preserved_instance_ids:
                print(f"Will stop {instance_id}")
                timestamp = datetime.utcnow().isoformat()

                try:
                    print(f"Tagging {instance_id}")
                    ec2.create_tags(Resources=[instance_id], Tags=[{'Key': 'stopinator:last-stopped-at', 'Value': timestamp}])
                except Exception as e:
                    print(f"Error tagging instance {instance_id}: {str(e)}")

                try:
                    print(f"Stopping {instance_id}")
                    timestamp = datetime.utcnow().isoformat()
                    ec2.stop_instances(InstanceIds=[instance_id])
                except Exception as e:
                    print(f"Error stopping instance {instance_id}: {str(e)}")