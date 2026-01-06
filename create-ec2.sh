#!/usr/bin/env bash

set -uo pipefail

# =========================
# LOGGING CONFIGURATION
# =========================

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Log function with color support
log() {
    local level="$1"
    shift
    local message="$@"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    case "$level" in
        ERROR)   echo -e "${RED}[$timestamp] [$level] $message${NC}" ;;
        SUCCESS) echo -e "${GREEN}[$timestamp] [$level] $message${NC}" ;;
        WARNING) echo -e "${YELLOW}[$timestamp] [$level] $message${NC}" ;;
        INFO)    echo -e "${BLUE}[$timestamp] [$level]${NC} $message" ;;
        *)       echo "[$timestamp] [$level] $message" ;;
    esac
}

# Validation function
validate_config() {
    local errors=0
    
    [[ -z "$AWS_PROFILE" ]] && { log "ERROR" "AWS_PROFILE is not set"; ((errors++)); }
    [[ -z "$AWS_REGION" ]] && { log "ERROR" "AWS_REGION is not set"; ((errors++)); }
    [[ -z "$AMI_ID" ]] && { log "ERROR" "AMI_ID is not set"; ((errors++)); }
    [[ -z "$SUBNET_ID" ]] && { log "ERROR" "SUBNET_ID is not set"; ((errors++)); }
    [[ -z "$SECURITY_GROUP_ID" ]] && { log "ERROR" "SECURITY_GROUP_ID is not set"; ((errors++)); }
    [[ ${#INSTANCE_NAMES[@]} -eq 0 ]] && { log "ERROR" "INSTANCE_NAMES array is empty"; ((errors++)); }
    
    if [[ $errors -gt 0 ]]; then
        log "ERROR" "Configuration validation failed with $errors error(s)"
        exit 1
    fi
    
    log "SUCCESS" "Configuration validated successfully"
}

# Check if instance exists
instance_exists() {
    local instance_name="$1"
    aws ec2 describe-instances \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --filters "Name=tag:Name,Values=$instance_name" \
                  "Name=instance-state-name,Values=pending,running,stopping,stopped" \
        --query "Reservations[0].Instances[0].[InstanceId,State.Name]" \
        --output text 2>/dev/null
}

# Create EC2 instance
create_instance() {
    local instance_name="$1"
    
    # Create temporary user data file to avoid Git Bash path conversion
    local userdata_file=$(mktemp)
    cat > "$userdata_file" << 'USERDATA'
#!/bin/bash
set -x
exec > /var/log/user-data.log 2>&1

echo "Starting user data script at $(date)"
apt update -y
apt upgrade -y
apt install git zip unzip curl -y

# Install AWS CLI v2
echo "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws

# Verify installations
echo "Git version: $(git --version)"
echo "AWS CLI version: $(aws --version)"

echo "User data script completed at $(date)"
USERDATA
    
    local result=$(aws ec2 run-instances \
        --profile "$AWS_PROFILE" \
        --region "$AWS_REGION" \
        --image-id "$AMI_ID" \
        --instance-type "$INSTANCE_TYPE" \
        --key-name "$KEY_NAME" \
        --subnet-id "$SUBNET_ID" \
        --security-group-ids "$SECURITY_GROUP_ID" \
        --iam-instance-profile "Name=$IAM_INSTANCE_PROFILE_NAME" \
        --user-data "file://$userdata_file" \
        --block-device-mappings "[{
            \"DeviceName\":\"/dev/xvda\",
            \"Ebs\":{
                \"VolumeSize\":$ROOT_VOLUME_SIZE,
                \"VolumeType\":\"$ROOT_VOLUME_TYPE\",
                \"DeleteOnTermination\":true
            }
        }]" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance_name}]" \
        --network-interfaces "DeviceIndex=0,SubnetId=$SUBNET_ID,Groups=$SECURITY_GROUP_ID,AssociatePublicIpAddress=$ASSOCIATE_PUBLIC_IP" \
        --query 'Instances[0].InstanceId' \
        --output text 2>&1)
    
    # Clean up temp file
    rm -f "$userdata_file"
    
    echo "$result"
}

log "INFO" "===== EC2 Instance Creation Script Started ====="

# =========================
# CONFIGURATION
# =========================

readonly AWS_PROFILE="sarowar-ostad"
readonly AWS_REGION="us-west-2"

readonly INSTANCE_NAMES=("ubuntu-01")

readonly AMI_ID="ami-00f46ccd1cbfb363e"
readonly INSTANCE_TYPE="t3.medium"
readonly KEY_NAME="ostad-batch-08"

readonly VPC_ID="vpc-02f7c57975d04ca56"
readonly SUBNET_ID="subnet-03672544009e3c40e"
readonly SECURITY_GROUP_ID="sg-07cc5ad28f68e8e55"

readonly ASSOCIATE_PUBLIC_IP=true
readonly IAM_INSTANCE_PROFILE_NAME="SSM"

readonly ROOT_VOLUME_SIZE=10
readonly ROOT_VOLUME_TYPE="gp3"

# Validate configuration
validate_config

# Log configuration
log "INFO" "Configuration:"
log "INFO" "  Region: $AWS_REGION | Profile: $AWS_PROFILE"
log "INFO" "  AMI: $AMI_ID | Type: $INSTANCE_TYPE"
log "INFO" "  Subnet: $SUBNET_ID | SG: $SECURITY_GROUP_ID"
log "INFO" "  Instances: ${INSTANCE_NAMES[*]}"

# =========================
# MAIN EXECUTION
# =========================

declare -i SUCCESS_COUNT=0 FAILED_COUNT=0 SKIPPED_COUNT=0

for INSTANCE_NAME in "${INSTANCE_NAMES[@]}"; do
    log "INFO" "Processing: $INSTANCE_NAME"

    # Check if instance already exists (excluding terminated)
    EXISTING=$(instance_exists "$INSTANCE_NAME")
    
    # Check if we got valid data (AWS returns "None" when no instances found)
    if [[ -n "$EXISTING" && "$EXISTING" != "None"* ]]; then
        read -r INSTANCE_ID STATE <<< "$EXISTING"
        log "WARNING" "Instance '$INSTANCE_NAME' already exists ($INSTANCE_ID - $STATE) - Skipping"
        ((SKIPPED_COUNT++))
        continue
    fi

    # Create the instance
    log "INFO" "Creating instance: $INSTANCE_NAME"
    
    if INSTANCE_ID=$(create_instance "$INSTANCE_NAME"); then
        # Check if we got a valid instance ID
        if [[ "$INSTANCE_ID" =~ ^i-[0-9a-f]+$ ]]; then
            log "SUCCESS" "Instance '$INSTANCE_NAME' created successfully ($INSTANCE_ID)"
            ((SUCCESS_COUNT++))
        else
            log "ERROR" "Instance creation failed: $INSTANCE_ID"
            ((FAILED_COUNT++))
        fi
    else
        log "ERROR" "Failed to create instance '$INSTANCE_NAME'"
        ((FAILED_COUNT++))
    fi
    
    [[ ${#INSTANCE_NAMES[@]} -gt 1 ]] && log "INFO" "---"
done

# =========================
# SUMMARY
# =========================

echo ""
log "INFO" "===== Summary ====="
log "INFO" "Total: ${#INSTANCE_NAMES[@]} | Created: $SUCCESS_COUNT | Skipped: $SKIPPED_COUNT | Failed: $FAILED_COUNT"

if [[ $FAILED_COUNT -gt 0 ]]; then
    log "ERROR" "Script completed with errors"
    exit 1
elif [[ $SUCCESS_COUNT -gt 0 ]]; then
    log "SUCCESS" "All new instances created successfully"
else
    log "INFO" "No new instances created"
fi
