# Maestro Architecture Deep Dive

## Core Architecture

### System Components

| Component | Description | Responsibilities |
|-----------|-------------|------------------|
| **Maestro Server** | Central orchestrator | Resource storage, CloudEvent publishing, API endpoints |
| **Maestro Agent** | Cluster-side executor | Resource application, status reporting |
| **PostgreSQL** | Persistent storage | Resource metadata, status tracking, event history |
| **Message Brokers** | Event transport | CloudEvent delivery between server and agents |

### Key Design Principles

- **Event-driven architecture** using CloudEvents
- **Scalable** to 200,000+ clusters without linear infrastructure scaling
- **Broker-agnostic** supporting MQTT, gRPC, GCP Pub/Sub, and AWS IoT
- **Single binary** with different subcommands for server/agent roles

### Architectural Rationale

Maestro uses an **event-driven architecture** where:

1. **HTTP API** → Read-only access for monitoring and metadata (consumers)
2. **gRPC/CloudEvents** → Actual ManifestWork lifecycle operations (create, update, delete)
3. **Event Controllers** → Process gRPC events and update database

**Why this design:**
- **Scalability:** gRPC is more efficient for high-volume ManifestWork operations
- **Real-time:** CloudEvents provide immediate delivery to agents
- **Consistency:** Event-driven system ensures proper ordering and delivery
- **Monitoring:** HTTP API provides simple REST interface for dashboards

### Deployment Modes

#### 1. gRPC Mode (Recommended for HyperFleet)

```
Components:
  - Maestro Server (with integrated gRPC broker)
  - Maestro Agents (on target clusters)
  - PostgreSQL Database

Communication Flow:
  Server ←──gRPC Stream (bidirectional)──▶ Agents
  (Resources: Server → Agents, Status: Agents → Server)
```

**Advantages:**
- No separate broker infrastructure
- Lower latency, binary protocol
- Built-in TLS/mTLS support
- Direct server-agent communication

#### 2. MQTT Mode

```
Components:
  - Maestro Server
  - MQTT Broker (Eclipse Mosquitto)
  - Maestro Agents (on target clusters)
  - PostgreSQL Database

Communication Flow:
  Server ──Publish──▶ MQTT Broker ──Subscribe──▶ Agents
```

**Advantages:**
- Better network isolation
- Topic-based routing
- Supports complex network topologies

#### 3. GCP Pub/Sub Mode

```
Components:
  - Maestro Server
  - GCP Pub/Sub Topics & Subscriptions
  - Maestro Agents (on target clusters)
  - PostgreSQL Database

Communication Flow:
  Server ──Publish──▶ GCP Pub/Sub ──Subscribe──▶ Agents
```

**Advantages:**
- Native GCP integration
- Managed infrastructure (no broker to maintain)
- Global message delivery with low latency
- Built-in IAM authentication

#### 4. AWS IoT Mode

```
Components:
  - Maestro Server
  - AWS IoT Core
  - Maestro Agents (on target clusters)
  - PostgreSQL Database

Communication Flow:
  Server ──Publish──▶ AWS IoT Core ──Subscribe──▶ Agents
```

**Advantages:**
- Native AWS integration
- Managed MQTT broker
- Device certificate authentication
- Scales to millions of connections

---

## Communication Protocols

### HTTP REST API

**Use Cases:** Consumer management and monitoring only

- **Authentication:** JWT Bearer tokens (optional - can be disabled for development)
- **Format:** JSON over HTTP/HTTPS
- **Documentation:** OpenAPI specification available

### gRPC Communication

**Use Cases:** Real-time resource delivery, ManifestWork lifecycle operations

- **Authentication:** TLS, mTLS, or token-based
- **Operations:** CloudEvents publish/subscribe, streaming, ManifestWork CRUD
- **Format:** Protocol Buffers over HTTP/2
- **Performance:** Lower latency, smaller payload size

### Subscription Pre-setup Requirements

**⚠️ Broker-specific setup requirements:**
- **gRPC**: Dynamic subscriptions (no pre-setup needed)
- **MQTT**: Topic structure must be configured during Maestro deployment
- **GCP Pub/Sub**: Topics and subscriptions must be created before use
- **AWS IoT**: IoT Things, device certificates, and policies required

---

## Event Consumption Patterns

### Consumption Models by Broker

| **Broker Type** | **Consumption Pattern** | **Multiple Subscribers** | **Setup Complexity** |
|-----------------|-------------------------|-------------------------|---------------------|
| **gRPC** | Independent streams (broadcast) | ✅ Safe - each gets own stream | Low (dynamic) |
| **MQTT** | Topic-based queuing | ⚠️ Competing consumers | Medium (topic structure) |
| **GCP Pub/Sub** | Subscription-based | ✅ Configurable | Medium (topics + IAM) |
| **AWS IoT** | Topic routing | ⚠️ Similar to MQTT | High (Things + certs + policies) |

### Event Consumption Risks

**⚠️ MQTT/AWS IoT Risk:** Queue-based consumption means multiple subscribers compete for messages:
- **Message consumption conflict** - only one subscriber receives each message
- **Unintended message loss** - if Maestro server and your client both subscribe
- **Mitigation**: Use separate topics or unique client IDs

**✅ gRPC Safe Pattern:** Broadcast streaming - multiple subscribers each receive independent copies of all events.

---

## API Capabilities

> **Key Finding:** ManifestWork lifecycle operations (apply, update, delete) are **only available via gRPC**, not HTTP. The HTTP API is intentionally limited to read operations and consumer management.

### API Endpoint Support Matrix

| API Endpoint | GET | POST | DELETE | Purpose |
|--------------|-----|------|--------|---------|
| `/api/maestro/v1/consumers` | ✅ | ✅ | ✅ | Consumer metadata management |
| `/api/maestro/v1/resource-bundles` | ✅ | ❌ | ✅ | ManifestWork status/monitoring |

### API Design Rationale

**Why HTTP is Read-Only for Resources:**
- **Performance:** gRPC more efficient for high-volume ManifestWork operations
- **Real-time:** CloudEvents provide immediate delivery to agents
- **Scalability:** Event-driven system handles large cluster counts better
- **Consistency:** gRPC ensures proper ordering and delivery guarantees

**HTTP API Use Cases:**
- Dashboard monitoring and reporting
- Consumer (cluster) management
- Status queries and filtering
- Operational tooling and scripts

---

## ManifestWork Integration

### Resource Model

Maestro works with **ManifestWork** resources (Open Cluster Management API) but does **NOT require ACM operator**:

- Uses Open Cluster Management APIs (`open-cluster-management.io/api`) for resource definitions
- Implements custom transport layer via CloudEvents
- Self-contained control plane with PostgreSQL storage

### Resource vs ManifestWork Relationship

```yaml
# ManifestWork is stored as a "resource" in Maestro
apiVersion: work.open-cluster-management.io/v1
kind: ManifestWork
metadata:
  name: test-manifestwork
  namespace: consumer-cluster
spec:
  workload:
    manifests: [...]
```

This becomes a Maestro `resource` with:
- **consumer_name:** Target cluster
- **manifest:** The ManifestWork YAML
- **type:** `ManifestWork`

---

## Security Architecture

### Authentication Layers

1. **HTTP API Authentication**
   - JWT Bearer tokens (optional for development)
   - Red Hat SSO integration
   - Role-based access control

2. **gRPC Authentication**
   - TLS/mTLS for transport security
   - Token-based authentication
   - Certificate-based client auth

3. **Agent Authentication**
   - mTLS between server and agents
   - Service account management
   - Certificate rotation strategy

### Network Security

- **TLS encryption** for all communications
- **Network policies** to restrict access between components
- **Firewall rules** for broker access
- **VPN/Private networks** for cross-cluster communication

---

## Monitoring & Observability

### Key Metrics

- **Resource delivery latency**: Time from submission to application
- **Agent connection status**: Healthy/unhealthy agent connections
- **CloudEvents processing rates**: Events per second throughput
- **Database performance**: Query latency, connection pools
- **gRPC connection health**: Stream status, connection errors

### Logging Strategy

```yaml
# Configurable log levels
- name: KLOG_V
  value: "2"  # Adjust verbosity as needed
```

### Alerting Scenarios

- Agent disconnections
- Resource application failures
- Database connection issues
- Message broker downtime
- Certificate expiration warnings

---

## Troubleshooting Guide

### Connection Issues

1. **TLS certificate problems**
   - Check certificate expiration dates
   - Verify certificate chain validity
   - Ensure proper CA configuration

2. **Network connectivity**
   - Test connectivity between components
   - Verify firewall rules and security groups
   - Check DNS resolution

3. **Authentication failures**
   - Validate JWT tokens and expiration
   - Check service account permissions
   - Verify mTLS certificate configuration

### Resource Delivery Issues

1. **Agent status problems**
   - Check agent logs for errors
   - Verify agent connectivity to broker
   - Validate consumer registration

2. **CloudEvents validation**
   - Check event format and schema
   - Verify required extensions present
   - Validate JSON payload structure

3. **Database performance**
   - Monitor connection pool usage
   - Check query performance
   - Verify database disk space

4. **Target cluster permissions**
   - Validate RBAC permissions for agent
   - Check namespace access rights
   - Verify resource quotas and limits
