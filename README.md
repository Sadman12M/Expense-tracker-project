# Expense Tracker — Serverless AWS Application

A full-stack personal expense tracker built entirely on serverless AWS infrastructure, provisioned end-to-end with Terraform. Users sign up, log in through Amazon Cognito, and track expenses that persist in DynamoDB.

**Live demo:** `https://d3bc09xnpkrjrx.cloudfront.net`

![Dashboard screenshot]
<img width="1916" height="917" alt="image" src="https://github.com/user-attachments/assets/994449db-612c-441a-a87b-c1bf7389db4d" />



---


## Why I built this

I built this project to get hands-on experience designing, deploying, and managing a real cloud application instead of only learning AWS and Terraform through tutorials. It gave me practical experience with authentication, APIs, databases, serverless services, and Infrastructure as Code.
---

## Architecture
<img width="1717" height="800" alt="Screenshot 2026-09-29 180426" src="https://github.com/user-attachments/assets/7b96ee73-ea56-4c1a-8511-b0040b66f03b" />

```

**Request flow:**
1. Browser loads the static site from CloudFront, which caches and serves files from S3 over HTTPS
2. Unauthenticated users are redirected to the Cognito Hosted UI to sign up or log in
3. Cognito returns an authorization code, which the frontend exchanges for a JWT (ID token)
4. Every API call includes `Authorization: Bearer <token>`
5. API Gateway validates the JWT against Cognito before invoking any Lambda function
6. Lambda reads the authenticated user's ID from the verified token claims — never from the request body — so one user can never read or modify another user's data
7. Lambda reads/writes DynamoDB, scoped to that user's partition key

---

## Tech stack

Layer            |    Technology
Authentication   |    Amazon Cognito
API              |    API Gateway HTTP API
Backend          |    AWS Lambda + python 3.12
Database         |    Amazon DynamoDB
Frontend Hosting |    Amazon S3
CDN              |    Amazon CloudFront
Monitoring       |    Amazon CloudWatch
Infrastructure   |    Terraform 
---

## Why these choices

**Auth:** Went with Cognito for the user pool + hosted login UI, mainly so I don't have to build and secure my own auth from scratch. It also handles JWT issuance for me.

**API:** Used API Gateway, but the HTTP API type specifically, not REST API — it's cheaper and simpler, and it has JWT authorizer support built in, so I didn't need to write a custom authorizer.

**Backend:** Didn't want something running 24/7 for an app like this, so I went serverless — Lambda with Python. It's pay-per-request, way cheaper than keeping an EC2 instance up for something that's barely used.

**Database:** DynamoDB, since this is NoSQL and a user's list of expenses doesn't really need the relational structure of something like RDS. Also scales to basically zero cost when nobody's using it.

**Frontend hosting:** S3 for static hosting, CloudFront in front of it. Mainly needed CloudFront for HTTPS (S3 alone is HTTP only), and it also caches at edge locations so it loads faster than hitting S3 directly.

**Monitoring:** CloudWatch, just for log groups per Lambda function and some basic alarms so failures don't go unnoticed.

**Terraform:** Could've just clicked through the console for all of this, but that's not reproducible — no history of what changed, no way to rebuild the exact same setup, nothing to review before it goes live. Actually proved this myself: partway through the project I accidentally ran `terraform destroy` on the whole stack, and got everything back with one `terraform apply`. That recovery just isn't possible if you built it by hand in the console.

---

## Design decisions & cost tradeoffs

- Lambda over EC2 — no continuously running server.
- DynamoDB on-demand — pay based on usage; no provisioned capacity.
- HTTP API over REST API — simpler and lower-cost API Gateway option.
- S3 + CloudFront — static frontend hosting with CDN and HTTPS.
- CloudFront PriceClass_100 — reduces CDN cost by limiting edge locations.
- 14-day CloudWatch retention — limits log storage costs.
- API Gateway throttling — helps control excessive requests and Lambda usage.
- Terraform — reproducible infrastructure and easier teardown/redeployment.

---

## Engineering challenges and how I solved them

None of these were caught by a tutorial — they only surfaced once multiple real AWS services were wired together and actually deployed. Each one required tracing a symptom back through the request path to find where two services disagreed about a contract, not just retrying until something worked:

| Symptom | Root cause | Fix |
|---|---|---|
| Cognito `invalid_request` error on login | `callback_urls` in Cognito hardcoded an old CloudFront domain from a previous deploy | Reference `aws_cloudfront_distribution.frontend.domain_name` directly instead of a literal string |
| Browser blocked API calls with a CORS error | API Gateway's `allow_origins` hardcoded an old CloudFront URL | Same fix — derive it from the CloudFront resource |
| Frontend fix didn't appear after redeploying | CloudFront was serving a cached copy of `script.js` | Set `cache_control = "no-cache"` on S3 objects and use the `CachingOptimized` managed cache policy so CloudFront revalidates on every request |
| Every API call returned `401 Unauthorized` even with a valid, unexpired token | Lambda read `event["requestContext"]["authorizer"]["claims"]`, which is the **REST API** shape. HTTP API nests claims one level deeper | Changed to `event["requestContext"]["authorizer"]["jwt"]["claims"]` in all three functions |
| The 401 above was hard to diagnose | A generic `except KeyError: return 401` in each Lambda function caught *any* code bug and misreported it as an auth failure | Isolated the JWT claim lookup into its own try/except, separate from business logic errors |
| `terraform plan` suddenly showed 34 resources to add on a project that was already deployed | Had run `terraform destroy` earlier in the session and forgotten | Confirmed via `terraform state list` (empty) before reapplying, to avoid creating duplicate/orphaned resources |

---

## Project structure

```
expense-tracker/
├── main.tf                  # Provider config, root module call
├── variables.tf              # aws_region, project_name
├── outputs.tf                # Root-level outputs (URLs, IDs, ARNs)
├── modules/
│   ├── variables.tf
│   ├── cognito.tf            # User pool, app client, hosted UI domain
│   ├── dynamodb.tf           # expenses table
│   ├── lambda.tf              # IAM role/policy, 3 Lambda functions
│   ├── api_gateway.tf        # HTTP API, JWT authorizer, routes
│   ├── s3.tf                  # Frontend bucket, generated config.js
│   ├── cloudfront.tf          # CDN distribution
│   └── cloudwatch.tf          # Log groups, error alarms
├── lambda_functions/
│   ├── add_expense.py
│   ├── get_expenses.py
│   └── delete_expense.py
└── frontend/
    ├── index.html
    ├── style.css
    └── script.js              # config.js is generated by Terraform
```

---

## API reference

All routes require `Authorization: Bearer <id_token>`.

| Method | Path | Description | Body |
|---|---|---|---|
| `POST` | `/expenses` | Create an expense | `{ amount, category, description, date }` |
| `GET` | `/expenses` | List the authenticated user's expenses | — (optional `?category=` query filter) |
| `DELETE` | `/expenses/{id}` | Delete one expense by ID | — |

`category` must be one of: `Food`, `Transport`, `Rent`, `Utilities`, `Other`.

---

## Deploying this yourself

**Prerequisites:** Terraform ≥ 1.9, an AWS account, AWS CLI credentials configured (an IAM user, not root).

```bash
git clone <this-repo>
cd expense-tracker
terraform init
terraform apply
```

Terraform will output the CloudFront URL, API Gateway URL, and Cognito details. Open the CloudFront URL to use the app — no manual configuration needed, since `config.js` is generated automatically.

```bash
terraform destroy
```
tears down all resources.

---

## Known limitations / what I'd add for production

- **Terraform state is local**, not stored remotely. A production setup would use an S3 backend with DynamoDB state locking.
- **No CI/CD** — deployment is manual (`terraform apply`). A GitHub Actions pipeline running `plan` on PRs and `apply` on merge to `main` would be the next step.
- **S3 bucket is public** rather than private-behind-CloudFront via Origin Access Control (OAC) — a stronger security posture for a production app.
- **No billing alarm** — a CloudWatch billing/budget alarm would catch unexpected cost before it grows.
- **CloudWatch alarms have no notification target** — they change state but don't alert anyone; wiring them to an SNS topic with email/Slack would close that gap.
- **No automated tests** — No automated tests yet; testing was done manually.
- **Login Session persists** - After the first login, users may not be asked for their password again untill the cognito session expires 
  
