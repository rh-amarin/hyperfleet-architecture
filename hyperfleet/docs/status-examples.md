# Adapter Implementation Guide

This document provides concrete examples for implementing the generic adapter SDK, showing how different adapters are configured and how they interact with the HyperFleet API.

## Table of Contents
1. [AdapterConfig Examples](#adapterconfig-examples)
2. [Precondition Evaluation Inputs](#precondition-evaluation-inputs)
3. [Post-Condition Aggregation Rules](#post-condition-aggregation-rules)
4. [Kubernetes Job Sub-Conditions](#kubernetes-job-sub-conditions)
5. [Status Payloads to HyperFleet API](#status-payloads-to-hyperfleet-api)

---

## AdapterConfig Examples

### 1. Validator Adapter

The validator adapter has **no external dependencies** - it only checks if it hasn't already completed its work (self-referential check).

<details>
<summary>Validator config example</summary>

```yaml
apiVersion: hyperfleet.redhat.com/v1alpha1
kind: AdapterConfig
metadata:
  name: validator-adapter
  # ... more YAML here...

  # Self-referential: Only run if validation hasn't completed yet
  preconditions:
    - field: status.adapters[?(@.name=='validation')].available
      operator: ne
      value: "True"

  # These come from reading the k8s jobs status field
  postconditions:
    applied:
      - field: status.conditions[?(@.type=='Complete')].status
        operator: exists
      - field: status.conditions[?(@.type=='Failed')].status
        operator: exists

    # Available is true when all validation checks pass
    available:
      - field: status.conditions[?(@.type=='ValidationComplete')].status
        operator: eq
        value: "True"
      - field: status.conditions[?(@.type=='AllChecksPass')].status
        operator: eq
        value: "True"
      - field: status.succeeded
        operator: greaterThanOrEqual
        value: 1

    # Health is false on unexpected errors
    health:
      failure:
        - field: status.conditions[?(@.type=='JobError')].status
          operator: eq
          value: "True"
        - field: status.failed
          operator: greaterThanOrEqual
          value: 3  # Max retries exhausted

```

</details>

### 2. DNS Adapter

DNS adapter depends on **validator being ready** and its own work not being complete.

<details>
<summary>DNS adaptor config example</summary>

```yaml
apiVersion: hyperfleet.redhat.com/v1alpha1
kind: AdapterConfig
metadata:
  name: dns-adapter
  # ... more YAML here...

  preconditions:
    # Validator must be ready for current generation
    - field: status.adapters[?(@.name=='validation')].available
      operator: eq
      value: "True"
    - field: status.adapters[?(@.name=='validation')].observedGeneration
      operator: eq
      fieldRef: generation

    # DNS work not already complete
    - field: status.adapters[?(@.name=='dns')].available
      operator: ne
      value: "True"


  postconditions:
    applied:
      - field: status.conditions[?(@.type=='Complete')].status
        operator: exists
      - field: status.conditions[?(@.type=='Failed')].status
        operator: exists

    available:
      # All DNS records must be created
      - field: status.conditions[?(@.type=='APIRecordCreated')].status
        operator: eq
        value: "True"
      - field: status.conditions[?(@.type=='AppsWildcardCreated')].status
        operator: eq
        value: "True"
      - field: status.conditions[?(@.type=='DNSVerified')].status
        operator: eq
        value: "True"
      - field: status.succeeded
        operator: greaterThanOrEqual
        value: 1

    health:
      failure:
        - field: status.conditions[?(@.type=='ProviderError')].status
          operator: eq
          value: "True"
        - field: status.failed
          operator: greaterThanOrEqual
          value: 3

```
</details>


### 3. Maestro Adapter

Maestro adapter depends on **all three previous adapters** being ready before it can proceed.
- validator
- DNS
- pullimage (not described, but similar to DNS)

<details>
<summary>Maestro adaptor config example</summary>

```yaml
apiVersion: hyperfleet.redhat.com/v1alpha1
kind: AdapterConfig
metadata:
  name: maestro-adapter
  # ... more YAML here...

  preconditions:
    # Validation must be ready
    - field: status.adapters[?(@.name=='validation')].available
      operator: eq
      value: "True"

    # DNS must be ready
    - field: status.adapters[?(@.name=='dns')].available
      operator: eq
      value: "True"

    # PullImage must be ready
    - field: status.adapters[?(@.name=='pullimage')].available
      operator: eq
      value: "True"
    - field: status.adapters[?(@.name=='pullimage')].observedGeneration
      operator: eq
      fieldRef: generation

    # Maestro work not complete
    - field: status.adapters[?(@.name=='maestro')].available
      operator: ne
      value: "True"

  postconditions:
    applied:
      - field: status.conditions[?(@.type=='Complete')].status
        operator: exists
      - field: status.conditions[?(@.type=='Failed')].status
        operator: exists

    available:
      # Cluster must be provisioned and accessible
      - field: status.conditions[?(@.type=='ClusterProvisioned')].status
        operator: eq
        value: "True"
      - field: status.conditions[?(@.type=='APIServerReachable')].status
        operator: eq
        value: "True"
      - field: status.conditions[?(@.type=='NodesReady')].status
        operator: eq
        value: "True"
      - field: status.succeeded
        operator: greaterThanOrEqual
        value: 1

    health:
      failure:
        - field: status.conditions[?(@.type=='ACMConnectionFailed')].status
          operator: eq
          value: "True"
        - field: status.conditions[?(@.type=='ProvisioningError')].status
          operator: eq
          value: "True"
        - field: status.failed
          operator: greaterThanOrEqual
          value: 3
```
</details>

---

## Precondition Evaluation Inputs

The adapter SDK's **rule engine**:
- Reads the configuration (above examples)
- Receives inputs from the HyperFleet API
- Evaluates the rules to have a precondition TRUE/FALSE

### Example Cluster Object from HyperFleet API and statuses

<details>
<summary>Responses from CLM API</summary>

```json

GET /cluster/123
{
  "id": "cls-550e8400",
  "name": "production-cluster-01",
  "generation": 2,
  "spec": {
    "provider": "aws",
    "region": "us-east-1",
    "baseDomain": "example.com",
    "dns": {
      "provider": "route53"
    },
    "images": [
      "quay.io/openshift/api:latest",
      "quay.io/openshift/controller:latest"
    ]
    //bla bla bla
  }

  GET /cluster/123/statuses
     [
      {
        "name": "validation",
        "available": "True",
        "observedGeneration": 2
      },
      {
        "name": "dns",
        "available": "True",
        "observedGeneration": 2
      },
      {
        "name": "pullimage",
        "available": "False",
        "observedGeneration": 1
      }
    ]
```
</details>

### Precondition Evaluation Examples
These are examples of the pre-conditions that we can find in the adaptor configs

**DNS Adapter Precondition Checks**:
```javascript
// Precondition 1: Validation adapter available
field: "status.adapters[?(@.name=='validation')].available"
operator: "eq"
value: "True"

// Evaluation:
cluster.status.adapters.find(a => a.name === 'validation').available === "True"
Result: TRUE ✓

// Precondition 2: Validation observed current generation
field: "status.adapters[?(@.name=='validation')].observedGeneration"
operator: "eq"
fieldRef: "generation"

// Evaluation:
cluster.status.adapters.find(a => a.name === 'validation').observedGeneration === cluster.generation
Result: TRUE (2 === 2) ✓

// Precondition 3: DNS not already complete
field: "status.adapters[?(@.name=='dns')].available"
operator: "ne"
value: "True"

// Evaluation:
cluster.status.adapters.find(a => a.name === 'dns').available !== "True"
Result: TRUE (available === "True", so check for != passes) ✓

// ALL PRECONDITIONS MET → Adapter proceeds to create/check Job
```

**Maestro Adapter Precondition Checks**:
```javascript
// Using the same cluster object above:

Validation: TRUE (available: "True", observedGeneration: 2)
DNS: TRUE (available: "True", observedGeneration: 2)
PullImage: FALSE (observedGeneration: 1, not current generation 2)

// PRECONDITIONS NOT MET → Adapter skips work, reports status
```

---

## Post-Condition Aggregation Rules

The adapter SDK evaluates **post-conditions** on Kubernetes Job status to determine the three aggregated conditions: **Applied**, **Available**, and **Health**.

In summary, it reads sub-conditions from k8s job status and comes up and has to build the payload to report back to CLM


### Post-Condition Evaluation Logic

Post-conditions contain three sections, each with an array of rules:

1. **`applied`**: Rules to determine if `Applied` condition should be True
2. **`available`**: Rules to determine if `Available` condition should be True
3. **`health.failure`**: Rules to determine if `Health` condition should be False

**Evaluation Strategy**:
- **Applied**: ALL rules must pass → Applied = True
- **Available**: ALL rules must pass → Available = True
- **Health**: If ANY failure rule passes → Health = False, else Health = True

### Example: DNS Adapter Post-Condition Evaluation

**Post-Condition Rules from AdapterConfig**:

Here I introduced conditional operator, do we need to have AND/OR for different operands?

e.g. something like

```
recordcreated==true and (wilcardcreated==true or dnsverified==true)
```


<details>
<summary>Sample DNS adaptor config for post-conditions</summary>

```yaml
postconditions:
  applied:
    - field: status.conditions[?(@.type=='Complete')].status
      operator: exists

  available:
    - conditional:
      operator: and
      operands:
      - field: status.conditions[?(@.type=='APIRecordCreated')].status
        operator: eq
        value: "True"
      - field: status.conditions[?(@.type=='AppsWildcardCreated')].status
        operator: eq
        value: "True"
      - field: status.conditions[?(@.type=='DNSVerified')].status
        operator: eq
        value: "True"
      - field: status.succeeded
        operator: greaterThanOrEqual
        value: 1

  health:
    failure:
      - field: status.conditions[?(@.type=='ProviderError')].status
        operator: eq
        value: "True"
      - field: status.failed
        operator: greaterThanOrEqual
        value: 3
```
</details>

**Evaluation Result**:
```javascript
// APPLIED Evaluation (ALL rules must pass):
Rule 1: job.status.conditions.find(c => c.type === 'Complete') exists
→ TRUE ✓

Applied = TRUE

// AVAILABLE Evaluation (ALL rules must pass):
Rule 1: job.status.conditions.find(c => c.type === 'APIRecordCreated').status === "True"
→ TRUE ✓

Rule 2: job.status.conditions.find(c => c.type === 'AppsWildcardCreated').status === "True"
→ TRUE ✓

Rule 3: job.status.conditions.find(c => c.type === 'DNSVerified').status === "True"
→ TRUE ✓

Rule 4: job.status.succeeded >= 1
→ TRUE ✓

Available = TRUE

// HEALTH Evaluation (ANY failure rule passes → Health = False):
Rule 1: job.status.conditions.find(c => c.type === 'ProviderError')?.status === "True"
→ FALSE (condition doesn't exist)

Rule 2: job.status.failed >= 3
→ FALSE (failed = 0)

Health = TRUE
```

**Final Aggregated Conditions**:
<details>
<summary>payload to send to CLM</summary>

```json
{
  "conditions": [
    {
      "type": "Applied",
      "status": "True",
      "reason": "JobLaunched",
      "message": "DNS Job created successfully"
    },
    {
      "type": "Available",
      "status": "True",
      "reason": "AllRecordsCreated",
      "message": "All DNS records created and verified"
    },
    {
      "type": "Health",
      "status": "True",
      "reason": "NoErrors",
      "message": "DNS adapter executed without errors"
    }
  ]
}
```
</details>

---

## Kubernetes Job Sub-Conditions

Kubernetes Jobs write **sub-conditions** to their own Job object status. The adapter reads these to create the aggregated conditions.

### How Jobs Write Sub-Conditions

Jobs write conditions to `status.conditions` array using the Kubernetes API. This typically happens via:
- Job controller/operator pattern
- Sidecar container that watches main container
- Init container that writes initial status
- Job completion logic that updates status before exit

### Example Job Sub-Conditions


<details>
<summary>DNS Job Sub-Condition</summary>

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: dns-cls-550e8400-gen2
  namespace: hyperfleet-jobs
status:
  conditions:
  # Standard Kubernetes Job condition
  - type: Complete
    status: "True"
    lastTransitionTime: "2025-10-21T14:35:00Z"
    reason: JobComplete
    message: Job completed successfully

  # Custom sub-condition: API record created
  - type: APIRecordCreated
    status: "True"
    lastTransitionTime: "2025-10-21T14:34:30Z"
    reason: RecordCreated
    message: Created A record for api.production-cluster-01.example.com (IP: 54.123.45.67)

  # Custom sub-condition: Apps wildcard created
  - type: AppsWildcardCreated
    status: "True"
    lastTransitionTime: "2025-10-21T14:34:45Z"
    reason: RecordCreated
    message: Created wildcard *.apps.production-cluster-01.example.com (IP: 54.123.45.68)

  # Custom sub-condition: DNS verification
  - type: DNSVerified
    status: "True"
    lastTransitionTime: "2025-10-21T14:35:00Z"
    reason: VerificationComplete
    message: DNS propagation verified via nslookup

  succeeded: 1
  failed: 0
  active: 0
  completionTime: "2025-10-21T14:35:00Z"
```
</details>

<details>
<summary>Validation Job Sub-Conditions (Failure)</summary>

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: validation-cls-550e8400-gen2
  namespace: hyperfleet-jobs
status:
  conditions:
  # Standard Kubernetes Job condition
  - type: Failed
    status: "True"
    lastTransitionTime: "2025-10-21T14:32:00Z"
    reason: BackoffLimitExceeded
    message: Job has reached the specified backoff limit

  # Custom sub-condition: Validation incomplete
  - type: ValidationComplete
    status: "False"
    lastTransitionTime: "2025-10-21T14:32:00Z"
    reason: ChecksFailed
    message: Validation checks failed

  # Custom sub-condition: Route53 check failed
  - type: Route53ZoneExists
    status: "False"
    lastTransitionTime: "2025-10-21T14:31:30Z"
    reason: ZoneNotFound
    message: Route53 hosted zone for example.com not found in account

  # Custom sub-condition: S3 check passed
  - type: S3BucketAccessible
    status: "True"
    lastTransitionTime: "2025-10-21T14:31:15Z"
    reason: BucketFound
    message: S3 bucket hyperfleet-clusters is accessible

  # Custom sub-condition: Quota check passed
  - type: QuotaSufficient
    status: "True"
    lastTransitionTime: "2025-10-21T14:31:20Z"
    reason: QuotaAvailable
    message: VPC quota sufficient (2/5 used)

  # Aggregated check condition
  - type: AllChecksPass
    status: "False"
    lastTransitionTime: "2025-10-21T14:32:00Z"
    reason: SomeChecksFailed
    message: 2/3 checks passed, 1 failed

  succeeded: 0
  failed: 3
  active: 0
```
</details>

<details>
<summary>Maestro Job Sub-Conditions (In Progress)</summary>

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: maestro-cls-550e8400-gen2
  namespace: hyperfleet-jobs
status:
  conditions:
  # Custom sub-condition: Cluster provisioning started
  - type: ClusterProvisioned
    status: "False"
    lastTransitionTime: "2025-10-21T14:40:00Z"
    reason: ProvisioningInProgress
    message: Cluster provisioning via ACM in progress

  # Custom sub-condition: API server not yet ready
  - type: APIServerReachable
    status: "False"
    lastTransitionTime: "2025-10-21T14:40:00Z"
    reason: APIServerNotReady
    message: Waiting for API server to become reachable

  # Custom sub-condition: Nodes not yet ready
  - type: NodesReady
    status: "False"
    lastTransitionTime: "2025-10-21T14:40:00Z"
    reason: NodesProvisioning
    message: 0/3 nodes ready

  succeeded: 0
  failed: 0
  active: 1
  startTime: "2025-10-21T14:38:00Z"
```
</details>



## Adapter SDK Implementation Summary

### SDK Components Required

1. **Precondition Evaluator**
   - JSONPath parser for field extraction
   - Comparison operators (eq, ne, in, exists, etc.)
   - Support for fieldRef (comparing two fields)
   - Boolean logic (ALL preconditions must pass)

2. **Post-Condition Aggregator**
   - Evaluates sub-conditions from Job status
   - Aggregates into Applied, Available, Health
   - Applies ALL-must-pass for available/applied
   - Applies ANY-passes for health.failure

3. **Job Manager**
   - Creates Jobs from Go templates
   - Watches Job status for sub-conditions
   - Implements idempotency (check if Job exists before creating)
   - Handles Job lifecycle (recreate on generation change, cleanup policies)

4. **Status Reporter**
   - Implements upsert pattern (GET → POST or PATCH)
   - Constructs condition payloads from aggregated results
   - Includes data and metadata fields
   - Manages observedGeneration tracking

5. **Event Processor**
   - Subscribes to Pub/Sub topic
   - Extracts clusterId and generation from event
   - Fetches cluster from HyperFleet API
   - Orchestrates: preconditions → job management → post-conditions → status reporting
   - Always ACKs messages

### SDK Configuration Input

Each adapter deployment references an AdapterConfig CRD instance that defines:
- Adapter identity and metadata
- Pub/Sub subscription details
- HyperFleet API client config
- Precondition rules
- Kubernetes resource templates (Jobs)
- Post-condition aggregation rules
- Resource management policies

The SDK reads this configuration and executes the adapter logic generically, without adapter-specific code.
