# DevTube - Kiến trúc Hệ thống

## Tổng quan Kiến trúc

DevTube được thiết kế theo mô hình microservices và triển khai trên Amazon EKS (Elastic Kubernetes Service). Hệ thống sử dụng kiến trúc cloud-native với khả năng mở rộng cao và tính sẵn sàng cao.

## Sơ đồ Kiến trúc Tổng thể

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│     Internet    │────│   Route 53/DNS   │────│     CloudFlare      │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
         │                        │                        │
         └────────────────────────┼────────────────────────┘
                                  │
                ┌─────────────────────────────────────┐
                │        AWS Application              │
                │        Load Balancer (ALB)          │
                │     ┌─────────────────────┐         │
                │     │   SSL Certificate   │         │
                │     │   (AWS ACM)        │         │
                │     └─────────────────────┘         │
                └─────────────────────────────────────┘
                                  │
              ┌───────────────────────────────────────────┐
              │              EKS Cluster                  │
              │    ┌─────────────────────────────────┐    │
              │    │        Ingress Controller       │    │
              │    │    (AWS Load Balancer)         │    │
              │    └─────────────────────────────────┘    │
              │                    │                      │
              │    ┌─────────────────────────────────┐    │
              │    │         API Gateway             │    │
              │    │      (Production)               │    │
              │    │   ┌───────────┬───────────┐     │    │
              │    │   │   Pod 1   │   Pod N   │     │    │
              │    │   └───────────┴───────────┘     │    │
              │    └─────────────────────────────────┘    │
              │                    │                      │
              │    ┌─────────────────────────────────┐    │
              │    │       Staging Services          │    │
              │    │   ┌─────────┬─────────────┐     │    │
              │    │   │  Auth   │   Upload    │     │    │
              │    │   │ Service │   Service   │     │    │
              │    │   └─────────┴─────────────┘     │    │
              │    └─────────────────────────────────┘    │
              └───────────────────────────────────────────┘
```

## Thành phần Kiến trúc

### 1. Network Layer

#### DNS & CDN
- **Route 53**: DNS routing cho domain
- **CloudFlare**: CDN và DNS management
- **Namecheap**: Domain registration

#### Load Balancing
- **AWS Application Load Balancer (ALB)**
  - Internet-facing scheme
  - Target type: IP
  - SSL termination tại ALB
  - HTTP → HTTPS redirect

### 2. Container Orchestration

#### Amazon EKS Cluster
- **Tên**: devtube
- **Region**: ap-southeast-1 (Singapore)
- **Mode**: Auto Mode (Serverless)
- **Node Management**: Fully managed by AWS

#### Kubernetes Components
```yaml
Namespace: devtube
├── Deployment: api-gateway-deployment
├── Service: api-gateway-service
└── Ingress: ingress-api-gateway
```

### 3. Application Layer

#### API Gateway (Production)
- **Image**: `public.ecr.aws/s0p6q3j7/api-gateway:v0.0.2-beta-2-e61f743`
- **Replicas**: 1 (có thể scale)
- **Port**: 8080 (container) → 80 (service)
- **Resource Management**: Kubernetes managed

#### Staging Services
- **Auth Service**: Authentication và authorization
- **Upload Service**: File upload và management
- **API Gateway**: Staging version cho testing

### 4. Security Layer

#### SSL/TLS
- **Certificate Provider**: AWS Certificate Manager (ACM)
- **Certificate ARN**: `arn:aws:acm:ap-southeast-1:564439693649:certificate/3a6cdb8f-c952-42c3-84f5-235d9747fc55`
- **Encryption**: TLS 1.2+
- **Redirect**: HTTP → HTTPS (301)

#### Network Security
- **Security Groups**: Managed by ALB Controller
- **Pod Security**: Kubernetes network policies
- **Service Mesh**: (Future implementation)

## Data Flow

### 1. Request Flow
```
User Browser → DNS Resolution → ALB → Ingress Controller → Service → Pod
```

#### Detailed Flow:
1. **DNS Resolution**: 
   - User nhập domain
   - DNS resolver query Route 53/CloudFlare
   - Return ALB DNS name

2. **Load Balancer**:
   - ALB nhận request
   - SSL termination
   - Route theo ingress rules

3. **Kubernetes Ingress**:
   - AWS Load Balancer Controller
   - Parse ingress rules
   - Forward đến service

4. **Service Discovery**:
   - Kubernetes Service (ClusterIP)
   - Load balance giữa các pods
   - Service mesh (future)

5. **Pod Processing**:
   - Container nhận request
   - Process business logic
   - Return response

### 2. Response Flow
```
Pod → Service → Ingress Controller → ALB → User Browser
```

## Deployment Strategy

### 1. Environment Separation
```
workloads/
├── Production (new-dep.yaml)
│   └── API Gateway (single service)
└── Staging (stg/ directory)
    ├── API Gateway
    ├── Auth Service
    └── Upload Service
```

### 2. Container Strategy
- **Registry**: Amazon ECR Public
- **Image Versioning**: Semantic versioning với Git hash
- **Pull Policy**: Always (để ensure latest image)
- **Rollout**: Rolling update (zero downtime)

### 3. Service Discovery
- **Internal**: Kubernetes DNS
- **External**: AWS Load Balancer
- **Health Checks**: Kubernetes liveness/readiness probes

## Scalability & Performance

### 1. Horizontal Scaling
```bash
# Scale pods
kubectl scale deployment api-gateway-deployment --replicas=5 -n devtube

# Auto-scaling (HPA)
kubectl autoscale deployment api-gateway-deployment --cpu-percent=70 --min=1 --max=10 -n devtube
```

### 2. Load Distribution
- **ALB**: Multiple AZs
- **EKS**: Multi-AZ node groups
- **Pods**: Distributed across nodes

### 3. Performance Optimization
- **Resource Limits**: CPU/Memory constraints
- **Caching**: (Future implementation)
- **CDN**: CloudFlare for static assets

## Monitoring & Observability

### 1. Logging Strategy
```
Application Logs → Container → Kubernetes → CloudWatch
```

### 2. Metrics Collection
- **Kubernetes Metrics**: CPU, Memory, Network
- **Application Metrics**: Custom metrics
- **Infrastructure Metrics**: EKS, ALB metrics

### 3. Health Checks
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
```

## Security Architecture

### 1. Network Security
```
Internet → WAF → ALB → Private Subnets → Pods
```

### 2. Identity & Access Management
- **EKS**: IAM roles for service accounts (IRSA)
- **Pods**: Service account với least privilege
- **ALB Controller**: Dedicated IAM role

### 3. Secrets Management
- **Kubernetes Secrets**: Sensitive data
- **AWS Secrets Manager**: External secrets (future)
- **ConfigMaps**: Non-sensitive configuration

## Disaster Recovery

### 1. Backup Strategy
- **Configuration**: YAML backups
- **Data**: Persistent volume snapshots
- **Cluster**: Infrastructure as Code

### 2. Recovery Procedures
- **RTO (Recovery Time Objective)**: < 30 minutes
- **RPO (Recovery Point Objective)**: < 5 minutes
- **Multi-region**: (Future implementation)

## Future Architecture Enhancements

### 1. Service Mesh
- **Istio**: Traffic management, security
- **Envoy Proxy**: Sidecar pattern
- **Observability**: Distributed tracing

### 2. Database Layer
- **Amazon RDS**: Managed database
- **ElastiCache**: Caching layer
- **DocumentDB**: NoSQL database

### 3. Event-Driven Architecture
- **Amazon SQS**: Message queuing
- **EventBridge**: Event routing
- **Lambda**: Serverless processing

### 4. CI/CD Pipeline
- **GitHub Actions**: Build & test
- **Amazon ECR**: Container registry
- **ArgoCD**: GitOps deployment

## Cost Optimization

### 1. Resource Management
- **Right-sizing**: Appropriate resource allocation
- **Spot Instances**: Cost-effective compute
- **Auto-scaling**: Scale down during low usage

### 2. Storage Optimization
- **EBS**: Optimized storage classes
- **EFS**: Shared storage when needed
- **Data Lifecycle**: Automated data archiving

## Compliance & Governance

### 1. Security Compliance
- **SOC 2**: Security controls
- **ISO 27001**: Information security
- **GDPR**: Data protection

### 2. Operational Excellence
- **Well-Architected**: AWS best practices
- **Infrastructure as Code**: Terraform/CloudFormation
- **Documentation**: Comprehensive docs

---

*Tài liệu này sẽ được cập nhật thường xuyên theo sự phát triển của hệ thống.* 