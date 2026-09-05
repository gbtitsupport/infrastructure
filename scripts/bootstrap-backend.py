#!/usr/bin/env python3
"""
Bootstrap the S3 bucket (and optionally DynamoDB table) that Terraform's
`backend "s3"` block depends on. Safe to run more than once — every step
checks for existence first and skips if it's already there.

Usage:
    # Exact bucket name:
    python3 bootstrap_backend.py \
        --bucket sa-lab-terraform-state-a15f0c2e \
        --region eu-west-1 \
        --table terraform-state-locks

    # Or let it generate a unique name for you (prefix + random suffix):
    python3 bootstrap_backend.py \
        --bucket-prefix sa-lab-terraform-state \
        --region eu-west-1

    # Skip the DynamoDB table if you're using Terraform 1.10+ native S3 locking:
    python3 bootstrap_backend.py --bucket sa-lab-terraform-state-a15f0c2e \
        --region eu-west-1 --no-dynamodb

IMPORTANT if you use --bucket-prefix: the generated name is random every
run. It's only safe to auto-generate on the FIRST run — after that, copy
the printed bucket name into your `backend "s3"` blocks (Terraform backend
config can't use variables, it must be a literal string) and pass that
exact name back in with --bucket on any future run of this script. Running
with --bucket-prefix again later creates a second, unrelated bucket rather
than reusing the first one.

Requires: boto3 (pip install boto3), and AWS credentials available via the
normal boto3 credential chain (env vars, a named profile, instance role,
or the same OIDC role your pipeline assumes if you run this from CI).
"""
import argparse
import os
import secrets
import sys

import boto3
from botocore.exceptions import ClientError


def generate_bucket_name(prefix):
    suffix = secrets.token_hex(4)  # 8 hex chars, e.g. "a15f0c2e"
    return f"{prefix}-{suffix}"


def bucket_exists(s3, bucket):
    try:
        s3.head_bucket(Bucket=bucket)
        return True
    except ClientError as e:
        status = e.response.get("ResponseMetadata", {}).get("HTTPStatusCode")
        if status == 404:
            return False
        raise


def create_bucket(s3, bucket, region):
    if bucket_exists(s3, bucket):
        print(f"[skip] bucket '{bucket}' already exists")
        return

    print(f"[create] bucket '{bucket}' in {region}")
    if region == "us-east-1":
        # us-east-1 is the one region that rejects a LocationConstraint
        s3.create_bucket(Bucket=bucket)
    else:
        s3.create_bucket(
            Bucket=bucket,
            CreateBucketConfiguration={"LocationConstraint": region},
        )

    waiter = s3.get_waiter("bucket_exists")
    waiter.wait(Bucket=bucket)


def configure_bucket(s3, bucket):
    print(f"[configure] versioning on '{bucket}'")
    s3.put_bucket_versioning(
        Bucket=bucket,
        VersioningConfiguration={"Status": "Enabled"},
    )

    print(f"[configure] default encryption on '{bucket}'")
    s3.put_bucket_encryption(
        Bucket=bucket,
        ServerSideEncryptionConfiguration={
            "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
        },
    )

    print(f"[configure] blocking public access on '{bucket}'")
    s3.put_public_access_block(
        Bucket=bucket,
        PublicAccessBlockConfiguration={
            "BlockPublicAcls": True,
            "IgnorePublicAcls": True,
            "BlockPublicPolicy": True,
            "RestrictPublicBuckets": True,
        },
    )


def table_exists(dynamodb, table):
    try:
        dynamodb.describe_table(TableName=table)
        return True
    except ClientError as e:
        if e.response["Error"]["Code"] == "ResourceNotFoundException":
            return False
        raise


def create_lock_table(dynamodb, table):
    if table_exists(dynamodb, table):
        print(f"[skip] DynamoDB table '{table}' already exists")
        return

    print(f"[create] DynamoDB table '{table}'")
    dynamodb.create_table(
        TableName=table,
        AttributeDefinitions=[{"AttributeName": "LockID", "AttributeType": "S"}],
        KeySchema=[{"AttributeName": "LockID", "KeyType": "HASH"}],
        BillingMode="PAY_PER_REQUEST",
    )

    waiter = dynamodb.get_waiter("table_exists")
    waiter.wait(TableName=table)
    print(f"[done] table '{table}' active")


def generate_key():
    suffix = secrets.token_hex(4) 
    return f"{suffix}.terraform.tfstate"


def main():
    parser = argparse.ArgumentParser(description="Bootstrap a Terraform S3 backend.")
    parser.add_argument("--bucket", default=None, help="Exact S3 bucket name to use/create")
    parser.add_argument(
        "--bucket-prefix",
        default=None,
        help="Auto-generate the bucket name as '<prefix>-<random suffix>' (mutually exclusive with --bucket)",
    )
    parser.add_argument("--region", required=True, help="AWS region, e.g. eu-west-1")
    parser.add_argument("--table", default="terraform-state-locks", help="DynamoDB lock table name")
    parser.add_argument(
        "--no-dynamodb",
        action="store_true",
        help="Skip creating the DynamoDB lock table (use with Terraform 1.10+ native S3 locking)",
    )
    parser.add_argument("--profile", default=None, help="Named AWS CLI profile to use (optional)")
    args = parser.parse_args()

    if bool(args.bucket) == bool(args.bucket_prefix):
        print("Pass exactly one of --bucket or --bucket-prefix.", file=sys.stderr)
        sys.exit(1)

    bucket_name = args.bucket or generate_bucket_name(args.bucket_prefix)
    if args.bucket_prefix:
        print(f"[generated] bucket name: {bucket_name}")
        print("[!] Save this name — reuse it with --bucket on every future run.\n")

    session = boto3.Session(profile_name=args.profile, region_name=args.region)
    s3 = session.client("s3")

    try:
        create_bucket(s3, bucket_name, args.region)
        configure_bucket(s3, bucket_name)

        if not args.no_dynamodb:
            dynamodb = session.client("dynamodb")
            create_lock_table(dynamodb, args.table)
        else:
            print("[skip] DynamoDB table creation skipped (--no-dynamodb)")

    except ClientError as e:
        print(f"AWS error: {e}", file=sys.stderr)
        sys.exit(1)

    # If running inside a GitHub Actions step, expose the bucket name as a
    # step output (e.g. `steps.bootstrap.outputs.bucket_name`) so downstream
    # jobs/steps can pick it up without you copy-pasting it by hand.
    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a") as f:
            f.write(f"bucket_name={bucket_name}\n")


    unqiue_key = generate_key()

    print("\nBootstrap complete. Your backend block:\n")
    print("terraform {")
    print('  backend "s3" {')
    print(f'    bucket         = "{bucket_name}"')
    print(f'    key            = "{unqiue_key}/terraform.tfstate"')
    print(f'    region         = "{args.region}"')
    if not args.no_dynamodb:
        print(f'    dynamodb_table = "{args.table}"')
    print("    encrypt        = true")
    print("  }")
    print("}")


if __name__ == "__main__":
    main()