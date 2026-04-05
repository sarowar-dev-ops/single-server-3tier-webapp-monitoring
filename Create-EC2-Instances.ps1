param(
    [string]$AwsProfile = "sarowar-ostad",
    [string]$Region = "ap-south-1",
    [string]$NamePrefix = "monitoring",
    [int]$InstanceCount = 2,
    [string]$InstanceType = "t3.medium",
    [string]$VpcId = "vpc-06f7dead5c49ece64",
    [string]$SubnetId = "subnet-0880772cfbeb8bb6f",
    [string]$SecurityGroupId = "sg-097d6afb08616ba09",
    [bool]$EnablePublicIp = $true,
    [string]$InstanceProfileName = "SSM",
    [int]$EbsGp3SizeGiB = 10,
    [string]$AmiId = "ami-05d2d839d4f73aafb",
    [string]$KeyName = "sarowar-ostad-mumbai",
    [switch]$NoPrompt,
    [switch]$WaitForRunning
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK]   $Message" -ForegroundColor Green
}

function Write-WarnMsg {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "[ERR]  $Message" -ForegroundColor Red
}

function Invoke-AwsCli {
    param(
        [string[]]$Arguments,
        [switch]$AsJson
    )

    $argList = @($Arguments + "--no-cli-pager")

    # PowerShell 5.1-compatible quoting for ProcessStartInfo.Arguments
    $escapedArgs = $argList | ForEach-Object {
        if ($_ -match '[\s"]') {
            '"' + ($_.Replace('"', '\"')) + '"'
        }
        else {
            $_
        }
    }
    $argString = $escapedArgs -join ' '

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "aws"
    $psi.Arguments = $argString
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi

    [void]$proc.Start()
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    $exitCode = $proc.ExitCode
    $stdoutText = ($stdout | Out-String).Trim()
    $stderrText = ($stderr | Out-String).Trim()

    if ($exitCode -ne 0) {
        $err = if (-not [string]::IsNullOrWhiteSpace($stderrText)) { $stderrText } else { "No stderr captured from AWS CLI." }
        throw [System.Exception]::new("AWS CLI failed (exit=$exitCode). Command: aws $($argList -join ' ') | Error: $err")
    }

    if ($AsJson) {
        try {
            if ([string]::IsNullOrWhiteSpace($stdoutText)) {
                throw "Empty JSON output"
            }
            return ($stdoutText | ConvertFrom-Json)
        }
        catch {
            throw "Failed to parse AWS CLI JSON response. Command: aws $($argList -join ' ') | Stdout: $stdoutText | Stderr: $stderrText"
        }
    }

    return $stdoutText
}

function Get-ErrorText {
    param($ErrorRecord)

    $message = ""
    if ($ErrorRecord -and $ErrorRecord.Exception -and $ErrorRecord.Exception.Message) {
        $message = $ErrorRecord.Exception.Message
    }

    if ([string]::IsNullOrWhiteSpace($message) -and $ErrorRecord) {
        $message = ($ErrorRecord | Out-String).Trim()
    }

    if ([string]::IsNullOrWhiteSpace($message)) {
        $message = "Unknown error (no details available)."
    }

    return $message
}

function Assert-RunInstancesDryRun {
    param(
        [string]$Profile,
        [string]$AwsRegion,
        [string]$ImageId,
        [string]$Type,
        [string]$Subnet,
        [string]$SecurityGroup,
        [string]$BlockMappings,
        [string]$TagSpec,
        [bool]$PublicIp,
        [string]$ProfileName,
        [string]$Ec2KeyName
    )

    Write-Info "Running preflight dry-run for ec2 run-instances..."

    $cmd = @(
        "ec2", "run-instances",
        "--profile", $Profile,
        "--region", $AwsRegion,
        "--image-id", $ImageId,
        "--instance-type", $Type,
        "--subnet-id", $Subnet,
        "--security-group-ids", $SecurityGroup,
        "--block-device-mappings", $BlockMappings,
        "--tag-specifications", $TagSpec,
        "--count", "1",
        "--dry-run",
        "--output", "json"
    )

    if ($PublicIp) {
        $cmd += "--associate-public-ip-address"
    }

    if (-not [string]::IsNullOrWhiteSpace($ProfileName)) {
        $cmd += @("--iam-instance-profile", "Name=$ProfileName")
    }

    if (-not [string]::IsNullOrWhiteSpace($Ec2KeyName)) {
        $cmd += @("--key-name", $Ec2KeyName)
    }

    try {
        $null = Invoke-AwsCli -Arguments $cmd -AsJson
        Write-WarnMsg "Dry-run unexpectedly succeeded. Continuing..."
    }
    catch {
        $errText = Get-ErrorText $_
        if ($errText -match "DryRunOperation") {
            Write-Success "Dry-run passed (required permissions and parameters look valid)."
            return
        }

        throw "Preflight dry-run failed. $errText"
    }
}

function Require-Value {
    param(
        [string]$Name,
        [string]$Value
    )
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "Missing required value: $Name"
    }
}

function Assert-ResourceCompatibility {
    param(
        [string]$Vpc,
        [string]$Subnet,
        [string]$SecurityGroup,
        [string]$Profile,
        [string]$AwsRegion
    )

    Write-Info "Validating subnet belongs to VPC..."
    $subnetResult = Invoke-AwsCli -Arguments @(
        "ec2", "describe-subnets",
        "--profile", $Profile,
        "--region", $AwsRegion,
        "--subnet-ids", $Subnet,
        "--output", "json"
    ) -AsJson

    if (-not $subnetResult.Subnets -or $subnetResult.Subnets.Count -eq 0) {
        throw "Subnet not found: $Subnet"
    }

    $subnetVpcId = $subnetResult.Subnets[0].VpcId
    if ($subnetVpcId -ne $Vpc) {
        throw "Subnet $Subnet belongs to VPC $subnetVpcId, expected $Vpc"
    }
    Write-Success "Subnet/VPC validation passed"

    Write-Info "Validating security group belongs to VPC..."
    $sgResult = Invoke-AwsCli -Arguments @(
        "ec2", "describe-security-groups",
        "--profile", $Profile,
        "--region", $AwsRegion,
        "--group-ids", $SecurityGroup,
        "--output", "json"
    ) -AsJson

    if (-not $sgResult.SecurityGroups -or $sgResult.SecurityGroups.Count -eq 0) {
        throw "Security group not found: $SecurityGroup"
    }

    $sgVpcId = $sgResult.SecurityGroups[0].VpcId
    if ($sgVpcId -ne $Vpc) {
        throw "Security group $SecurityGroup belongs to VPC $sgVpcId, expected $Vpc"
    }
    Write-Success "SecurityGroup/VPC validation passed"
}

function Assert-AmiExists {
    param(
        [string]$ImageId,
        [string]$Profile,
        [string]$AwsRegion
    )

    Write-Info "Validating AMI exists and is available..."
    $amiResult = Invoke-AwsCli -Arguments @(
        "ec2", "describe-images",
        "--profile", $Profile,
        "--region", $AwsRegion,
        "--image-ids", $ImageId,
        "--output", "json"
    ) -AsJson

    if (-not $amiResult.Images -or $amiResult.Images.Count -eq 0) {
        throw "AMI not found: $ImageId"
    }

    $state = $amiResult.Images[0].State
    if ($state -ne "available") {
        throw "AMI $ImageId state is '$state' (must be 'available')"
    }

    Write-Success "AMI validation passed"
}

function Assert-KeyPairIfProvided {
    param(
        [string]$ProvidedKeyName,
        [string]$Profile,
        [string]$AwsRegion
    )

    if ([string]::IsNullOrWhiteSpace($ProvidedKeyName)) {
        return
    }

    Write-Info "Validating key pair exists..."
    $null = Invoke-AwsCli -Arguments @(
        "ec2", "describe-key-pairs",
        "--profile", $Profile,
        "--region", $AwsRegion,
        "--key-names", $ProvidedKeyName,
        "--output", "json"
    ) -AsJson
    Write-Success "Key pair validation passed"
}

function Assert-InstanceProfileIfProvided {
    param(
        [string]$ProfileName,
        [string]$Profile,
        [string]$AwsRegion
    )

    if ([string]::IsNullOrWhiteSpace($ProfileName)) {
        return
    }

    Write-Info "Validating IAM instance profile exists..."
    $null = Invoke-AwsCli -Arguments @(
        "iam", "get-instance-profile",
        "--profile", $Profile,
        "--region", $AwsRegion,
        "--instance-profile-name", $ProfileName,
        "--output", "json"
    ) -AsJson
    Write-Success "Instance profile validation passed"
}

function Get-NextSequenceStart {
    param(
        [string]$Prefix,
        [string]$Profile,
        [string]$AwsRegion
    )

    Write-Info "Scanning existing instance names for smart numbering..."
    $existing = Invoke-AwsCli -Arguments @(
        "ec2", "describe-instances",
        "--profile", $Profile,
        "--region", $AwsRegion,
        "--filters", "Name=tag:Name,Values=$Prefix-*", "Name=instance-state-name,Values=pending,running,stopping,stopped",
        "--query", "Reservations[].Instances[].Tags[?Key=='Name'].Value | []",
        "--output", "json"
    ) -AsJson

    $max = 0
    foreach ($name in $existing) {
        if ($name -match "^$([regex]::Escape($Prefix))-(\d+)$") {
            $n = [int]$Matches[1]
            if ($n -gt $max) {
                $max = $n
            }
        }
    }

    return ($max + 1)
}
try {
    Write-Info "Validating required values..."
    Require-Value -Name "VpcId" -Value $VpcId
    Require-Value -Name "SubnetId" -Value $SubnetId
    Require-Value -Name "SecurityGroupId" -Value $SecurityGroupId
    Require-Value -Name "AmiId" -Value $AmiId

    if ($InstanceCount -lt 1) {
        throw "InstanceCount must be at least 1"
    }

    if ($EbsGp3SizeGiB -lt 8) {
        throw "EbsGp3SizeGiB must be >= 8"
    }

    Write-Info "Checking AWS CLI availability..."
    $null = Get-Command aws -ErrorAction Stop

    Write-Info "Validating AWS profile '$AwsProfile' in region '$Region'..."
    $identity = Invoke-AwsCli -Arguments @(
        "sts", "get-caller-identity",
        "--profile", $AwsProfile,
        "--region", $Region,
        "--output", "json"
    ) -AsJson
    Write-Success "Authenticated as: $($identity.Arn)"

    Assert-ResourceCompatibility -Vpc $VpcId -Subnet $SubnetId -SecurityGroup $SecurityGroupId -Profile $AwsProfile -AwsRegion $Region
    Assert-AmiExists -ImageId $AmiId -Profile $AwsProfile -AwsRegion $Region
    Assert-KeyPairIfProvided -ProvidedKeyName $KeyName -Profile $AwsProfile -AwsRegion $Region
    Assert-InstanceProfileIfProvided -ProfileName $InstanceProfileName -Profile $AwsProfile -AwsRegion $Region

    $startSequence = Get-NextSequenceStart -Prefix $NamePrefix -Profile $AwsProfile -AwsRegion $Region
    Write-Success "Smart naming start number: $startSequence"

    Write-Info "Provisioning summary"
    Write-Host "  Profile:            $AwsProfile"
    Write-Host "  Region:             $Region"
    Write-Host "  Name Prefix:        $NamePrefix"
    Write-Host "  Instance Count:     $InstanceCount"
    Write-Host "  Instance Type:      $InstanceType"
    Write-Host "  VPC:                $VpcId"
    Write-Host "  Subnet:             $SubnetId"
    Write-Host "  Security Group:     $SecurityGroupId"
    Write-Host "  Public IP:          $EnablePublicIp"
    Write-Host "  Instance Profile:   $(if ($InstanceProfileName) { $InstanceProfileName } else { "<none>" })"
    Write-Host "  EBS gp3 Size (GiB): $EbsGp3SizeGiB"
    Write-Host "  AMI:                $AmiId"
    Write-Host "  Key Pair:           $(if ($KeyName) { $KeyName } else { "<none>" })"

    if (-not $NoPrompt) {
        $confirm = Read-Host "Proceed with instance creation? (yes/no)"
        if ($confirm -ne "yes") {
            Write-WarnMsg "Cancelled by user."
            exit 0
        }
    }

    $created = @()
    $failed = @()

    $baseTagSpec = @(
        @{
            ResourceType = "instance"
            Tags = @(
                @{ Key = "Name"; Value = "$NamePrefix-00" }
            )
        }
    ) | ConvertTo-Json -Depth 6 -Compress

    $baseBlockMappings = @(
        @{
            DeviceName = "/dev/xvda"
            Ebs = @{
                VolumeSize = $EbsGp3SizeGiB
                VolumeType = "gp3"
                DeleteOnTermination = $true
            }
        }
    ) | ConvertTo-Json -Depth 6 -Compress

    Assert-RunInstancesDryRun `
        -Profile $AwsProfile `
        -AwsRegion $Region `
        -ImageId $AmiId `
        -Type $InstanceType `
        -Subnet $SubnetId `
        -SecurityGroup $SecurityGroupId `
        -BlockMappings $baseBlockMappings `
        -TagSpec $baseTagSpec `
        -PublicIp $EnablePublicIp `
        -ProfileName $InstanceProfileName `
        -Ec2KeyName $KeyName

    for ($i = 0; $i -lt $InstanceCount; $i++) {
        $currentNumber = $startSequence + $i
        $suffix = "{0:D2}" -f $currentNumber
        $instanceName = "$NamePrefix-$suffix"

        Write-Info "Creating instance: $instanceName"

        $tagSpec = @(
            @{
                ResourceType = "instance"
                Tags = @(
                    @{ Key = "Name"; Value = $instanceName }
                )
            }
        ) | ConvertTo-Json -Depth 6 -Compress

        $blockMappings = @(
            @{
                DeviceName = "/dev/xvda"
                Ebs = @{
                    VolumeSize = $EbsGp3SizeGiB
                    VolumeType = "gp3"
                    DeleteOnTermination = $true
                }
            }
        ) | ConvertTo-Json -Depth 6 -Compress

        $clientToken = "{0}-{1}-{2}" -f $instanceName, (Get-Date -Format "yyyyMMddHHmmss"), ([guid]::NewGuid().ToString("N").Substring(0, 10))

        $cmd = @(
            "ec2", "run-instances",
            "--profile", $AwsProfile,
            "--region", $Region,
            "--image-id", $AmiId,
            "--instance-type", $InstanceType,
            "--subnet-id", $SubnetId,
            "--security-group-ids", $SecurityGroupId,
            "--block-device-mappings", $blockMappings,
            "--tag-specifications", $tagSpec,
            "--count", "1",
            "--client-token", $clientToken,
            "--output", "json"
        )

        if ($EnablePublicIp) {
            $cmd += "--associate-public-ip-address"
        }

        if (-not [string]::IsNullOrWhiteSpace($InstanceProfileName)) {
            $cmd += @("--iam-instance-profile", "Name=$InstanceProfileName")
        }

        if (-not [string]::IsNullOrWhiteSpace($KeyName)) {
            $cmd += @("--key-name", $KeyName)
        }

        try {
            $result = Invoke-AwsCli -Arguments $cmd -AsJson
            $instanceId = $result.Instances[0].InstanceId
            Write-Success "Created $instanceName => $instanceId"
            $created += [PSCustomObject]@{
                Name = $instanceName
                InstanceId = $instanceId
            }
        }
        catch {
            $errText = Get-ErrorText $_
            Write-Err "Failed to create ${instanceName}: $errText"
            $failed += $instanceName
        }
    }

    if ($WaitForRunning -and $created.Count -gt 0) {
        Write-Info "Waiting for created instances to reach 'running' state..."
        foreach ($item in $created) {
            try {
                $null = Invoke-AwsCli -Arguments @(
                    "ec2", "wait", "instance-running",
                    "--profile", $AwsProfile,
                    "--region", $Region,
                    "--instance-ids", $item.InstanceId
                )
                Write-Success "Instance running: $($item.InstanceId)"
            }
            catch {
                Write-WarnMsg "Wait failed for $($item.InstanceId): $($_.Exception.Message)"
            }
        }
    }

    Write-Host ""
    Write-Host "==================== RESULT ===================="
    Write-Host "Created: $($created.Count)"
    Write-Host "Failed : $($failed.Count)"

    if ($created.Count -gt 0) {
        Write-Host ""
        Write-Host "Created instances:"
        $created | Format-Table -AutoSize

        Write-Info "Fetching current instance state + IPs..."
        foreach ($item in $created) {
            try {
                $desc = Invoke-AwsCli -Arguments @(
                    "ec2", "describe-instances",
                    "--profile", $AwsProfile,
                    "--region", $Region,
                    "--instance-ids", $item.InstanceId,
                    "--output", "json"
                ) -AsJson
                $inst = $desc.Reservations[0].Instances[0]
                $pub = if ($inst.PublicIpAddress) { $inst.PublicIpAddress } else { "N/A" }
                Write-Host (" - {0} | {1} | state={2} | private={3} | public={4}" -f $item.Name, $item.InstanceId, $inst.State.Name, $inst.PrivateIpAddress, $pub)
            }
            catch {
                Write-WarnMsg "Could not fetch details for $($item.InstanceId)"
            }
        }
    }

    if ($failed.Count -gt 0) {
        Write-Host ""
        Write-Host "Failed instance names:"
        $failed | ForEach-Object { Write-Host " - $_" }
    }

    Write-Host "==============================================="
    Write-Success "Done."
}
catch {
    Write-Err $_.Exception.Message
    exit 1
}
