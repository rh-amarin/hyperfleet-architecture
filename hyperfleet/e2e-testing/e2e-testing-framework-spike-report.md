# Spike Report: E2E Testing Framework for Hyperfleet Core Data Flow

---

**JIRA Story:** HYPERFLEET-403  
**Date:** Jan 9, 2026  
**Target System:** Hyperfleet API → Sentinel → Message Broker → Adapters (Core Framework)

---

## Executive Summary

This spike report evaluates E2E testing frameworks for **Hyperfleet's core data flow**—testing the end-to-end pipeline: Hyperfleet API → Sentinel → Message Broker → Adapters → back to API.

**✅ Decision: Ginkgo v2 + Gomega + Markdown Documentation**

After evaluating Ginkgo v2, Godog, and Testify across seven dimensions, we select **Ginkgo v2 + Gomega** because this combination excels in:
- **Reliability & Flakiness Prevention**: Gomega's built-in async testing (`Eventually`/`Consistently`) prevents flaky tests in distributed systems
- **AI-Assisted Development**: Pure Go optimizes LLM-driven test generation, maintenance, and debugging
- **Maturity & Ecosystem**: Large community, widely adopted, strong long-term support

**What This Means:**
- **Ginkgo v2**: BDD-style test framework providing test organization, labels, parallel execution, and lifecycle hooks
- **Gomega**: Assertion library with expressive matchers and async testing primitives
- **Markdown**: Documentation format for test scenarios, linked to code via AI-Sync-ID metadata

We mitigate documentation drift risk through AI-powered validation and CI checks (detailed in Section 2.3).

**Scope**: This framework tests our core data flow architecture. Provider-specific adapter implementations (validation, DNS, etc.) are **out of scope** and should have dedicated stories. 

---

## 1. Background & Problem Statement

### 1.1 System Architecture

The target system comprises the **core Hyperfleet data flow framework**:

![Hyperfleet E2E Data Flow Architecture](./hyperfleet-e2e.png)

*Diagram provided by Ciaran*

**Core Data Flow (In Scope):**
1. **User → API**: User creates/queries objects through Hyperfleet API
2. **API → Sentinel**: Sentinel polls API for objects requiring orchestration
3. **Sentinel → Broker**: Sentinel creates topics and publishes to message broker
4. **Broker → Adapter**: Topics are broadcast to adapter(s) for consumption
5. **Adapter → API**: Adapters orchestrate task lifecycle and report state back to API

**Out of Scope:**
- Provider-specific adapter implementations (validation, DNS, pull-secret adapters, etc.)
- Provider-specific infrastructure provisioning
- Multi-provider deployment architecture

### 1.2 Testing Challenges

1. **Multi-Component Data Flow:** Validating data flow across API → Sentinel → Broker → Adapter → API
2. **Asynchronous Operations:** Eventual consistency requires intelligent polling and timeout handling
3. **Version Skew:** Rolling deployments require compatibility validation across service versions
4. **Framework Regression:** Changes in one component must not break downstream components

---

## 2. Framework Selection and Evaluation

### 2.1 Evaluation Criteria

Three candidate frameworks were evaluated—**Ginkgo v2**, **Godog**, and **Testify**—across seven critical dimensions:

1. **Integration & Setup**: Ease of integrating testing scenarios, CI pipelines, and tooling requirements
2. **Test Organization & Execution**: Test structure, filtering capabilities, and execution control
3. **Documentation & Communication**: How tests serve as documentation and communicate intent to stakeholders
4. **Reliability & Flakiness Prevention**: Built-in support for eventual consistency, retry logic, and anti-flakiness patterns
5. **AI-Assisted Development**: Suitability for LLM-driven test generation, maintenance, and debugging
6. **Maturity & Ecosystem**: Community size, stability, long-term support, and available resources
7. **Long-term Maintainability**: Ease of debugging, refactoring, and evolving tests over time

### 2.2 Framework Comparison

| Criteria | Ginkgo v2 + Gomega | Godog | Testify |
|----------|-----------|-------|---------|
| **Integration & Setup** | ⭐⭐⭐⭐⭐ Standard Go, minimal dependencies | ⭐⭐⭐☆☆ Requires Godog runner + feature files | ⭐⭐⭐⭐⭐ Standard Go test |
| **Test Organization & Execution** | ⭐⭐⭐⭐⭐ Labels, hierarchical, parallel | ⭐⭐⭐⭐☆ Tags, scenarios, serial by default | ⭐⭐☆☆☆ Flat, name-based |
| **Documentation & Communication** | ⭐⭐⭐☆☆ Requires separate Markdown docs | ⭐⭐⭐⭐⭐ Executable specs, zero drift | ⭐⭐☆☆☆ Code-only |
| **Reliability & Flakiness Prevention** | ⭐⭐⭐⭐⭐ Gomega's Eventually/Consistently, automatic retry | ⭐⭐☆☆☆ Manual polling with custom logic | ⭐⭐☆☆☆ Manual implementation |
| **AI-Assisted Development** | ⭐⭐⭐⭐⭐ Single language, direct debugging | ⭐⭐⭐☆☆ Two languages, higher token cost | ⭐⭐⭐⭐☆ Simple but limited |
| **Maturity & Ecosystem** | ⭐⭐⭐⭐⭐ Large community, widely adopted | ⭐⭐⭐☆☆ Smaller community, growing | ⭐⭐⭐⭐☆ Mature, simpler scope |
| **Long-term Maintainability** | ⭐⭐⭐⭐☆ Doc drift risk, strong tooling | ⭐⭐⭐⭐☆ Two files to maintain, clear intent | ⭐⭐⭐☆☆ Limited structure |

**Key Trade-offs:**

| Framework | Strengths | Weaknesses |
|-----------|-----------|------------|
| **Ginkgo v2 + Gomega** | • Gomega's async testing (`Eventually`/`Consistently`)<br>• Pure Go (AI-friendly, single language)<br>• Rich organization (labels, parallel, ordered)<br>• Expressive matchers for clear assertions | • Separate docs (drift risk)<br>• Less accessible to non-developers |
| **Godog** | • Executable specs (zero drift by design)<br>• Readable by non-developers<br>• Industry-standard Gherkin | • Manual async patterns<br>• Two-file system overhead<br>• Less AI-optimal (context switching) |

**✅ Decision: Ginkgo v2 + Gomega + Markdown**

For Hyperfleet E2E testing, we prioritize **reliability** (Gomega's robust async testing) and **development velocity** (AI-assisted workflows with pure Go) over executable documentation. Meanwhile, we mitigate doc drift through AI-powered validation (Section 2.3).

**Note:** Ginkgo v2 and Gomega are designed to work together—Ginkgo provides the test framework structure while Gomega provides the assertion library with async testing capabilities.

*See Appendix A for detailed framework evaluations.*

### 2.3 Implementation: Ginkgo v2 + Gomega + Markdown Documentation

**This is our chosen approach.** The Hyperfleet E2E testing framework uses **Ginkgo v2** (test framework) with **Gomega** (assertion library) and **Markdown documentation**. 

**Why This Combination:**
- **Ginkgo v2**: Provides BDD-style test organization, label-based filtering, parallel execution, and powerful lifecycle hooks
- **Gomega**: Offers rich, expressive matchers and built-in async testing (`Eventually`/`Consistently`) for distributed systems
- **Markdown**: Flexible documentation format supporting diagrams, code samples, and rich formatting beyond Gherkin limitations

This section details implementation patterns and how we address documentation drift.

#### 2.3.1 Reliability & Flakiness Prevention

Distributed E2E testing requires robust async handling. Ginkgo's built-in patterns eliminate entire classes of flaky tests:

<details>
<summary>Ginkgo Async Testing Patterns (click to expand)</summary>

```go
// Eventual consistency - polls until condition met or timeout
Eventually(func() string {
    return apiClient.GetObjectStatus(ctx, objectID).State
}, 10*time.Minute, 15*time.Second).Should(Equal("COMPLETED"))

// Stable state verification - ensures condition remains true
Consistently(func() bool {
    return brokerClient.IsHealthy(ctx)
}, 2*time.Minute, 5*time.Second).Should(BeTrue())
```

**Anti-Flakiness Patterns:**
- **No fixed sleeps**: `Eventually` polls dynamically, adapts to actual system timing
- **Automatic retry**: Transparent handling of transient failures
- **Configurable timeouts**: Environment-specific timing without code changes
- **Idempotent cleanup**: Resources freed even on test failures

```go
AfterEach(func() {
    defer GinkgoRecover() // Don't let cleanup failures crash suite
    if testObject != nil {
        _ = apiClient.DeleteObject(testObject.ID) // Ignore errors
        Eventually(func() bool {
            _, err := apiClient.GetObject(testObject.ID)
            return err != nil && IsNotFoundError(err)
        }, 5*time.Minute).Should(BeTrue())
    }
})
```

</details>


#### 2.3.2 AI-Assisted Development

- **Single language**: LLMs parse pure Go without Gherkin/Go context switching
- **Direct debugging**: Stack traces map to exact code locations
- **High generation accuracy**: LLMs produce correct Ginkgo patterns with minimal context

#### 2.3.3 Test Organization

<summary>Test Organization Patterns (click to expand)</summary>

**Label-based filtering:**
```bash
ginkgo --label-filter="smoke && gcp"      # Smoke tests for GCP
ginkgo --label-filter="critical && !day2"    # Critical excluding day2
```

**Ordered execution with shared setup:**
```go
Describe("Nodepool", Ordered, func() {
    BeforeAll(func() { clusterID = createCluster() })
    It("creates nodepool", func() { ... })
    It("scales nodepool", func() { ... })
    AfterAll(func() { deleteCluster(clusterID) })
})
```

#### 2.3.4 Documentation Sync Strategy

**Challenge:** Separate Markdown documentation can drift from test code.

**Solution:** AI-assisted sync validation:

**Approach:**

1. **Metadata anchors** link docs to tests:
   ```markdown
   **AI-Sync-ID:** E2E-FLOW-001
   ```
   ```go
   // @AI-Sync-ID: E2E-FLOW-001
   var _ = Describe("Data Flow", Label("E2E-FLOW-001"), ...)
   ```

2. **AI-powered validation**: LLMs verify sync by scanning AI-Sync-IDs, detect drift

3. **Markdown advantages**: Supports diagrams, links, embedded content beyond Gherkin's limitations

#### 2.3.5 Test Case Structure
**Example:**
```markdown
<!-- scenarios/data_flow.md -->
## Scenario: End-to-End Object Creation Data Flow
**AI-Sync-ID:** E2E-FLOW-001  
**Priority:** Critical
...
```
*Refer to the [Test Case Markdown Template](https://github.com/openshift-hyperfleet/hyperfleet-e2e/blob/main/testcases/template.md) for detailed structure.*

```go
// tests/data_flow_test.go
// @AI-Sync-ID: E2E-FLOW-001
var _ = Describe("End-to-End Data Flow", Label("E2E-FLOW-001", "critical"), func() {
    // Test implementation
})
```

#### 2.3.6 Complete Example Implementation
<details>
<summary>Complete Ginkgo + Gomega + Markdown Test Example (click to expand)</summary>

**Part 1: Markdown Documentation**

```markdown
# scenarios/data_flow.md

## Scenario: End-to-End Data Flow Validation

**AI-Sync-ID:** E2E-FLOW-001  
**Priority:** Critical  
**Labels:** data-flow, framework, critical

### Purpose
Validate the complete data flow from API to adapter and back, ensuring framework components work together correctly.

### Prerequisites
- The Hyperfleet API is available
- Sentinel is running and polling
- The message broker is healthy
- At least one adapter is deployed

### Test Steps

1. **Create Object via API**
   - Create an object with name "test-object-1" and type "ClusterRequest"
   - Verify creation succeeds and returns a valid object ID

2. **Verifying adapter reports status back to API**
   - Expected: Adapter consumes topic within 2 minutes
   - Expected: Adapter reports status back to API

5. **Verify Complete Flow**
   - Poll object status periodically
   - Expected: Object reaches "READY" state within 10 minutes

6. **Verify State Consistency**
   - Ensure final state remains stable
   - Expected: State consistently stays "COMPLETED"

### Cleanup
- Delete the created object
- Verify deletion completes successfully
```

**Part 2: Go Test Implementation**

```go
// tests/data_flow_test.go
package tests

import (
    "context"
    "time"

    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
    
    "hyperfleet-e2e/pkg/clients"
)

// @AI-Sync-ID: E2E-FLOW-001
var _ = Describe("End-to-End Data Flow Validation", Label("data-flow", "framework", "critical", "E2E-FLOW-001"), func() {
    var (
        ctx              context.Context
        apiClient        *clients.APIClient
        sentinelClient   *clients.SentinelClient
        brokerClient     *clients.BrokerClient
        adapterClient    *clients.AdapterClient
        createdObjectID  string
        createdObject    *clients.Object
    )

    // BeforeEach verifies all prerequisites before running tests
    BeforeEach(func() {
        ctx = context.Background()
        
        // Initialize clients
        apiClient = clients.NewAPIClient(cfg.APIEndpoint, cfg.APIToken)
        sentinelClient = clients.NewSentinelClient(cfg.SentinelEndpoint)
        brokerClient = clients.NewBrokerClient(cfg.BrokerEndpoint)
        adapterClient = clients.NewAdapterClient(cfg.AdapterEndpoint)
        
        GinkgoWriter.Println("Verifying system prerequisites...")
        
        // Verify: Hyperfleet API is available
        Eventually(func() error {
            return apiClient.HealthCheck(ctx)
        }, 30*time.Second, 2*time.Second).Should(Succeed(), "API should be healthy")
        
        // Verify: Sentinel is running and polling
        Eventually(func() bool {
            status, err := sentinelClient.GetStatus(ctx)
            return err == nil && status.IsRunning
        }, 30*time.Second, 2*time.Second).Should(BeTrue(), "Sentinel should be running")
        
        // Verify: Message broker is healthy
        Expect(brokerClient.IsHealthy(ctx)).To(BeTrue(), "Message broker should be healthy")
        
        // Verify: At least one adapter is deployed
        adapters, err := adapterClient.ListAdapters(ctx)
        Expect(err).NotTo(HaveOccurred(), "Should be able to list adapters")
        Expect(adapters).NotTo(BeEmpty(), "At least one adapter should be deployed")
        
        GinkgoWriter.Println("✓ All prerequisites verified")
    })

    // AfterEach handles cleanup with idempotent operations
    AfterEach(func() {
        defer GinkgoRecover()
        
        if createdObjectID != "" {
            GinkgoWriter.Printf("Cleaning up object: %s\n", createdObjectID)
            _ = apiClient.DeleteObject(ctx, createdObjectID)
            
            // Verify deletion completes successfully
            Eventually(func() bool {
                _, err := apiClient.GetObject(ctx, createdObjectID)
                return err != nil && clients.IsNotFoundError(err)
            }, 5*time.Minute, 10*time.Second).Should(BeTrue())
            
            GinkgoWriter.Println("✓ Cleanup completed")
        }
    })

    It("should complete full data flow from API to adapter and back", func() {
        By("creating an object via the API")
        var err error
        createdObject, err = apiClient.CreateObject(ctx, &clients.CreateObjectRequest{
            Name: "test-object-1",
            Type: "ClusterRequest",
        })
        Expect(err).NotTo(HaveOccurred(), "Object creation should succeed")
        Expect(createdObject).NotTo(BeNil())
        Expect(createdObject.ID).NotTo(BeEmpty(), "Object should have a valid ID")
        createdObjectID = createdObject.ID
        GinkgoWriter.Printf("✓ Created object with ID: %s\n", createdObjectID)

        By("verifying adapter reports status back to API")
        Eventually(func() bool {
            status, err := apiClient.GetObjectStatus(ctx, createdObjectID)
            if err != nil {
                GinkgoWriter.Printf("Error getting object status: %v\n", err)
                return false
            }
            return status.LastUpdatedBy == "adapter" && status.State = "Available"
        }, 2*time.Minute, 10*time.Second).Should(BeTrue(),
            "Adapter should report status to API")

        // Step 5: Verify complete flow
        By("polling object status until completion")
        Eventually(func() string {
            status, err := apiClient.GetObjectStatus(ctx, createdObjectID)
            if err != nil {
                GinkgoWriter.Printf("Error getting object status: %v\n", err)
                return ""
            }
            GinkgoWriter.Printf("Object state: %s (updated: %v)\n", 
                status.State, status.LastUpdated)
            return status.State
        }, 10*time.Minute, 15*time.Second).Should(Equal("READY"),
            "Object should reach READY state within 10 minutes")
        GinkgoWriter.Printf("✓ Complete data flow validated for object: %s\n", createdObjectID)
        
        // Step 6: Verify state consistency (If needed)
        By("verifying final state consistency")
        Consistently(func() string {
            status, err := apiClient.GetObjectStatus(ctx, createdObjectID)
            if err != nil {
                return ""
            }
            return status.State
        }, 30*time.Second, 5*time.Second).Should(Equal("READY"),
            "Object state should remain stable")
        GinkgoWriter.Println("✓ Final state is consistent")
    })
})
```

</details>

---

## 3. Compatibility Testing Strategy

### 3.1 Branch-Based Testing Model

**Principle:** Repository branch = CLM Framework version (no version tracking in test code).

**Structure:**
```
e2e-tests/
├── release-1.0.x/        # Tests for Hyperfleet v1.0.x
├── release-1.1.x/        # Tests for Hyperfleet v1.1.x
├── release-1.2.x/        # Tests for Hyperfleet v1.2.x (current)
└── main/                 # Tests for next release (development)
```

Each branch contains tests for that specific framework release. Branch name implicitly defines which API contract tests expect.

### 3.2 Backward Compatibility Testing

Run old tests on new framework to validate backward compatibility:

```bash
# Test current release
git checkout release-1.2
./e2e-runner --env=staging.yaml  # v1.2.0 passes

# Test backward compatibility  
git checkout release-1.1          # Old tests
./e2e-runner --env=staging.yaml   # Same v1.2.0 environment passes
```

**Validates:**
- API contract stability across versions
- Topic format compatibility
- Framework component interoperability

---

## Appendix A: Detailed Framework Evaluations

This appendix provides detailed assessments of each framework for reference.

### A.1 Hybrid Ginkgo + Godog Pattern

**Overview:**
An alternative approach using Ginkgo v2 as the test runner with Godog (Gherkin) for scenario definition in critical user flows.

**Key Characteristics:**
- Executable Gherkin `.feature` files serve as both documentation and test specifications
- Step definitions map Gherkin steps to Go implementation
- Zero drift between documentation and code (tests fail if out of sync)
- Industry-standard Gherkin syntax for cross-tool compatibility

**When This Approach Makes Sense:**
- Organizations with strong compliance/audit requirements requiring traceable documentation
- Cross-functional teams with significant non-developer involvement (Product, QA, Legal, Compliance)
- Projects where business stakeholders must validate test scenarios
- Environments where executable specifications are mandated by policy
- Teams with existing Gherkin/Cucumber expertise and tooling

**Trade-offs vs. Recommended Approach:**
- **Learning Curve:** Requires team to learn Gherkin syntax and step definition patterns
- **Development Velocity:** Slower test creation with AI assistance compared to pure Go
- **Debugging Complexity:** Stack traces require mapping from Gherkin steps to Go code
- **AI Integration:** Lower first-pass accuracy compared to pure Go approach
- **Context Overhead:** Higher LLM token consumption compared to single-file approach
- **Maintenance:** Additional step definition layer to maintain and keep in sync

**Example Implementation:**

<details>
<summary>Complete Godog (Gherkin) Test Example (click to expand)</summary>

```gherkin
# scenarios/data_flow.feature
@data-flow @framework
Feature: End-to-End Data Flow Validation
  As a framework developer
  I want to validate the complete data flow from API to adapter
  So that I can ensure framework components work together correctly

  @critical @E2E-FLOW-001
  Scenario: Complete data flow for object creation
    Given the Hyperfleet API is available
    And Sentinel is running and polling
    And the message broker is healthy
    And at least one adapter is deployed

    When I create an object via the API:
      | field | value          |
      | name  | test-object-1  |
      | type  | ClusterRequest |
    Then I should receive a "202" response
    And the response should contain a valid object ID

    # Verify Sentinel detects object
    When I wait for Sentinel to detect the object
    Then Sentinel should have detected the object within "2 minutes"

    # Verify topic created
    When I check the message broker
    Then a topic should exist for the object within "1 minute"

    # Verify adapter consumption
    When I check adapter state
    Then the adapter should have consumed the topic within "2 minutes"
    And the adapter should report status back to API

    # Verify complete flow
    When I poll the object status every "10 seconds"
    Then the object should reach "COMPLETED" state within "10 minutes"
```

```go
// Firstly, define each step
func (s *DataFlowSteps) theObjectShouldReachStateWithin(expectedState, timeoutStr string) error {
    ctx := context.Background()
    apiClient := s.commonSteps.GetAPIClient()

    timeout := parseDuration(timeoutStr)
    pollInterval := 10 * time.Second

    fmt.Printf("Waiting for object to reach %s state (timeout: %v)...\n", expectedState, timeout)

    startTime := time.Now()
    for {
        status, err := apiClient.GetObjectStatus(ctx, s.CreatedObjectID)
        if err == nil && status.State == expectedState {
            fmt.Printf("✓ Object reached %s state\n", expectedState)
            return nil
        }

        if time.Since(startTime) > timeout {
            currentState := "UNKNOWN"
            if status != nil {
                currentState = status.State
            }
            return fmt.Errorf("object did not reach %s state within %v (current: %s)",
                expectedState, timeout, currentState)
        }

        time.Sleep(pollInterval)
    }
}

// Secondly, register the steps, which map the content to the step functions
func (s *DataFlowSteps) RegisterSteps(sc *godog.ScenarioContext) {
    // Also register common steps
    s.commonSteps.RegisterSteps(sc)
    
    // Object creation steps
    sc.Step(`^I create an object via the API:$`, s.iCreateAnObjectViaTheAPI)
    
    // Sentinel verification steps
    sc.Step(`^I wait for Sentinel to detect the object$`, s.iWaitForSentinelToDetectTheObject)
    sc.Step(`^Sentinel should have detected the object within "([^"]*)"$`, s.sentinelShouldHaveDetectedTheObjectWithin)
    
    // Broker verification steps
    sc.Step(`^I check the message broker$`, s.iCheckTheMessageBroker)
    sc.Step(`^a topic should exist for the object within "([^"]*)"$`, s.aTopicShouldExistForTheObjectWithin)
    
    // Adapter verification steps
    sc.Step(`^the adapter should have consumed the topic within "([^"]*)"$`, s.theAdapterShouldHaveConsumedTheTopicWithin)
    
    // Object status steps
    sc.Step(`^I poll the object status every "([^"]*)"$`, s.iPollTheObjectStatusEvery)
    sc.Step(`^the object should reach "([^"]*)" state within "([^"]*)"$`, s.theObjectShouldReachStateWithin)
}

// Thirdly, load all the scenarios, and dynamically creates Describe blocks for each feature
func registerFeatureTests() {
    scenariosDir := "../scenarios"

    // Discover all feature files
    features, err := discoverFeatures(scenariosDir)

    // Create a Describe block for each feature file with appropriate labels
    for _, feature := range features {
        // Capture feature in closure
        f := feature

        // Convert labels to Label() arguments
        ginkgoLabels := make([]interface{}, len(f.Labels))
        for i, label := range f.Labels {
            ginkgoLabels[i] = label
        }

        // Create Describe block with dynamic labels
        Describe(f.Name, Label(ginkgoLabels...), func() {
            var (
                ctx           context.Context
                dataFlowSteps *steps.DataFlowSteps
                commonSteps   *steps.CommonSteps
            )

            BeforeEach(func() {
                ctx = context.Background()
                // Initialize step definition handlers
                dataFlowSteps = steps.NewDataFlowSteps()
                commonSteps = steps.NewCommonSteps()
            })

            It("executes feature scenarios from: "+filepath.Base(f.Path), func() {
                GinkgoWriter.Printf("\nExecuting feature: %s\n", f.Path)
                GinkgoWriter.Printf("Labels: %v\n", f.Labels)

                // Create Godog test suite for this specific feature
                suite := godog.TestSuite{
                    ScenarioInitializer: func(sc *godog.ScenarioContext) {
                        // Register all step definitions
                        dataFlowSteps.RegisterSteps(sc)
                        commonSteps.RegisterSteps(sc)

                        // Scenario hooks
                        sc.Before(func(ctx context.Context, scenario *godog.Scenario) (context.Context, error) {
                            GinkgoWriter.Printf("\n--- Scenario: %s ---\n", scenario.Name)
                            return ctx, nil
                        })

                        sc.After(func(ctx context.Context, scenario *godog.Scenario, err error) (context.Context, error) {
                            // Cleanup after each scenario
                            if dataFlowSteps.CreatedObjectID != "" {
                                GinkgoWriter.Printf("Cleaning up object: %s\n", dataFlowSteps.CreatedObjectID)
                                _ = dataFlowSteps.Cleanup(ctx)
                            }
                            return ctx, nil
                        })
                    },
                    Options: &godog.Options{
                        Format:   "pretty",
                        Paths:    []string{f.Path},
                        TestingT: GinkgoT(),
                    },
                }

                // Run Godog scenarios
                status := suite.Run()
                if status != 0 {
                    Fail("Feature scenarios failed")
                }
            })
        })
    }
}
```

</details>

**Verdict:** While technically sound, Godog prioritizes auditability over development velocity. The Ginkgo + Markdown approach achieves similar traceability with better AI integration and developer experience.

---

### A.2 Other Frameworks Considered

**Testify:**
- Lightweight assertion library excellent for unit/integration tests
- Standard Go test integration with zero setup overhead
- **Not suitable for E2E**: Lacks hierarchical organization, parallel execution primitives, and built-in async polling (`Eventually`/`Consistently`)
- No support for eventual consistency testing in distributed systems
- Better suited for unit tests than distributed E2E orchestration

**Cucumber:**
- Industry standard for BDD but requires maintaining Ruby/JavaScript alongside Go
- Adds language complexity and deployment overhead without leveraging team's Go expertise

**Bruno:**
- Open-source API client for manual/semi-automated API testing
- Better suited for ad-hoc API exploration than systematic regression testing

**Markdown Style Test (ty pattern):**
- Python project using markdown files with embedded test assertions
- Designed for unit tests, not distributed E2E scenarios
- Lacks orchestration primitives for multi-service coordination
- Inspired our metadata anchor approach but not directly applicable to distributed systems complexity

---

## References
- [Ginkgo](https://github.com/onsi/ginkgo)
- [Gomega](https://github.com/onsi/gomega)
- [Cucumber for golang](https://github.com/cucumber/godog)
- [Gherkin](https://cucumber.io/docs/gherkin/)
- [Testify](https://github.com/stretchr/testify)
- [API testing tools](https://testguild.com/api-testing-tools/)
- [Bruno](https://github.com/usebruno/bruno/tree/main)
- [Markdown style test suite example of ty](https://github.com/astral-sh/ruff/blob/main/crates/ty_python_semantic/resources/mdtest/typed_dict.md)
- [OpenShift E2E Testing Repository](https://github.com/openshift/origin/)

---
