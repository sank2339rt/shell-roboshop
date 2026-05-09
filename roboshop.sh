#!/bin/bash

SG_ID="sg-047c75f124eff5499"
SUBNET_ID="subnet-0b14763661b94a835"
AMI_ID="ami-0220d79f3f480ecf5"
ZONE_ID="Z05589412ZZNFD99WYGU4"
DOMAIN_NAME="sank2339.online"

for instance in $@
do
    echo "Creating instance: $instance"

    INSTANCE_ID=$( aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type "t3.micro" \
    --security-group-ids $SG_ID \
    --subnet-id $SUBNET_ID \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" \
    --query 'Instances[0].InstanceId' \
    --output text )

    # Validate instance creation
    if [ -z "$INSTANCE_ID" ]; then
        echo "Failed to create instance for $instance"
        exit 1
    fi

    echo "Instance created with ID: $INSTANCE_ID"

    # Wait until instance is running
    aws ec2 wait instance-running --instance-ids $INSTANCE_ID

    echo "Instance $instance is now running"

    if [ "$instance" == "frontend" ]; then

        IP=$( aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[].Instances[].PublicIpAddress' \
        --output text )

        RECORD_NAME="$DOMAIN_NAME"

    else

        IP=$( aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[].Instances[].PrivateIpAddress' \
        --output text )

        RECORD_NAME="$instance.$DOMAIN_NAME"

    fi

    echo "IP Address: $IP"

    aws route53 change-resource-record-sets \
    --hosted-zone-id $ZONE_ID \
    --change-batch '
    {
        "Comment": "Updating record",
        "Changes": [
            {
                "Action": "UPSERT",
                "ResourceRecordSet": {
                    "Name": "'$RECORD_NAME'",
                    "Type": "A",
                    "TTL": 1,
                    "ResourceRecords": [
                        {
                            "Value": "'$IP'"
                        }
                    ]
                }
            }
        ]
    }
    '

    echo "DNS record updated for $instance"

done