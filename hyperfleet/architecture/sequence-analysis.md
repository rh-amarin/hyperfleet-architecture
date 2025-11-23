# Architecture Doubts Analysis

This document analyzes the architectural doubts identified in `sequence.md` (marked with `???`) and proposes standard patterns and alternatives to resolve them.

## 1. Idempotency & Re-validation Events
**Locations:** 00:32, 00:42, 00:52, 01:02, 11:02, 41:02  
**Context:** The Validation Adapter receives a reconcile event for `generation=1`. It observes that a validation job (`validation-cls-123-gen1`) has already completed successfully.

**Doubt:** 
> "what to do here? how to differentiate this event, from one that deserves re-creating the job?"

### Situation Analysis
The adapter is stateless regarding the event trigger; it just sees the current state of the world. It sees a `Cluster` at `gen=1` and a completed `Job` for `gen=1`. 

### Alternatives
*   **Alternative A: Generation-based Idempotency (Recommended)**
    *   **Logic:** If a successful job exists specifically annotated/labeled with the current `generation`, do **not** re-run. Treat the validation as "Complete".
    *   **Pros:** Efficient. Aligns with Kubernetes "Level Triggered" logic. Prevents loops.
    *   **Cons:** Does not catch "drift" (e.g., if the external thing being validated changes but the Cluster spec doesn't).
<details>
<summary>📚 <strong>Detailed Example: Generation-Based Idempotency</strong></summary>

**Scenario:**  
A user creates a Cluster resource, which triggers a validation process. The `generation` field of the Cluster resource is incremented on every spec change.

#### Step-by-step Example

1. **Initial Creation:**
    - The Cluster is created with `generation=5`.
    - The Validation Adapter receives a reconcile event for `generation=5`.
    - It checks for an existing validation job labeled/annotated with `gen=5`.
    - _No such job exists_: Adapter creates a validation job for `gen=5`.

2. **Subsequent Reconcile Events (No Spec Change):**
    - The Cluster is still at `generation=5`.
    - The Validation Adapter is triggered again (e.g., by a periodic event or unrelated update).
    - It checks for a completed validation job for `gen=5`.
    - _Finds successful job for `gen=5`_: **No new job is created.**
    - Adapter simply reports the status as "validation complete for gen=5."

3. **No Further Spec Changes:**
    - If the user never changes the Cluster spec again, the `generation` remains at `5`.
    - The validation status for `gen=5` is reported repeatedly, but **the job is never recreated or updated**.

#### **Why Won't the Validation Be Updated Again?**

Because the adapter only reacts to changes in the `generation`—and only creates/updates the validation job if the Cluster's `generation` changes—there is **no automatic re-run or re-validation** for the same generation. This means the validation result is effectively _frozen_ for `gen=5`, and will **never be updated again** unless the user makes a change that bumps the Cluster's `generation`. This is the classic "level-triggered" pattern.

_If the external world drifts (e.g., validated resources change without an update to the Cluster spec), this approach will NOT catch it. Only a spec change will trigger new validation._

</details>

*   **Alternative B: Time-to-Live (TTL) Re-validation**
    *   **Logic:** If the job finished > X minutes ago, re-run it regardless of generation match.
    *   **Pros:** Ensures continuous compliance/drift detection.
    *   **Cons:** Expensive. Can cause flapping status.


*   **Alternative C: Hash/Checksum Verification**
    *   **Logic:** Instead of relying on `generation`, calculate a hash of the relevant spec fields. If the job's stored hash matches the current spec hash, skip.
    *   **Pros:** More precise than generation if generation increments for unrelated fields.

### Resolution
Adopt **Alternative A**. The `Sentinel` publishing periodic events (e.g., at 41:02) should effectively be a "No-Op" for the Validation Adapter if the generation matches. The adapter should simply report the existing successful status again (or do nothing if status is already correct).

---

## 2. Excessive Querying by Adapters
**Locations:** 00:52, 01:02, 11:02, 41:02  
**Context:** The DNS Adapter queries the existing DNS CRD every time it receives an event, even if it just did so recently.

**Doubt:** 
> "is this necessary for every event ?"

### Situation Analysis
Stateless adapters often query the "world" to decide what to do. However, querying external APIs or heavy CRDs on every loop can be inefficient.

### Alternatives
*   **Alternative A: Always Query (Naive)**
    *   **Logic:** Trust nothing but the live state.
    *   **Pros:** Robust against manual interference (e.g., someone manually deleting the DNS CRD).
    *   **Cons:** High API load. Performance bottleneck.
*   **Alternative B: Kubernetes Informers/Listers (Recommended)**
    *   **Logic:** The adapter should maintain a local cache (Informer) of the DNS CRDs. It checks the cache.
    *   **Pros:** Zero network cost for reads. Near real-time updates.
    *   **Cons:** Requires the adapter to be a long-running process with a Watch connection, not just a lambda/webhook.
*   **Alternative C: Trust Status**
    *   **Logic:** Check `Hyperfleet API` status. If it says `DNS_Available=True` and `observedGeneration` matches, assume it's done.
    *   **Pros:** Fast.
    *   **Cons:** Vulnerable to state drift (status says true, but actual CRD is gone).

### Resolution
If the DNS Adapter is a K8s Controller, use **Alternative B** (Informer). If it is a purely event-driven function (e.g., Knative), **Alternative A** is acceptable but should be guarded by a check: "Is my locally observed generation different from the Cluster generation?" or "Is the last check > X seconds ago?".

---

## 3. Reporting Status during Generation Transitions
**Location:** 42:02  
**Context:** User updates Cluster to `gen=2`. Validation Adapter starts a new job.
**Doubt:** 
> "should it report from: current job: gen=2 Applied=true Available=false, old job: gen=1 Applied=true Available=true, both?"

### Situation Analysis
The system is in a transition state. The "old" version is technically still running/valid, but the "new" version is requested (ObservedGeneration 2).

### Alternatives
*   **Alternative A: Strict Forward Progress (Recommended)**
    *   **Logic:** Report `observedGeneration=2`. Since the job for `gen=2` is not finished, report `Available=False`.
    *   **Pros:** Clearly signals that the *current desired state* is not yet ready. Standard Kubernetes behavior.
    *   **Cons:** The system looks "Not Ready" during updates.  <<-- this is problematic
*   **Alternative B: Dual Status (Progressive)**
    *   **Logic:** Report `observedGeneration=2`, but keep a separate field for `lastAvailableGeneration=1`.
    *   **Pros:** Allows UI to show "Update in progress" while keeping the "Service is up" indicator.

### Resolution
Adopt **Alternative A**. The `observedGeneration` must match the Cluster's generation to acknowledge receipt of the update. If we report `observedGeneration=1`, the Sentinel/Orchestrator assumes we haven't seen the update yet.

---

## 4. Synchronous Operations & Event Loops
**Location:** 42:02  
**Context:** DNS Adapter updates the CRD synchronously.
**Doubt:** 
> "patch is a synchronous operation... this adapter by itself does not retrigger a reconcile"

### Situation Analysis
The adapter modifies an external resource (DNS CRD). In K8s, writing to the API usually triggers watchers.

### Alternatives
*   **Alternative A: Rely on Status Update Trigger**
    *   **Logic:** The DNS Adapter reports its new status to `Hyperfleet API`. *That* write operation is an event. The Sentinel (or a watcher on Hyperfleet API) sees the status change and potentially re-triggers if needed (though usually status updates shouldn't trigger "reconcile" logic unless strict conditions met).
*   **Alternative B: Fire-and-Forget (Assumed)**
    *   **Logic:** If the operation is synchronous and successful, the adapter reports `Available=True` immediately. No further reconcile is needed for *this specific task*.
    *   **Pros:** Efficient.
*   **Alternative C: Re-queue**
    *   **Logic:** After a successful operation, explicitly request a re-queue.
    *   **Pros:** Safer if there are dependent steps.

### Resolution
**Alternative B** is likely correct here. Since the operation is synchronous, the adapter knows the result immediately. It reports `Available=True`. The system doesn't *need* another loop for the DNS adapter, though the Hyperfleet Adapter (downstream dependency) will need to be triggered by the status change to proceed.

