.PHONY: all lint test build scan deploy-staging deploy-prod tf-init tf-plan tf-apply validate bootstrap

ENV ?= staging
IMAGE_TAG ?= sha-$(shell git rev-parse --short HEAD)
TF_DIR = infrastructure/terraform

# ── Development ──────────────────────────────────────────────
lint:
	cd src/app && ruff check . && black --check . && isort --check-only .

format:
	cd src/app && ruff check --fix . && black . && isort .

test:
	cd src/app && \
	  pytest tests/unit/ -v \
	    --cov=app \
	    --cov-report=term-missing \
	    --cov-report=xml:../../reports/coverage.xml \
	    --cov-fail-under=90 \
	    --junitxml=../../reports/junit.xml

test-integration:
	cd src/app && \
	  pytest tests/integration/ -v \
	    --base-url=$(BASE_URL) \
	    --junitxml=../../reports/junit-integration.xml

# ── Docker ───────────────────────────────────────────────────
build:
	docker build -t app:$(IMAGE_TAG) src/

push: build
	docker tag app:$(IMAGE_TAG) $(ECR_REGISTRY)/$(ECR_REPO):$(IMAGE_TAG)
	docker push $(ECR_REGISTRY)/$(ECR_REPO):$(IMAGE_TAG)

# ── Security ─────────────────────────────────────────────────
scan:
	@mkdir -p reports
	trivy image --severity CRITICAL,HIGH app:$(IMAGE_TAG)
	bash scripts/validate-iac.sh

scan-deps:
	pip-audit -r src/app/requirements.txt
	bandit -r src/app/ -ll

# ── Terraform ────────────────────────────────────────────────
tf-init:
	cd $(TF_DIR) && terraform init

tf-plan:
	cd $(TF_DIR) && \
	  terraform workspace select $(ENV) && \
	  terraform plan -var-file=environments/$(ENV).tfvars -var="image_tag=$(IMAGE_TAG)"

tf-apply:
	cd $(TF_DIR) && \
	  terraform workspace select $(ENV) && \
	  terraform apply -var-file=environments/$(ENV).tfvars -var="image_tag=$(IMAGE_TAG)" -auto-approve

tf-drift:
	cd $(TF_DIR) && \
	  terraform workspace select $(ENV) && \
	  terraform plan -var-file=environments/$(ENV).tfvars -detailed-exitcode

# ── CI/CD ────────────────────────────────────────────────────
deploy-staging: build scan
	$(MAKE) tf-apply ENV=staging
	bash scripts/smoke-test.sh --env=staging --endpoint=$(STAGING_URL)/health

deploy-prod: build scan
	$(MAKE) tf-apply ENV=prod
	bash scripts/smoke-test.sh --env=prod --endpoint=$(PROD_URL)/health

# ── Setup ────────────────────────────────────────────────────
bootstrap:
	bash scripts/bootstrap.sh

validate:
	bash scripts/validate-iac.sh

rollback:
	bash scripts/auto-rollback.sh --env=$(ENV) --cluster=cicd-python-ecs-$(ENV)
