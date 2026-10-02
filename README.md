# Manual Review: Inventory Reporting Service

**20 minutes. No AI assistance**, including chat, agents, AI search answers, and editor AI completion. You may read the code, take notes, use local inspection commands, and consult official documentation directly. Do not deploy infrastructure or call AWS during this exercise.

## Situation

A teammate has prepared a container-based AWS Lambda job. An operator submits a run through `invoke.py`. The job inventories an S3 prefix, records the result in PostgreSQL, and publishes a JSON report to a separate S3 bucket. Retry logic has been added to make the service resilient to transient failures.

The teammate considers it ready for deployment. Review the implementation across file boundaries and decide whether you agree.

## Intended behavior

- Count every object under `exports/`. A typical run covers about 2,500 objects; an empty prefix is valid.
- Record the run ID, object count, and total bytes in PostgreSQL and publish the same result to `reports/<run_id>.json`.
- A logical run may be submitted again with the **same run ID**, including while its previous invocation is still running. It must not create duplicate database records or report success with an unpublished report.
- Recover from transient failures within a bounded time. Permanent failures must remain visible to the caller. A failed or incomplete operation must not look like a successful empty inventory.
- Connect to PostgreSQL on its configured port using TLS with server identity verification. Only this Lambda's security group should gain database access through the rules managed here.
- Grant only the AWS and network access needed to collect inventory, access the database credentials, publish reports, and emit logs. Do not modify source objects.
- Keep reports for at least 90 days, including when application infrastructure is retired. Early data deletion requires a separate explicit operation.
- Apply approved image and environment configuration updates through Terraform after the initial deployment.
- Keep database password values out of Terraform state and deployment outputs; retrieve them only at runtime.

## Files

| File | Role |
|---|---|
| [main.tf](main.tf) | Lambda, environment, report bucket, IAM |
| [networking.tf](networking.tf) | VPC inputs and security group rules |
| [operations.tf](operations.tf) | Storage lifecycle and operational outputs |
| [app.py](app.py) | Inventory, database connection, transaction, publication, retries |
| [schema.sql](schema.sql) | Existing database table |
| [invoke.py](invoke.py) | Operator's synchronous invocation and retry logic |
| [Dockerfile](Dockerfile), [requirements.txt](requirements.txt) | Image packaging and entry point |

Example operator command, for reading only:

```bash
python3 invoke.py interview-s3-inventory interview-001
```

## Environment facts

- Standard commercial AWS account, region `eu-central-1`. The source bucket and VPC already exist. The report bucket name is available.
- PostgreSQL already runs on **TCP 5432**, in the supplied VPC, with no public endpoint. `db_host` is its valid DNS endpoint. The supplied DB security group is attached to it; no other rules grant client access. `schema.sql` has been applied, and the application user can insert into the table and use its identity sequence.
- The database currently accepts both TLS and plaintext connections. The organization's client policy requires TLS and verification of the server certificate and hostname. A trusted CA bundle is available at `/etc/pki/tls/certs/ca-bundle.crt` in the prepared image.
- The secret identified by `db_secret_arn` exists and contains `username` and `password`; it uses the standard Secrets Manager managed encryption key. The application database is named `inventory`.
- The supplied subnets are private, DNS and routes are correct, and NACLs allow the required traffic. Working endpoints provide HTTPS access to S3 and Secrets Manager. There are no additional security groups attached to the Lambda or database.
- The image is built from this Dockerfile for `linux/amd64` and available in ECR in the same account and region. `image_uri` points to its digest. ECR access is configured. The AWS base image supplies Boto3 and Botocore; the listed Psycopg dependency is available.
- The operator has invocation permissions and uses synchronous invocation. There is no API Gateway or event-source retry mechanism. Read all retry and timeout settings shown in the files; they are part of the review.
- Run IDs are trusted strings. Source objects remain unchanged across attempts for a logical run. A healthy run takes 2–15 seconds. Transient database and AWS failures are possible.
- S3 buckets use SSE-S3. No additional policies, permission boundaries, retention mechanisms, unique indexes, triggers, or reconciliation jobs compensate for the supplied code.

## What to explain

Trace a run from the caller through the container, network, credentials, database, and S3 report. Identify defects you can substantiate, explain their consequences, and prioritize the changes needed before deployment.

For the most important findings, identify the relevant code, propose a correction, and explain how you would verify it. Separate definite defects from assumptions and optional improvements. Continue tracing later stages even if an earlier issue prevents startup or connection.

You do not need to fix the code or find every issue. Use the final 5 minutes to present your review. Reasoning, interactions between failures, and prioritization matter more than counting findings.
