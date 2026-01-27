#!/bin/bash

################################################################################
# AWS DevOps Agent - Test Execution Scripts
# These scripts set up failure scenarios and validate agent responses
################################################################################

# Configuration
REPO_NAME="devops-agent-test"
GITHUB_ORG="your-org"
AWS_REGION="us-east-1"
ECS_CLUSTER="test-cluster"
TEST_RESULTS_DIR="./test-results"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize test environment
setup_test_environment() {
    echo -e "${GREEN}Setting up test environment...${NC}"
    mkdir -p $TEST_RESULTS_DIR
    mkdir -p test-repo/.github/workflows
    cd test-repo || exit
}

# Cleanup function
cleanup() {
    echo -e "${YELLOW}Cleaning up test artifacts...${NC}"
    cd ..
    # Optionally remove test repo
}

################################################################################
# TEST 1.1: GitHub Actions YAML Syntax Error
################################################################################

test_1_1_yaml_syntax_error() {
    echo -e "${GREEN}=== TEST 1.1: YAML Syntax Error ===${NC}"
    
    # Create workflow with intentional syntax error
    cat > .github/workflows/build.yml << 'EOF'
name: Build Test
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
      - name: Build  # WRONG INDENTATION - Should be at same level as 'uses'
        run: echo "Building application"
      - name: Test
        run: echo "Running tests"
EOF

    # Commit and push
    git add .github/workflows/build.yml
    git commit -m "TEST 1.1: Add workflow with YAML syntax error"
    git push origin main
    
    # Wait for workflow to fail
    echo "Waiting for workflow to execute..."
    sleep 10
    
    # Get workflow run ID
    WORKFLOW_RUN_ID=$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')
    
    # Save logs for agent analysis
    gh run view $WORKFLOW_RUN_ID --log > $TEST_RESULTS_DIR/test_1_1_workflow_log.txt
    
    # Test agent query
    echo -e "${YELLOW}Query for Agent:${NC}"
    echo "Why is my build workflow failing?"
    
    # Expected patterns in agent response
    cat > $TEST_RESULTS_DIR/test_1_1_expected.txt << 'EOF'
EXPECTED AGENT RESPONSE SHOULD CONTAIN:
- "YAML syntax error" or "parsing failure"
- ".github/workflows/build.yml"
- "indentation" or "line 8"
- Specific fix suggestion
- Reference to the 'name' key alignment issue
EOF

    echo -e "${GREEN}Test 1.1 setup complete. Check $TEST_RESULTS_DIR/${NC}"
}

################################################################################
# TEST 1.2: npm Dependency Failure
################################################################################

test_1_2_npm_dependency_failure() {
    echo -e "${GREEN}=== TEST 1.2: npm Dependency Failure ===${NC}"
    
    # Create package.json with invalid version
    cat > package.json << 'EOF'
{
  "name": "test-app",
  "version": "1.0.0",
  "description": "Test application for DevOps agent",
  "dependencies": {
    "express": "99.99.99",
    "lodash": "^4.17.21"
  },
  "devDependencies": {
    "jest": "^29.0.0"
  }
}
EOF

    # Create workflow that runs npm install
    cat > .github/workflows/npm-build.yml << 'EOF'
name: NPM Build
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Node
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      - name: Install dependencies
        run: npm install
      - name: Run tests
        run: npm test
EOF

    # Commit and push
    git add package.json .github/workflows/npm-build.yml
    git commit -m "TEST 1.2: Add invalid npm dependency"
    git push origin main
    
    sleep 10
    
    WORKFLOW_RUN_ID=$(gh run list --workflow=npm-build.yml --limit 1 --json databaseId --jq '.[0].databaseId')
    gh run view $WORKFLOW_RUN_ID --log > $TEST_RESULTS_DIR/test_1_2_workflow_log.txt
    
    echo -e "${YELLOW}Query for Agent:${NC}"
    echo "npm install is failing in my GitHub Actions workflow"
    
    cat > $TEST_RESULTS_DIR/test_1_2_expected.txt << 'EOF'
EXPECTED AGENT RESPONSE SHOULD CONTAIN:
- Identifies "express@99.99.99" as the problem
- States "version does not exist"
- Suggests valid version like "express@^4.18.0"
- Provides npm command to check available versions
- References the "Install dependencies" step failure
EOF

    echo -e "${GREEN}Test 1.2 setup complete${NC}"
}

################################################################################
# TEST 1.3: Python Dependency Failure
################################################################################

test_1_3_python_dependency_failure() {
    echo -e "${GREEN}=== TEST 1.3: Python Dependency Failure ===${NC}"
    
    # Create requirements.txt with invalid version
    cat > requirements.txt << 'EOF'
requests==99.99.99
boto3==1.26.137
flask==2.3.0
EOF

    # Create workflow
    cat > .github/workflows/python-build.yml << 'EOF'
name: Python Build
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - name: Install dependencies
        run: pip install -r requirements.txt
      - name: Run tests
        run: python -m pytest tests/
EOF

    git add requirements.txt .github/workflows/python-build.yml
    git commit -m "TEST 1.3: Add invalid Python dependency"
    git push origin main
    
    sleep 10
    
    WORKFLOW_RUN_ID=$(gh run list --workflow=python-build.yml --limit 1 --json databaseId --jq '.[0].databaseId')
    gh run view $WORKFLOW_RUN_ID --log > $TEST_RESULTS_DIR/test_1_3_workflow_log.txt
    
    echo -e "${YELLOW}Query for Agent:${NC}"
    echo "pip install is failing, what's wrong with my dependencies?"
    
    cat > $TEST_RESULTS_DIR/test_1_3_expected.txt << 'EOF'
EXPECTED AGENT RESPONSE SHOULD CONTAIN:
- Identifies "requests==99.99.99" as invalid
- States version does not exist
- Provides valid version suggestion (e.g., "requests==2.31.0")
- Suggests using flexible versioning (e.g., "requests>=2.28.0")
- References pip error output
EOF

    echo -e "${GREEN}Test 1.3 setup complete${NC}"
}

################################################################################
# TEST 2.2: GitHub → ECS Deployment Failure
################################################################################

test_2_2_ecs_deployment_failure() {
    echo -e "${GREEN}=== TEST 2.2: ECS Deployment Failure ===${NC}"
    
    # Create task definition with wrong environment variable
    cat > task-definition.json << 'EOF'
{
  "family": "test-api-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "name": "api-container",
      "image": "nginx:latest",
      "portMappings": [
        {
          "containerPort": 80,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "DATABASE_URL",
          "value": "postgres://wrong-host.internal:5432/mydb"
        },
        {
          "name": "REDIS_URL",
          "value": "redis://localhost:6379"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/test-api",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
EOF

    # Create GitHub Actions workflow for ECS deployment
    cat > .github/workflows/deploy-ecs.yml << 'EOF'
name: Deploy to ECS
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Register task definition
        id: task-def
        run: |
          TASK_DEF_ARN=$(aws ecs register-task-definition \
            --cli-input-json file://task-definition.json \
            --query 'taskDefinition.taskDefinitionArn' \
            --output text)
          echo "task-def-arn=$TASK_DEF_ARN" >> $GITHUB_OUTPUT
      
      - name: Update ECS service
        run: |
          aws ecs update-service \
            --cluster test-cluster \
            --service test-api-service \
            --task-definition ${{ steps.task-def.outputs.task-def-arn }} \
            --force-new-deployment
      
      - name: Wait for deployment
        run: |
          aws ecs wait services-stable \
            --cluster test-cluster \
            --services test-api-service
EOF

    git add task-definition.json .github/workflows/deploy-ecs.yml
    git commit -m "TEST 2.2: Deploy to ECS with wrong DB config"
    COMMIT_SHA=$(git rev-parse HEAD)
    git push origin main
    
    echo "Deployment commit SHA: $COMMIT_SHA"
    
    # Wait for deployment
    sleep 30
    
    # Get deployment details
    WORKFLOW_RUN_ID=$(gh run list --workflow=deploy-ecs.yml --limit 1 --json databaseId --jq '.[0].databaseId')
    gh run view $WORKFLOW_RUN_ID --log > $TEST_RESULTS_DIR/test_2_2_workflow_log.txt
    
    # Get ECS task failures
    aws ecs describe-services \
        --cluster test-cluster \
        --services test-api-service \
        > $TEST_RESULTS_DIR/test_2_2_ecs_service.json
    
    # Get stopped tasks
    STOPPED_TASKS=$(aws ecs list-tasks \
        --cluster test-cluster \
        --service-name test-api-service \
        --desired-status STOPPED \
        --query 'taskArns[0]' \
        --output text)
    
    if [ "$STOPPED_TASKS" != "None" ]; then
        aws ecs describe-tasks \
            --cluster test-cluster \
            --tasks $STOPPED_TASKS \
            > $TEST_RESULTS_DIR/test_2_2_ecs_stopped_task.json
    fi
    
    # Get CloudWatch logs
    aws logs tail /ecs/test-api \
        --since 10m \
        --format short \
        > $TEST_RESULTS_DIR/test_2_2_cloudwatch_logs.txt
    
    echo -e "${YELLOW}Query for Agent:${NC}"
    echo "My ECS deployment from GitHub Actions is failing. The workflow succeeded but the tasks won't start."
    
    cat > $TEST_RESULTS_DIR/test_2_2_expected.txt << 'EOF'
EXPECTED AGENT RESPONSE SHOULD CONTAIN:
- Links GitHub workflow run to ECS deployment
- Identifies the commit SHA
- Shows ECS task exit/stop reason
- Extracts container logs showing database connection failure
- Points to DATABASE_URL environment variable issue
- Suggests verification steps for DB endpoint
- Provides rollback command with previous task definition
- Timeline showing deployment time vs failure time
EOF

    # Create metadata file for agent context
    cat > $TEST_RESULTS_DIR/test_2_2_metadata.json << EOF
{
  "test_id": "2.2",
  "github_workflow_run_id": "$WORKFLOW_RUN_ID",
  "commit_sha": "$COMMIT_SHA",
  "ecs_cluster": "test-cluster",
  "ecs_service": "test-api-service",
  "deployment_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "expected_failure": "Database connection timeout"
}
EOF

    echo -e "${GREEN}Test 2.2 setup complete${NC}"
}

################################################################################
# TEST 2.3: Lambda Deployment with Memory Issue
################################################################################

test_2_3_lambda_memory_failure() {
    echo -e "${GREEN}=== TEST 2.3: Lambda Memory Failure ===${NC}"
    
    # Create Lambda function code that uses lots of memory
    cat > lambda_function.py << 'EOF'
import json

def lambda_handler(event, context):
    # Intentionally consume memory
    large_list = []
    for i in range(10000000):  # Will exceed 128MB
        large_list.append({'data': 'x' * 1000, 'index': i})
    
    return {
        'statusCode': 200,
        'body': json.dumps('Success')
    }
EOF

    # Create deployment workflow
    cat > .github/workflows/deploy-lambda.yml << 'EOF'
name: Deploy Lambda
on: [push]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Package Lambda
        run: |
          zip function.zip lambda_function.py
      
      - name: Deploy Lambda
        run: |
          # Update or create function
          aws lambda update-function-code \
            --function-name test-api-handler \
            --zip-file fileb://function.zip || \
          aws lambda create-function \
            --function-name test-api-handler \
            --runtime python3.11 \
            --role arn:aws:iam::123456789012:role/lambda-role \
            --handler lambda_function.lambda_handler \
            --zip-file fileb://function.zip \
            --memory-size 128 \
            --timeout 30
      
      - name: Test Lambda
        run: |
          aws lambda invoke \
            --function-name test-api-handler \
            --payload '{}' \
            response.json
          cat response.json
EOF

    git add lambda_function.py .github/workflows/deploy-lambda.yml
    git commit -m "TEST 2.3: Deploy Lambda with insufficient memory"
    git push origin main
    
    sleep 15
    
    WORKFLOW_RUN_ID=$(gh run list --workflow=deploy-lambda.yml --limit 1 --json databaseId --jq '.[0].databaseId')
    gh run view $WORKFLOW_RUN_ID --log > $TEST_RESULTS_DIR/test_2_3_workflow_log.txt
    
    # Get Lambda logs
    aws logs tail /aws/lambda/test-api-handler \
        --since 5m \
        --format short \
        > $TEST_RESULTS_DIR/test_2_3_lambda_logs.txt
    
    echo -e "${YELLOW}Query for Agent:${NC}"
    echo "Lambda function deployed from GitHub but it's timing out when invoked"
    
    cat > $TEST_RESULTS_DIR/test_2_3_expected.txt << 'EOF'
EXPECTED AGENT RESPONSE SHOULD CONTAIN:
- Identifies Lambda memory exhaustion
- Shows CloudWatch log with "Max Memory Used: 127 MB" near "Memory Size: 128 MB"
- Links deployment from GitHub Actions
- Suggests increasing memory allocation
- Provides AWS CLI command to update memory size
- Explains memory vs timeout issue
EOF

    echo -e "${GREEN}Test 2.3 setup complete${NC}"
}

################################################################################
# TEST 3.1: Missing GitHub Secret
################################################################################

test_3_1_missing_github_secret() {
    echo -e "${GREEN}=== TEST 3.1: Missing GitHub Secret ===${NC}"
    
    echo -e "${YELLOW}Manual step required:${NC}"
    echo "1. Go to: https://github.com/$GITHUB_ORG/$REPO_NAME/settings/secrets/actions"
    echo "2. DELETE the secret: AWS_ACCESS_KEY_ID"
    echo "3. Press Enter when ready to continue..."
    read -r
    
    # Create workflow that requires AWS credentials
    cat > .github/workflows/aws-access.yml << 'EOF'
name: AWS Access Test
on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: us-east-1
        run: |
          aws sts get-caller-identity
      
      - name: List S3 buckets
        run: |
          aws s3 ls
EOF

    git add .github/workflows/aws-access.yml
    git commit -m "TEST 3.1: Test with missing AWS secret"
    git push origin main
    
    sleep 10
    
    WORKFLOW_RUN_ID=$(gh run list --workflow=aws-access.yml --limit 1 --json databaseId --jq '.[0].databaseId')
    gh run view $WORKFLOW_RUN_ID --log > $TEST_RESULTS_DIR/test_3_1_workflow_log.txt
    
    echo -e "${YELLOW}Query for Agent:${NC}"
    echo "AWS commands are failing in my GitHub Actions workflow"
    
    cat > $TEST_RESULTS_DIR/test_3_1_expected.txt << 'EOF'
EXPECTED AGENT RESPONSE SHOULD CONTAIN:
- Identifies authentication failure
- Mentions AWS_ACCESS_KEY_ID environment variable is empty/not set
- States this indicates missing GitHub Secret
- Provides steps to add secret in repository settings
- Warns against committing credentials to repository
EOF

    echo -e "${GREEN}Test 3.1 setup complete${NC}"
    echo -e "${YELLOW}Remember to restore the AWS_ACCESS_KEY_ID secret after testing${NC}"
}

################################################################################
# TEST 3.2: Invalid AWS Credentials
################################################################################

test_3_2_invalid_aws_credentials() {
    echo -e "${GREEN}=== TEST 3.2: Invalid AWS Credentials ===${NC}"
    
    echo -e "${YELLOW}Manual step required:${NC}"
    echo "1. Go to: https://github.com/$GITHUB_ORG/$REPO_NAME/settings/secrets/actions"
    echo "2. UPDATE AWS_ACCESS_KEY_ID with invalid value: AKIAINVALIDKEY123456"
    echo "3. Press Enter when ready to continue..."
    read -r
    
    # Same workflow as 3.1
    git commit --allow-empty -m "TEST 3.2: Test with invalid AWS credentials"
    git push origin main
    
    sleep 10
    
    WORKFLOW_RUN_ID=$(gh run list --workflow=aws-access.yml --limit 1 --json databaseId --jq '.[0].databaseId')
    gh run view $WORKFLOW_RUN_ID --log > $TEST_RESULTS_DIR/test_3_2_workflow_log.txt
    
    echo -e "${YELLOW}Query for Agent:${NC}"
    echo "Getting InvalidClientTokenId error in GitHub Actions"
    
    cat > $TEST_RESULTS_DIR/test_3_2_expected.txt << 'EOF'
EXPECTED AGENT RESPONSE SHOULD CONTAIN:
- Identifies "InvalidClientTokenId" error
- States credentials are invalid or expired
- Lists common causes (rotated key, deleted user, expiration)
- Provides steps to generate new access key in IAM
- Gives instructions to update GitHub Secrets
- Suggests testing credentials locally with 'aws sts get-caller-identity'
EOF

    echo -e "${GREEN}Test 3.2 setup complete${NC}"
    echo -e "${YELLOW}Remember to restore valid AWS credentials after testing${NC}"
}

################################################################################
# TEST 4.2: Docker Build Failure
################################################################################

test_4_2_docker_build_failure() {
    echo -e "${GREEN}=== TEST 4.2: Docker Build Failure ===${NC}"
    
    # Create Dockerfile with syntax error
    cat > Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 3000

# Syntax error - missing comma in CMD
CMD ["npm" "start"]
EOF

    # Create workflow that builds Docker image
    cat > .github/workflows/docker-build.yml << 'EOF'
name: Docker Build
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2
      
      - name: Build Docker image
        run: |
          docker build -t test-app:latest .
      
      - name: Test container
        run: |
          docker run --rm test-app:latest
EOF

    git add Dockerfile .github/workflows/docker-build.yml
    git commit -m "TEST 4.2: Add Dockerfile with syntax error"
    git push origin main
    
    sleep 15
    
    WORKFLOW_RUN_ID=$(gh run list --workflow=docker-build.yml --limit 1 --json databaseId --jq '.[0].databaseId')
    gh run view $WORKFLOW_RUN_ID --log > $TEST_RESULTS_DIR/test_4_2_workflow_log.txt
    
    echo -e "${YELLOW}Query for Agent:${NC}"
    echo "Docker build is failing in GitHub Actions"
    
    cat > $TEST_RESULTS_DIR/test_4_2_expected.txt << 'EOF'
EXPECTED AGENT RESPONSE SHOULD CONTAIN:
- Identifies Dockerfile syntax error
- Points to line with CMD instruction
- Shows the missing comma issue
- Provides corrected syntax: CMD ["npm", "start"]
- May reference Dockerfile best practices
EOF

    echo -e "${GREEN}Test 4.2 setup complete${NC}"
}

################################################################################
# Main Test Runner
################################################################################

run_all_tests() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}AWS DevOps Agent - Test Suite${NC}"
    echo -e "${GREEN}========================================${NC}\n"
    
    setup_test_environment
    
    # Run tests based on arguments
    if [ $# -eq 0 ]; then
        # Run all tests
        test_1_1_yaml_syntax_error
        test_1_2_npm_dependency_failure
        test_1_3_python_dependency_failure
        test_2_2_ecs_deployment_failure
        test_2_3_lambda_memory_failure
        test_3_1_missing_github_secret
        test_3_2_invalid_aws_credentials
        test_4_2_docker_build_failure
    else
        # Run specific test
        case $1 in
            1.1) test_1_1_yaml_syntax_error ;;
            1.2) test_1_2_npm_dependency_failure ;;
            1.3) test_1_3_python_dependency_failure ;;
            2.2) test_2_2_ecs_deployment_failure ;;
            2.3) test_2_3_lambda_memory_failure ;;
            3.1) test_3_1_missing_github_secret ;;
            3.2) test_3_2_invalid_aws_credentials ;;
            4.2) test_4_2_docker_build_failure ;;
            *) echo "Unknown test: $1" ;;
        esac
    fi
    
    cleanup
    
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Test execution complete!${NC}"
    echo -e "${GREEN}Results saved to: $TEST_RESULTS_DIR${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# Execute tests
# Usage: ./test-scripts.sh [test_number]
# Example: ./test-scripts.sh 1.1
# Or: ./test-scripts.sh (runs all tests)

run_all_tests "$@"
