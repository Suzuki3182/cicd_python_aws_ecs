# ============================================================
# Módulo VPC - Rede completa com subnets públicas e privadas
# ============================================================

# -----------------------------------------------------------
# VPC Principal
# -----------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true # Necessário para o EKS
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
    # Tags necessárias para o EKS descobrir as subnets automaticamente
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  }
}

# -----------------------------------------------------------
# Internet Gateway (acesso público)
# -----------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# -----------------------------------------------------------
# Subnets Públicas (1 por AZ)
# -----------------------------------------------------------
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true # Instâncias nas subnets públicas recebem IP público

  tags = {
    Name = "${var.project_name}-${var.environment}-public-${var.availability_zones[count.index]}"
    Type = "Public"
    # Tag para o EKS criar Load Balancers públicos automaticamente
    "kubernetes.io/role/elb"                                        = "1"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  }
}

# -----------------------------------------------------------
# Subnets Privadas (1 por AZ)
# -----------------------------------------------------------
resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-${var.environment}-private-${var.availability_zones[count.index]}"
    Type = "Private"
    # Tag para o EKS criar Load Balancers internos automaticamente
    "kubernetes.io/role/internal-elb"                               = "1"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  }
}

# -----------------------------------------------------------
# Elastic IPs para NAT Gateways
# -----------------------------------------------------------
resource "aws_eip" "nat" {
  # 1 EIP por AZ (ou apenas 1 se single_nat_gateway = true)
  count  = var.single_nat_gateway ? 1 : length(var.availability_zones)
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-${var.environment}-eip-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------
# NAT Gateways (nas subnets públicas)
# CUSTO: ~$0.045/h por NAT GW + $0.045/GB transferido
# Em dev/staging, use single_nat_gateway = true
# -----------------------------------------------------------
resource "aws_nat_gateway" "main" {
  count = var.single_nat_gateway ? 1 : length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.main]
}

# -----------------------------------------------------------
# Route Table - Subnets Públicas
# -----------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rt-public"
  }
}

resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------
# Route Tables - Subnets Privadas (1 por AZ ou 1 único)
# -----------------------------------------------------------
resource "aws_route_table" "private" {
  count  = var.single_nat_gateway ? 1 : length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rt-private-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

# -----------------------------------------------------------
# VPC Flow Logs (auditoria de tráfego de rede)
# -----------------------------------------------------------
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.project_name}-${var.environment}/flow-logs"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc-flow-logs"
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.project_name}-${var.environment}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn

  tags = {
    Name = "${var.project_name}-${var.environment}-flow-log"
  }
}
