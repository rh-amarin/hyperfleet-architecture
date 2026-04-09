---
Status: Draft
Owner: HyperFleet Architecture Team
Last Updated: 2026-04-09
---

# Generic Resource Registry — Design Document

This document contains the proposal for the Generic Resource Registry and alternatives

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Design Overview](#2-design-overview)
3. [OpenAPI Contract](#3-openapi-contract)
   - [3.1 Core types](#31-core-types)
   - [3.2 Routes](#32-routes)
4. [Data Layer](#4-data-layer)
   - [4.1 GORM types](#41-gorm-types-pkgapiresourcego)
   - [4.2 Database schema](#42-database-schema)
   - [4.3 ResourceDao](#43-resourcedao-pkgdaoresourcego)
5. [Entity Registry](#5-entity-registry)
   - [5.1 EntityDescriptor](#51-entitydescriptor-pkgregistrydescriptorgo)
   - [5.2 Global registry](#52-global-registry-pkgregistryregistrygo)
   - [5.3 Entity configuration examples](#53-entity-configuration-examples)
   - [5.4 Href generation](#54-href-generation)
6. [Spec Field Validation](#6-spec-field-validation)
   - [6.1 Current implementation](#61-current-implementation)
   - [6.2 Additional OpenAPI contract](#62-additional-openapi-contract-spec-schemas)
7. [Handler Layer](#7-handler-layer)
   - [7.1 Shared presenter](#71-shared-presenter-pkgapipresentersresourcego)
   - [7.2 ResourceHandler](#72-resourcehandler-pkghandlersresourcego)
   - [7.3 ResourceStatusHandler](#73-resourcestatushandler-pkghandlersresource_statusgo)
   - [7.4 Auto route registration](#74-auto-route-registration-pkghandlersentity_routesgo)
8. [Delete Model for Owned Resources](#8-delete-model-for-owned-resources)
   - [8.1 Descriptor-driven delete policy](#81-descriptor-driven-delete-policy)
   - [8.2 Service layer implementation](#82-service-layer-implementation)
9. [No Migration, No Backward Compatibility](#9-no-migration-no-backward-compatibility)
10. [Alternatives and Tradeoffs](#10-alternatives-and-tradeoffs)
    - [10.1 Separate tables vs. JSONB for labels and conditions](#101-separate-tables-vs-jsonb-for-labels-and-conditions)
    - [10.2 Delete model for owned resources](#102-delete-model-for-owned-resources)
    - [10.3 Entity configuration: where entity types are defined](#103-entity-configuration-where-entity-types-are-defined)
    - [10.4 Naming the generic entity type](#104-naming-the-generic-entity-type)
    - [10.5 Computed vs. stored conditions](#105-computed-vs-stored-conditions)
    - [10.6 Child entity creation via the generic root endpoint](#106-child-entity-creation-via-the-generic-root-endpoint)
11. [Risks](#11-risks)

- [Appendix A. Current State](#appendix-a-current-state)
- [Appendix B. Authorization Design](#appendix-b-authorization-design)

---

## 1. Problem Statement

HyperFleet API currently has two managed entity types — Cluster and NodePool — and more are expected. Adding each new entity type requires changing the code, which is mostly duplicated code and releasing a new version.

This is not desirable since slows down HyperFleet customers willing to add new functionality and having to wait until these changes are coordinated and deployed

**Goals:**

- Streamline the process of adding new entities to the HyperFleet API
- New entity types require only registration code, no shared infrastructure changes.
- All routes, spec validation, status aggregation, and delete semantics are derived automatically from a declarative entity descriptor.
- The system supports hierarchical ownership (child entities accessible under parent routes) without per-entity handler code.

---

## 2. Design Overview

The design rests on three ideas:

1. **Generic OpenAPI contract**: the API exposes a single `Resource` response type.
    - The `spec` field is an untyped JSON object at the API layer;
    - Entity-specific spec shapes are validated by a separate schema contract file.
2. **Single Go type**: all entities share one GORM struct (`Resource`) with a `type` discriminator.
    - One `resources` table.
3. **Entity registry**: each entity type is described by an `EntityDescriptor` registered at startup.
    - The registry drives route generation, spec validation, status aggregation, and delete behavior.
    - Entities are defined in the configuration file

---

## 3. OpenAPI Contract

The main API contract moves from per-entity types (`Cluster`, `NodePool`) to a single generic `Resource` type. Entity-specific spec structure is validated separately (see §7).

The development approach is contract-first with the OpenAPI spec generated in the hyperfleet-api-spec repository and copied over to the hyperfleet-api repository.

In the future the hyperfleet-api may add more endpoints that are not managed Entities, and these will also follow contract-first approach.

### 3.1 Core types

<details>
<summary>OpenAPI type definitions (YAML)</summary>

```yaml
Resource:
  required: [id, type, name, spec, status, generation, created_time, updated_time, created_by, updated_by]
  properties:
    id:               { type: string }
    type:             { type: string }   # "Cluster", "NodePool", etc.
    kind:             { type: string }   # display name, usually same as type
    name:             { type: string }
    href:             { type: string }
    spec:             { type: object, additionalProperties: true }
    labels:           { type: object, additionalProperties: { type: string } }
    status:           { $ref: '#/components/schemas/ResourceStatus' }
    generation:       { type: integer, format: int32 }
    owner_references: { $ref: '#/components/schemas/ObjectReference' }  # optional
    created_time:     { type: string, format: date-time }
    updated_time:     { type: string, format: date-time }
    created_by:       { type: string, format: email }
    updated_by:       { type: string, format: email }

ResourceCreateRequest:
  required: [type, name, spec]
  properties:
    type:   { type: string }
    name:   { type: string }
    spec:   { type: object, additionalProperties: true }
    labels: { type: object, additionalProperties: { type: string } }

ResourcePatchRequest:
  properties:
    spec:   { type: object, additionalProperties: true }
    labels: { type: object, additionalProperties: { type: string } }

ResourceList:
  required: [items, total, size, page]
  properties:
    items: { type: array, items: { $ref: '#/components/schemas/Resource' } }
    total: { type: integer, format: int64 }
    size:  { type: integer, format: int32 }
    page:  { type: integer, format: int32 }

ResourceStatus:
  properties:
    conditions: { type: array, items: { $ref: '#/components/schemas/ResourceCondition' } }
```

</details>

Existing types `ResourceCondition`, `ObjectReference`, `AdapterStatus`, and `AdapterStatusList` are unchanged — they were already generic.

### 3.2 Routes

The API contract defines the routes for the `Resource` entity and methods:

```
# Top-level (all entity types)
GET                /api/hyperfleet/v1/resources
POST               /api/hyperfleet/v1/resources      # resources without parent
GET PATCH,DELETE   /api/hyperfleet/v1/resources/{id}
GET POST           /api/hyperfleet/v1/resources/{id}/statuses

```

Additionally, for each registered entity type, the following routes are generated:

```
# Top-level (all entity types)
GET POST           /api/hyperfleet/v1/{plural}
GET PATCH,DELETE   /api/hyperfleet/v1/{plural}/{id}
GET POST           /api/hyperfleet/v1/{plural}/{id}/statuses

# Nested (child entity types only — when ParentType != "")
GET POST           /api/hyperfleet/v1/[{parent-plural}/{parent_id}...]/{plural}
GET PATCH DELETE   /api/hyperfleet/v1/[{parent-plural}/{parent_id}...]/{plural}/{id}
GET POST           /api/hyperfleet/v1/[{parent-plural}/{parent_id}...]/{plural}/{id}/statuses
```

The `[ ...]` denotes the full hierarchy of parent resources.

Example with Cluster (top-level) and NodePool (parent: Cluster):

```
GET POST         /api/hyperfleet/v1/clusters
GET PATCH DELETE /api/hyperfleet/v1/clusters/{id}
GET POST         /api/hyperfleet/v1/clusters/{id}/statuses

GET POST         /api/hyperfleet/v1/node-pools
GET PATCH DELETE /api/hyperfleet/v1/node-pools/{id}
GET POST         /api/hyperfleet/v1/node-pools/{id}/statuses

GET POST         /api/hyperfleet/v1/clusters/{parent_id}/node-pools
GET PATCH DELETE /api/hyperfleet/v1/clusters/{parent_id}/node-pools/{id}
GET POST         /api/hyperfleet/v1/clusters/{parent_id}/node-pools/{id}/statuses
```

---

## 4. Data Layer

### 4.1 GORM types (`pkg/api/resource.go`)

`Labels` and `StatusConditions` are stored in dedicated tables rather than JSONB columns. The `Resource` struct holds them as GORM `HasMany` associations.

<details>
<summary>Resource GORM struct</summary>

```go
// Resource is the single Go type for all HyperFleet managed entities.
// Entity types are differentiated by the Type field (e.g., "Cluster", "NodePool").
type Resource struct {
    Meta                                // ID, CreatedTime, UpdatedTime, DeletedAt

    Type       string         `gorm:"column:type;size:100;not null"`
    Kind       string         `gorm:"column:kind;size:100;not null"`
    Name       string         `gorm:"column:name;size:100;not null"`
    Href       string         `gorm:"column:href;size:500"`
    CreatedBy  string         `gorm:"column:created_by;size:255;not null"`
    UpdatedBy  string         `gorm:"column:updated_by;size:255;not null"`

    // Parent reference — empty string for top-level entities
    OwnerID    string         `gorm:"column:owner_id;size:255"`
    OwnerType  string         `gorm:"column:owner_type;size:100"`
    OwnerHref  string         `gorm:"column:owner_href;size:500"`

    Spec       datatypes.JSON `gorm:"column:spec;not null"`
    Generation int32          `gorm:"column:generation;default:1;not null"`

    // Associations — stored in separate tables, loaded via Preload
    Labels     []ResourceLabel     `gorm:"foreignKey:ResourceID"`
    Conditions []ResourceCondition `gorm:"foreignKey:ResourceID"`
}

type ResourceList []Resource
```

</details>

**`ResourceLabel`** — one row per label key-value pair per resource:

```go
// ResourceLabel stores a single key-value label for a Resource.
// Table: resource_labels. Natural composite PK (resource_id, key) — no surrogate ID.
type ResourceLabel struct {
    ResourceID string `gorm:"primaryKey;column:resource_id;size:255"`
    Key        string `gorm:"primaryKey;column:key;size:255"`
    Value      string `gorm:"column:value;size:255;not null"`
}
```

**`ResourceCondition`** — one row per condition type per resource. Mirrors the OpenAPI `ResourceCondition` schema fields:

```go
// ResourceCondition stores a single status condition for a Resource.
// Table: resource_conditions. Natural composite PK (resource_id, type) — no surrogate ID.
type ResourceCondition struct {
    ResourceID         string    `gorm:"primaryKey;column:resource_id;size:255"`
    Type               string    `gorm:"primaryKey;column:type;size:255"`
    Status             string    `gorm:"column:status;size:50;not null"`  // "True", "False"
    Reason             string    `gorm:"column:reason;size:255"`
    Message            string    `gorm:"column:message;type:text"`
    ObservedGeneration int32     `gorm:"column:observed_generation;not null"`
    CreatedTime        time.Time `gorm:"column:created_time;not null"`
    LastUpdatedTime    time.Time `gorm:"column:last_updated_time;not null"`
    LastTransitionTime time.Time `gorm:"column:last_transition_time;not null"`
}
```

GORM lifecycle hooks (`BeforeCreate`, `BeforeUpdate`) on `Resource` handle ID generation, timestamp management, and generation initialization — identical to the current per-entity hook logic. Neither `ResourceLabel` nor `ResourceCondition` has a surrogate ID — both use natural composite PKs (`(resource_id, key)` and `(resource_id, type)` respectively) set by the DAO on insert.

### 4.2 Database schema

<details>
<summary>Table: resources</summary>

| Column | Type | Notes |
|---|---|---|
| `id` | `VARCHAR(255)` PK | RFC 4122 UUID v7 |
| `type` | `VARCHAR(100)` NOT NULL | Discriminator |
| `kind` | `VARCHAR(100)` NOT NULL | Display name |
| `name` | `VARCHAR(100)` NOT NULL | |
| `href` | `VARCHAR(500)` | Computed |
| `created_by` / `updated_by` | `VARCHAR(255)` | |
| `owner_id` | `VARCHAR(255)` | Empty string for top-level |
| `owner_type` / `owner_href` | `VARCHAR(100/500)` | |
| `spec` | `JSONB` NOT NULL | |
| `generation` | `INT4` DEFAULT 1 | |
| `created_time` / `updated_time` | `TIMESTAMPTZ` | |
| `deleted_at` | `TIMESTAMPTZ` | Soft delete |

`labels` and `status_conditions` are **not columns** on this table.

</details>

<details>
<summary>Table: resource_labels</summary>

| Column | Type | Notes |
|---|---|---|
| `resource_id` | `VARCHAR(255)` NOT NULL FK → `resources(id)` | Part of composite PK |
| `key` | `VARCHAR(255)` NOT NULL | Part of composite PK |
| `value` | `VARCHAR(255)` NOT NULL | |

Primary key: `(resource_id, key)` — enforces label key uniqueness per resource. No surrogate ID.

</details>

<details>
<summary>Table: resource_conditions</summary>

| Column | Type | Notes |
|---|---|---|
| `resource_id` | `VARCHAR(255)` NOT NULL FK → `resources(id)` | Part of composite PK |
| `type` | `VARCHAR(255)` NOT NULL | Part of composite PK — e.g., `"Ready"`, `"Available"`, `"Adapter1Successful"` |
| `status` | `VARCHAR(50)` NOT NULL | `"True"` or `"False"` |
| `reason` | `VARCHAR(255)` | |
| `message` | `TEXT` | |
| `observed_generation` | `INT4` NOT NULL | |
| `created_time` | `TIMESTAMPTZ` NOT NULL | |
| `last_updated_time` | `TIMESTAMPTZ` NOT NULL | |
| `last_transition_time` | `TIMESTAMPTZ` NOT NULL | |

Primary key: `(resource_id, type)` — enforces one condition per type per resource. No surrogate ID.

</details>

**Indexes:**

<details>
<summary>Database indexes</summary>

```sql
-- resources: name uniqueness per type for top-level entities
CREATE UNIQUE INDEX idx_resources_type_name
    ON resources (type, name)
    WHERE owner_id = '' AND deleted_at IS NULL;

-- resources: name uniqueness per type + owner for child entities
CREATE UNIQUE INDEX idx_resources_type_owner_name
    ON resources (type, owner_id, name)
    WHERE owner_id != '' AND deleted_at IS NULL;

-- resources: child lookups
CREATE INDEX idx_resources_owner_id ON resources (owner_id) WHERE owner_id != '';

-- resources: type filter (drives all list queries)
CREATE INDEX idx_resources_type ON resources (type);

-- resources: soft delete
CREATE INDEX idx_resources_deleted_at ON resources (deleted_at);

-- resource_labels: no extra index needed — the composite PK (resource_id, key) is the leading index
-- and covers all "WHERE resource_id = ?" queries efficiently.

-- resource_conditions: no extra index needed — the composite PK (resource_id, type) is the leading
-- index and covers all "WHERE resource_id = ?" queries efficiently. Uniqueness per (resource_id, type)
-- is enforced by the PK itself.
```

</details>

Name uniqueness is scoped **per entity type**: a Cluster named `"prod"` and a NodePool named `"prod"` can coexist. Two Clusters named `"prod"` cannot.

### 4.3 `ResourceDao` (`pkg/dao/resource.go`)

Single DAO interface replacing `ClusterDao` and `NodePoolDao`. All queries include `type = ?` as a scope condition. `Get` and `GetByOwner` always preload `Labels` and `Conditions`. List operations preload them via `GenericService`'s `Preload` chain.

<details>
<summary>ResourceDao interface</summary>

```go
type ResourceDao interface {
    // Get fetches a resource with its Labels and Conditions preloaded.
    Get(ctx context.Context, resourceType, id string) (*api.Resource, error)

    // GetByOwner fetches a resource and validates it belongs to the given owner.
    // Labels and Conditions are preloaded.
    GetByOwner(ctx context.Context, resourceType, id, ownerID string) (*api.Resource, error)

    // Create inserts the resource row, then inserts all Labels.
    // Conditions are empty on create; they are set later by UpdateConditions.
    Create(ctx context.Context, resource *api.Resource) (*api.Resource, error)

    // Replace updates the resource row and replaces all Labels (delete + insert).
    // Conditions are not touched by Replace; use UpdateConditions for that.
    // Increments Generation when Spec or Labels change.
    Replace(ctx context.Context, resource *api.Resource) (*api.Resource, error)

    // UpdateConditions replaces all ResourceCondition rows for the given resource.
    UpdateConditions(ctx context.Context, resourceID string, conditions []api.ResourceCondition) error

    Delete(ctx context.Context, resourceType, id string) error
    CountByOwner(ctx context.Context, resourceType, ownerID string) (int64, error)
    FindByType(ctx context.Context, resourceType string) (api.ResourceList, error)
    FindByTypeAndOwner(ctx context.Context, resourceType, ownerID string) (api.ResourceList, error)
    FindByIDs(ctx context.Context, ids []string) (api.ResourceList, error)
}
```

</details>

**Key implementation notes:**

- `Create` — inserts the resource row first (omitting associations), then bulk-inserts labels. Conditions are not inserted by the DAO; `ResourceService.Create` calls `UpdateStatusFromAdapters` immediately after to initialize them.
- `Replace` — fetches the existing row with its labels preloaded, increments `Generation` if either `Spec` or `Labels` changed, updates the resource row, then replaces labels with a delete + bulk-insert. Conditions are intentionally excluded; they are written only by `UpdateConditions`.


`UpdateConditions` — called exclusively by the status aggregation path. Replaces all condition rows for the resource atomically.

`Replace` and `UpdateConditions` are on separate code paths deliberately: `Replace` is called by user-initiated spec/label updates; `UpdateConditions` is called only by the status aggregation pipeline. This separation keeps user-writable and system-computed state from interfering.

---

## 5. Entity Registry

### 5.1 `EntityDescriptor` (`pkg/registry/descriptor.go`)

The descriptor is the complete, declarative definition of an entity type. Registering a descriptor is the only action needed to add a new entity type to the system.

Entity descriptors are loaded from the application's existing config YAML at startup and used to populate the registry. No Go code is required for standard entities.

<details>
<summary>EntityDescriptor struct</summary>

```go
// OnParentDeletePolicy determines what happens to a child entity when its parent is deleted.
type OnParentDeletePolicy string

const (
    // OnParentDeleteRestrict prevents deletion of the parent while this child exists (default).
    OnParentDeleteRestrict OnParentDeletePolicy = "restrict"
    // OnParentDeleteCascade soft-deletes this child when its parent is deleted.
    OnParentDeleteCascade OnParentDeletePolicy = "cascade"
)

// EntityDescriptor defines everything specific to a HyperFleet entity type.
// Registering a descriptor auto-generates all routes, spec validation,
// status aggregation, and delete behavior for that entity type.
type EntityDescriptor struct {
    // Type is the discriminator stored in Resource.Type.
    // Must be unique across all registered descriptors. e.g., "Cluster", "NodePool".
    Type string

    // Plural is the URL path segment for this entity's endpoints.
    // e.g., "clusters", "node-pools".
    Plural string

    // NameMinLen and NameMaxLen constrain the name field on Create and Patch.
    NameMinLen int
    NameMaxLen int

    // ParentType is the Type value of this entity's owner.
    // Empty string means this is a top-level entity (no parent route generated).
    // e.g., "" for Cluster; "Cluster" for NodePool.
    ParentType string

    // OnParentDelete determines what happens to this entity when its parent is deleted.
    // Only meaningful when ParentType != "".
    // OnParentDeleteRestrict (default): parent deletion is rejected with 409 if this entity exists.
    // OnParentDeleteCascade: this entity is soft-deleted when its parent is deleted.
    OnParentDelete OnParentDeletePolicy

    // RequiredAdapters lists the adapter names that must report for this entity's
    // Ready and Available conditions to be computed.
    RequiredAdapters []string

    // SearchDisallowedFields prevents specific fields from being used in TSL search.
    // Key and value are both the field name. e.g., {"spec": "spec"}.
    SearchDisallowedFields map[string]string

    // SpecSchemaName is the name of the schema component in the additional OpenAPI
    // contract (server.openapi_schema_path) used to validate the spec field on
    // Create and Patch requests.
    // Empty string = no spec validation (accept any JSON object).
    // e.g., "ClusterSpec", "NodePoolSpec".
    SpecSchemaName string

    // Authz defines per-operation authorization configuration.
    // nil = no authorization checks (current default for all entities).
    // OperationPermissions is expressible in the config file (plain string map).
    // ResourceCheck is Go-only (it is a function); entities requiring it must be registered via Register().
    Authz *EntityAuthzConfig
}
```

</details>

### 5.2 Global registry (`pkg/registry/registry.go`)

```go
func Register(d *EntityDescriptor)                       // panics on duplicate Type
func Get(entityType string) (*EntityDescriptor, bool)
func MustGet(entityType string) *EntityDescriptor        // panics if not found
func All() []*EntityDescriptor                           // all registered descriptors
func ChildrenOf(parentType string) []*EntityDescriptor   // descriptors with ParentType == parentType

// LoadFromConfig reads entity descriptors from the application config and registers them.
// Called during Env.Initialize() before route registration.
func LoadFromConfig(cfg config.ApplicationConfig)

// Validate checks all ParentType references resolve. Called at startup before
// the server accepts requests. Panics with a descriptive message on failure.
func Validate()
```

Descriptors are loaded from the application config file. The `Validate()` call in `Env.Initialize()` catches missing parent registrations or invalid/duplicated entries immediately at startup. Entities requiring custom `Authz` hooks can still be registered via `Register()` in Go code alongside config-loaded descriptors.

### 5.3 Entity configuration examples

Entity types are declared in the application's existing config YAML (e.g., `config.yaml`). No Go code is required for standard entities — only a new config entry and a redeploy.

```yaml
# In config.yaml — entities section
entities:
  - type: Cluster
    plural: clusters
    nameMinLen: 3
    nameMaxLen: 53
    specSchemaName: ClusterSpec
    requiredAdapters: [provisioner, lifecycle]
    searchDisallowedFields: [spec]

  - type: NodePool
    plural: node-pools
    nameMinLen: 3
    nameMaxLen: 15
    parentType: Cluster
    onParentDelete: cascade
    specSchemaName: NodePoolSpec
    requiredAdapters: [provisioner, lifecycle]
    searchDisallowedFields: [spec]
    authz:
      operationPermissions:
        GET: hyperfleet.node-pools.view
        POST: hyperfleet.node-pools.create
        PATCH: hyperfleet.node-pools.update
        DELETE: hyperfleet.node-pools.delete
```

That is all per-entity configuration required. No DAO, no service, no handler, no presenter, no Go code.

`authz.operationPermissions` is a plain string map and is fully expressible in config. `ResourceCheck` (per-resource ownership or tenant isolation logic) is a Go function and requires registering the descriptor via `Register()` — it cannot be declared in YAML.

### 5.4 Href generation

Each resource carries a relative `href` field that uniquely identifies it within the API. The href is computed once at creation time by the service layer using the entity's descriptor and its resolved parent chain and stored in the `resources.href` column. It is never recomputed after creation because the `id` (UUID) and the `Plural` path segment are both stable for the lifetime of the resource.

**Format:**

```
# Top-level entity
/api/hyperfleet/v1/{plural}/{id}

# Child entity — embeds the full parent path
/api/hyperfleet/v1/[{parent-plural}/{parent_id}...]/{plural}/{id}
```

Examples for a NodePool (parent: Cluster):

```
/api/hyperfleet/v1/clusters/c-abc123/node-pools/np-xyz789
```

The href is relative (no scheme or host). Clients that need an absolute URL prepend the base URL from their configuration. This avoids storing environment-specific hostnames in the database and prevents href staleness across environment promotions.

**Constraint: child entity creation requires parent context in the URL**

Because the child href embeds the parent ID, it can only be constructed correctly when the parent ID is known at the moment of creation. The parent ID is available in the URL path variable (`{parent_id}`) on the nested generated routes, but is absent from the generic root endpoint:

```
# Parent ID is in the URL — href can be constructed
POST /api/hyperfleet/v1/clusters/{parent_id}/node-pools   ✓

# No parent ID in the URL — href cannot be constructed
POST /api/hyperfleet/v1/resources                          ✗ (for child entity types)
```

**Design decision:** `POST /api/hyperfleet/v1/resources` is restricted to top-level entity types only (descriptors with `ParentType == ""`). Attempting to create a child entity type via the generic root endpoint returns `422 Unprocessable Entity` with a message directing the caller to the nested route. See §10.6 for the alternative considered.

---

## 6. Spec Field Validation

HyperFleet accepts JSON as the `spec` property of a `Resource`. To provider greater guarantees about the data being stored, a validation process is performed on the `spec` contents using a provider-specific OpenAPI schema with the full detail of the entities schemas.

### 6.1 Current implementation

`SchemaValidationMiddleware` (`pkg/middleware/schema_validation.go`) already validates the `spec` field of POST and PATCH requests before they reach the handler. It uses `SchemaValidator` (`pkg/validators/schema_validator.go`) to evaluate the spec against a named schema component in the OpenAPI YAML at `server.openapi_schema_path`.

The current implementation hardcodes the entity type → schema name mapping (`"cluster"` → `ClusterSpec`, `"nodepool"` → `NodePoolSpec`) and uses URL pattern matching to detect the entity type.

### 6.2 Additional OpenAPI contract (spec schemas)

A separate YAML file (configured via `server.openapi_schema_path`) contains provider-specific spec schemas for entities. This is the OpenAPI exposed to final customers, provided by the ROSA/GCP teams.

The `SpecSchemaName` field on `EntityDescriptor` replaces the hardcoded mapping allowing to specify the schema name in the provided OpenAPI schema

When registering the mappings, the validation function will validate that schemas for entities are present in the provided OpenAPI contract.

When a request is made (POST/PATCH) containing an `spec`, the mapping is used to extract the schema for validating the payload.

No changes to the middleware or validator are required, only how to extract the name of the schema to use from the entity registry.

---

## 7. Handler Layer

### 7.1 Shared presenter (`pkg/api/presenters/resource.go`)

Replaces all per-entity `ConvertCluster`, `PresentCluster`, `ConvertNodePool`, `PresentNodePool` functions.

<details>
<summary>ConvertResource + PresentResource</summary>

```go
func ConvertResource(
    req *openapi.ResourceCreateRequest,
    entityType, ownerID, ownerType, ownerHref, createdBy string,
) *api.Resource {
    specJSON, _ := json.Marshal(req.Spec)

    // Build []ResourceLabel from the request labels map.
    var labels []api.ResourceLabel
    for k, v := range req.Labels {
        labels = append(labels, api.ResourceLabel{Key: k, Value: v})
    }

    return &api.Resource{
        Type:      entityType,
        Kind:      entityType,
        Name:      req.Name,
        Spec:      specJSON,
        Labels:    labels,
        OwnerID:   ownerID,
        OwnerType: ownerType,
        OwnerHref: ownerHref,
        CreatedBy: createdBy,
        UpdatedBy: createdBy,
    }
}

func PresentResource(r *api.Resource) openapi.Resource {
    var spec map[string]interface{}
    json.Unmarshal(r.Spec, &spec)

    // Labels are typed structs from the resource_labels table — no JSON unmarshal needed.
    labels := make(map[string]string, len(r.Labels))
    for _, l := range r.Labels {
        labels[l.Key] = l.Value
    }

    // Conditions are typed structs from the resource_conditions table — no JSON unmarshal needed.
    result := openapi.Resource{
        Id: r.ID, Type: r.Type, Kind: r.Kind, Name: r.Name, Href: r.Href,
        Spec: spec, Labels: labels, Generation: r.Generation,
        CreatedTime: r.CreatedTime, UpdatedTime: r.UpdatedTime,
        CreatedBy: openapi_types.Email(r.CreatedBy),
        UpdatedBy: openapi_types.Email(r.UpdatedBy),
        Status: openapi.ResourceStatus{Conditions: toOpenAPIConditions(r.Conditions)},
    }
    if r.OwnerID != "" {
        result.OwnerReferences = &openapi.ObjectReference{
            Id: r.OwnerID, Kind: r.OwnerType, Href: r.OwnerHref,
        }
    }
    return result
}
```

</details>

### 7.2 `ResourceHandler` (`pkg/handlers/resource.go`)

A single handler struct, instantiated once per registered descriptor. Handles CRUD for one entity type via the `handlerConfig` pipeline.

<details>
<summary>ResourceHandler struct and method signatures</summary>

```go
type ResourceHandler struct {
    descriptor *registry.EntityDescriptor
    service    services.ResourceService
    generic    services.GenericService
}

// Top-level routes
func (h *ResourceHandler) List(w http.ResponseWriter, r *http.Request)
func (h *ResourceHandler) Create(w http.ResponseWriter, r *http.Request)
func (h *ResourceHandler) Get(w http.ResponseWriter, r *http.Request)
func (h *ResourceHandler) Patch(w http.ResponseWriter, r *http.Request)
func (h *ResourceHandler) Delete(w http.ResponseWriter, r *http.Request)

// Nested routes — child entity accessed under parent path
func (h *ResourceHandler) ListByOwner(w http.ResponseWriter, r *http.Request)
func (h *ResourceHandler) CreateWithOwner(w http.ResponseWriter, r *http.Request)
func (h *ResourceHandler) GetByOwner(w http.ResponseWriter, r *http.Request)
func (h *ResourceHandler) PatchByOwner(w http.ResponseWriter, r *http.Request)
func (h *ResourceHandler) DeleteByOwner(w http.ResponseWriter, r *http.Request)
```

</details>

Example — `GetByOwner` (child entity accessed via parent path):
<details>
<summary>GetByOwner handler</summary>

```go
func (h *ResourceHandler) GetByOwner(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    parentID, id := vars["parent_id"], vars["id"]

    handleGet(w, r, &handlerConfig{
        Action: func() (interface{}, *errors.ServiceError) {
            if err := h.checkOperationAuthz(r, http.MethodGet); err != nil { return nil, err }

            // Verify parent exists
            _, err := h.service.Get(r.Context(), h.descriptor.ParentType, parentID)
            if err != nil { return nil, err }

            resource, err := h.service.GetByOwner(r.Context(), h.descriptor.Type, id, parentID)
            if err != nil { return nil, err }

            if err := h.checkResourceAuthz(r, resource); err != nil { return nil, err }
            return presenters.PresentResource(resource), nil
        },
    })
}
```

</details>

Example — `Delete` (policy driven by descriptor, no query parameter):

<details>
<summary>Delete handler</summary>

```go
func (h *ResourceHandler) Delete(w http.ResponseWriter, r *http.Request) {
    id := mux.Vars(r)["id"]
    handleDelete(w, r, &handlerConfig{
        Action: func() (interface{}, *errors.ServiceError) {
            if err := h.checkOperationAuthz(r, http.MethodDelete); err != nil { return nil, err }
            return nil, h.service.Delete(r.Context(), h.descriptor.Type, id)
        },
    }, http.StatusNoContent)
}
```

</details>

### 7.3 `ResourceStatusHandler` (`pkg/handlers/resource_status.go`)

Handles `GET` and `POST` on `/{id}/statuses` for all entity types. The `{id}` path variable is the same whether accessed via a top-level or nested route.

<details>
<summary>ResourceStatus handler</summary>

```go
type ResourceStatusHandler struct {
    descriptor       *registry.EntityDescriptor
    resourceService  services.ResourceService
    adapterStatusSvc services.AdapterStatusService
}

func (h *ResourceStatusHandler) List(w http.ResponseWriter, r *http.Request)
func (h *ResourceStatusHandler) Create(w http.ResponseWriter, r *http.Request)
```

</details>

### 7.4 Auto route registration (`pkg/handlers/entity_routes.go`)

Called once from `cmd/hyperfleet-api/server/routes.go`, after config loading and `registry.Validate()` complete. Replaces all per-entity plugin route registration calls.

<details>
<summary>RegisterEntityRoutes</summary>

```go
func RegisterEntityRoutes(
    apiV1Router *mux.Router,
    resourceService services.ResourceService,
    adapterStatusService services.AdapterStatusService,
    genericService services.GenericService,
    authMiddleware auth.JWTMiddleware,
    authzMiddleware auth.AuthorizationMiddleware,
) {
    for _, descriptor := range registry.All() {
        h := NewResourceHandler(descriptor, resourceService, genericService, authzMiddleware)
        sh := NewResourceStatusHandler(descriptor, resourceService, adapterStatusService)

        base := "/" + descriptor.Plural
        r := apiV1Router.PathPrefix(base).Subrouter()
        r.HandleFunc("", h.List).Methods(http.MethodGet)
        r.HandleFunc("", h.Create).Methods(http.MethodPost)
        r.HandleFunc("/{id}", h.Get).Methods(http.MethodGet)
        r.HandleFunc("/{id}", h.Patch).Methods(http.MethodPatch)
        r.HandleFunc("/{id}", h.Delete).Methods(http.MethodDelete)
        r.HandleFunc("/{id}/statuses", sh.List).Methods(http.MethodGet)
        r.HandleFunc("/{id}/statuses", sh.Create).Methods(http.MethodPost)

        if descriptor.ParentType != "" {
            parent := registry.MustGet(descriptor.ParentType)
            pr := apiV1Router.PathPrefix("/" + parent.Plural + "/{parent_id}/" + descriptor.Plural).Subrouter()
            pr.HandleFunc("", h.ListByOwner).Methods(http.MethodGet)
            pr.HandleFunc("", h.CreateWithOwner).Methods(http.MethodPost)
            pr.HandleFunc("/{id}", h.GetByOwner).Methods(http.MethodGet)
            pr.HandleFunc("/{id}", h.PatchByOwner).Methods(http.MethodPatch)
            pr.HandleFunc("/{id}", h.DeleteByOwner).Methods(http.MethodDelete)
            pr.HandleFunc("/{id}/statuses", sh.List).Methods(http.MethodGet)
            pr.HandleFunc("/{id}/statuses", sh.Create).Methods(http.MethodPost)
        }
    }
}
```

</details>

---

## 8. Delete Model for Owned Resources

### 8.1 Descriptor-driven delete policy

Delete behavior for child entities is declared on the **child's** `EntityDescriptor` via `OnParentDelete`. This mirrors database foreign key semantics (`ON DELETE CASCADE` / `ON DELETE RESTRICT`) and keeps the policy co-located with the entity it governs. See §10.2 for alternatives considered.

```go
type OnParentDeletePolicy string

const (
    OnParentDeleteRestrict OnParentDeletePolicy = "restrict" // default
    OnParentDeleteCascade  OnParentDeletePolicy = "cascade"
)
```

When a resource is deleted, the service iterates all registered child types and applies each child's policy:

- **`restrict`** — if any active children of this type exist, return `409 Conflict`. No partial deletion occurs.
- **`cascade`** — soft-delete all children of this type recursively (DFS, innermost first) before deleting the parent.

Different child types of the same parent can have different policies. For example, a Cluster might have NodePools (`cascade`) and AuditLogs (`restrict`) — deleting the Cluster cascades to NodePools but is blocked if AuditLogs exist.

There is no caller-supplied query parameter. The API surface is simply:

```
DELETE /clusters/{id} → 204 No Content  (NodePools cascade)
                      → 409 Conflict    (if a restrict-policy child exists)
```

### 8.2 Service layer implementation

A single `Delete` method handles all cases. `DeleteCascade` is not a separate method.

<details>
<summary>Delete service implementation</summary>

```go
func (s *sqlResourceService) Delete(ctx context.Context, resourceType, id string) *errors.ServiceError {
    for _, child := range registry.ChildrenOf(resourceType) {
        count, _ := s.dao.CountByOwner(ctx, child.Type, id)
        if count == 0 {
            continue
        }
        switch child.OnParentDelete {
        case registry.OnParentDeleteCascade:
            children, _ := s.dao.FindByTypeAndOwner(ctx, child.Type, id)
            for _, c := range children {
                if err := s.Delete(ctx, c.Type, c.ID); err != nil {
                    return err
                }
            }
        default: // OnParentDeleteRestrict
            return errors.Conflict("HYPERFLEET-CNF-001",
                "cannot delete %s %q: has %d active %s(s)",
                resourceType, id, count, child.Type)
        }
    }
    return handleDeleteError(resourceType, s.dao.Delete(ctx, resourceType, id))
}
```

</details>

All deletions happen within the existing transaction-per-request middleware. The entire tree is soft-deleted atomically or not at all. If a restrict-policy child is found after some cascade-policy children have already been deleted, the transaction rolls back and nothing is persisted.

---

## 9. No Migration, No Backward Compatibility

The database is initialized from scratch. There is no existing data to migrate and no requirement to maintain API compatibility with the current per-entity endpoints.

**What this removes from the implementation scope:**

- Data migration SQL
- Parallel API versioning
- Backward-compatible field defaults or shims
- Feature flags for old/new code path switching

**Database migrations:**

```
202604080001_add_resources.go         — CREATE TABLE resources + indexes
202604080002_add_resource_labels.go   — CREATE TABLE resource_labels
202604080003_add_resource_conditions.go — CREATE TABLE resource_conditions
```

The `clusters` and `node_pools` tables are not dropped — the database is initialized from scratch with no pre-existing tables.

The `adapter_statuses` table is unchanged. Its `resource_type` column already stores the entity type string (`"Cluster"`, `"NodePool"`) and needs no migration.

---

## 10. Alternatives and Tradeoffs

This section documents the most critical design decisions, the alternatives considered, and why each was accepted or rejected.

### 10.1 Separate tables vs. JSONB for labels and conditions

**Chosen:** `resource_labels` and `resource_conditions` as dedicated tables with natural composite PKs.

**Alternative — Keep JSONB columns on `resources` (original design)**

Store `labels JSONB` and `status_conditions JSONB` on the `resources` row.

- Pro : No joins; simpler DAO with no association preloading
- Pro : Single-row reads for `Get`
- Con : Filtering by label key/value requires GIN index + JSONB operators (`@>`, `?`) — more complex queries
- Con : DB cannot enforce uniqueness of condition `type` per resource — duplicates possible
- Con : Updating a single condition requires full JSON replace at the application level
- Con : `UpdateConditions` and `Replace` write to the same column — status aggregation and user edits can race or interfere

---

### 10.2 Delete model for owned resources

**Chosen:** Descriptor-driven `OnParentDelete` policy on the child entity. See §8 for the implementation.

**Alternative A — Restrict only**

A parent cannot be deleted while it has active children. `409 Conflict` always; no cascade option.

- Pro : Safest; impossible to accidentally delete a tree
- Pro : Simplest service implementation — no cascade path
- Con : UX friction for deep hierarchies; caller must delete children bottom-up in multiple round trips

**Alternative B — Cascade always**

Deleting a parent immediately soft-deletes all descendants recursively, with no opt-out.

- Pro : Single operation removes the entire tree
- Con : Destructive with no warning; easy to delete large trees accidentally
- Con : A large tree (thousands of children) can cause the request to time out

**Alternative C — Caller-controlled cascade (`?cascade=true`) — previously chosen**

Default behavior is Restrict. The caller passes `?cascade=true` to opt into recursive soft-delete. `EntityDescriptor.AllowCascadeDelete` controls whether the flag is accepted.

```
DELETE /clusters/{id}              → 409 Conflict (has active children)
DELETE /clusters/{id}?cascade=true → 204 No Content
```

- Pro : Explicit: the caller signals intent at the call site
- Pro : Same DELETE endpoint; behavior toggled by a query parameter
- Con : Behavior is split between the API call and the descriptor — two places to understand
- Con : All children of a parent cascade or restrict uniformly; different policies per child type require multiple `AllowCascadeDelete` flags and more complex handler logic
- Con : Clients must know to pass the flag; forgetting it returns 409 even when cascade is the only sensible behavior

**Why chosen (descriptor-driven `OnParentDelete`):** The policy belongs to the child entity, not to the caller or the API call. Different child types of the same parent can legitimately require different behaviors — cascade for NodePools, restrict for hypothetical audit-log children — which a single `?cascade=true` flag cannot express. Placing the policy on the child's descriptor makes behavior inspectable at startup, eliminates a query parameter from the API surface, and keeps the `Delete` handler trivially simple.

We have to have in mind that there will be a hard deletion option with `?force=true` or similar that will cascade delete all entities from a root entity for administrative tasks.

---

### 10.3 Entity configuration: where entity types are defined

**Chosen:** Entity descriptors declared in the application's existing config YAML file. The server reads them at startup to populate the registry. No Go code is required for standard entities.

```yaml
# config.yaml — entities section
entities:
  - type: Cluster
    plural: clusters
    nameMinLen: 3
    nameMaxLen: 53
    specSchemaName: ClusterSpec
    requiredAdapters: [provisioner, lifecycle]
    searchDisallowedFields: [spec]
```

- Pro : Adding a standard entity requires only a new config entry and a redeploy — no Go code
- Pro : Config is readable, diffable, and reviewable without Go knowledge
- Pro : Integrates with existing config management — same file, same deployment tooling, same GitOps workflows
- Pro : `registry.Validate()` still catches misconfiguration (e.g., unknown `parentType`) at startup
- Con : Config schema must be defined, validated, and kept in sync with `EntityDescriptor` as the struct evolves
- Con : Route registration still happens at startup; config must be fully loaded before the router is built. No hot-reload without a server restart

**Why chosen (config file):** All current `EntityDescriptor` fields for Cluster and NodePool are plain config values — no custom `ValidateSpec` or `Authz` hooks exist. Defining entities in the application config eliminates all per-entity Go code while keeping the deployment and configuration model consistent. Entities needing custom hooks can still be registered programmatically alongside config-loaded descriptors. This is the right default; compiled Go descriptors remain available as an escape hatch.

**Alternative A — Kubernetes CRDs**

Entity types are defined as Kubernetes Custom Resource Definitions. The API server watches the cluster and dynamically loads/unloads entity descriptors as CRDs are applied or removed.

An alternative to watch the cluster is to have the list of CRD files in a folder at boot time to serve as configuration

```yaml
apiVersion: hyperfleet.io/v1alpha1
kind: EntityType
metadata:
  name: machinepool
spec:
  plural: machine-pools
  parentType: NodePool
  nameMinLen: 3
  nameMaxLen: 30
  specSchemaName: MachinePoolSpec
  requiredAdapters: [provisioner, lifecycle]
```

- Pro : Entity types can be added/removed at runtime without redeploying the API serv
- Pro : Standard Kubernetes extension mechanism — operators and GitOps workflows apply naturally
- Pro : CRD schema validation (via OpenAPI v3 in the CRD spec) can enforce descriptor correctness
- Con : Requires the API server to run inside (or alongside) a Kubernetes cluster — rules out bare-metal or non-k8s deployments
- Con : Dynamic route registration is fundamentally incompatible with gorilla/mux, which builds its routing tree at startup; routes cannot be added at runtime without restarting the router
- Con : Adds a hard dependency on the Kubernetes API and `controller-runtime` or `client-go` — significant operational complexity
- Con : Entity type changes become a cluster operation rather than a code change; harder to test locally
- Con : Duplication of OpenAPI schemas. Providers already have their OpenAPI schema for their external API but now they have to break the types into CRDs and keep them aligned.

**Alternative B — Entity types in a database table**

Entity types are stored in a `entity_types` table. The API server reads them at startup (or on each request) and builds descriptors dynamically.

- Pro : Entity types can be added without redeploying — a DB row insert is enough
- Pro : No Kubernetes dependency
- Pro : Standard CRUD tooling can manage entity type definitions
- Con : `RequiredAdapters` is a function of the runtime adapter config — it cannot be stored as a plain DB column; adapter requirements would need a separate join table or JSON column
- Con : Dynamic route registration has the same problem as CRDs: gorilla/mux cannot add routes after startup without a server restart
- Con : Behavior hooks (`ValidateSpec`, `Authz.ResourceCheck`) are Go functions — they cannot be stored in a DB row; only configuration can be persisted, not logic
- Con : The DB becomes a source of truth for schema-level concerns, coupling schema evolution (migrations) with runtime configuration
- Con : A misconfigured row (e.g., a `parentType` that doesn't exist) can corrupt the registry at runtime; the current design catches this at startup via `registry.Validate()`
- Con: When creating a new environment, we need to populate the database with the entities. This makes less descriptive/GitOps operations

**Alternative C — Compiled Go descriptors**

Entity types are declared as Go `EntityDescriptor` structs and registered at startup via `init()` — compiled directly into the binary.

```go
func init() {
    registry.Register(&registry.EntityDescriptor{
        Type:           "Cluster",
        Plural:         "clusters",
        NameMinLen:     3,
        NameMaxLen:     53,
        SpecSchemaName: "ClusterSpec",
        RequiredAdapters: func(cfg config.AdapterRequirementsConfig) []string {
            return cfg.RequiredClusterAdapters()
        },
        SearchDisallowedFields: map[string]string{"spec": "spec"},
    })
}
```

- Pro : Type-safe: compiler catches missing fields and type mismatches
- Pro : Behavior hooks (`Authz.ResourceCheck`, `RequiredAdapters` as a typed function) are natively expressible
- Pro : No config schema to define or keep in sync
- Con : Adding a new entity type requires a Go code change and a new release — no config-only path
- Con : `RequiredAdapters` as a function of runtime config is more indirection than needed for the current entity set
- Con : Per-entity `init()` registration in plugin packages creates coupling between plugin structure and registry bootstrapping

**Why not chosen:** All current entities (Cluster, NodePool) use only plain config values — no custom hooks exist. Requiring a Go change and release cycle for each new entity type adds unnecessary friction. The config file approach covers 100% of current use cases with less coupling. Go registration remains available as an escape hatch for entities that genuinely need behavior hooks.

---

### 10.4 Naming the generic entity type

The single Go/OpenAPI/DB type that unifies all entity kinds needs a name. This name appears in the API route (`/resources`), the OpenAPI schema (`Resource`), the Go struct (`Resource`), and the DB table (`resources`).

Some alternative names for `Resource` could be selected.

| Name | API route | Go type | DB table |
|---|---|---|---|
| **`Resource`** (chosen) | `/resources` | `Resource` | `resources` |
| `Entity` | `/entities` | `Entity` | `entities` |
| `ManagedEntity` | `/managed-entities` | `ManagedEntity` | `managed_entities` |
| `Object` | `/objects` | `Object` | `objects` |

**Chosen: `Resource`**

Standard REST vocabulary, recognized by API consumers across OpenAPI ecosystems and major cloud APIs (AWS, GCP, Azure all use "resource" for generic managed objects). The `type` discriminator field makes the concrete entity kind unambiguous regardless of the container name.

- Con : "resource" is already a broad REST term that can refer to any endpoint, not specifically this type
- Accepted : the `type` field disambiguates at the value level; callers always work with typed responses

**Alternative A — `Entity`**

Precise to the domain concept; avoids overloading the REST meaning of "resource".

- Pro : Maps cleanly to "entity" in domain modeling and the document's own language
- Con : Creates terminology collision with `EntityDescriptor` in the registry — two distinct concepts share the word "entity", which makes the doc and code harder to follow
- Con : Less familiar as an API surface term; most HTTP APIs use "resource" or "object"

**Alternative B — `ManagedEntity`**

Distinguishes HyperFleet-managed things from any other REST resources the API might expose.

- Pro : Explicitly signals lifecycle management intent
- Pro : Avoids collision with both REST "resource" and the registry's "entity"
- Con : Verbose everywhere: `/managed-entities`, `ManagedEntity`, `ManagedEntityList`, `managed_entities`, `managed_entity_labels` — all table and type names grow
- Con : The "managed" qualifier is implicit for everything served by this API; it adds no information

**Alternative C — `Object`**

Used by Kubernetes for all API objects (`metav1.Object`, object store, etc.).

- Pro : Familiar to teams coming from the Kubernetes ecosystem
- Con : Extremely generic — no domain signal at all
- Con : `Object` in Go conventionally suggests `interface{}` or an untyped value, which conflicts with the concrete, typed struct this represents
- Con : HyperFleet is not a Kubernetes API; importing Kubernetes naming without the Kubernetes machinery is likely to confuse rather than clarify

---

### 10.5 Computed vs. stored conditions

**Chosen:** Conditions are computed by `AggregateResourceStatus` when adapter statuses change and persisted to the `resource_conditions` table. Reads serve stored rows directly.

**Alternative — Compute conditions on every read**

The new design changed the Status Conditions from JSON to its own table. One additional change could be simplifying it or even eliminating and computing the values on request.

When a `GET` request arrives, fetch the resource row and its `adapter_statuses` rows, run `AggregateResourceStatus` in-process, and return the result without writing anything.

- Pro : Write path simplifies: `POST /{id}/statuses` writes one `adapter_statuses` row and returns — no aggregation, no secondary write
- Pro : Conditions are always current — no stale window between an adapter report and the next read
- Pro : Removes `resource_conditions` table, `ResourceDao.UpdateConditions`, and the two-step `Create` workflow that initializes conditions immediately after insert
- Pro : `ProcessAdapterStatus` becomes a pure single-row write with no side effects
- Con : **`LastTransitionTime` semantics break.** The field is only meaningful when compared against the previously stored status. Without history, you can only report the time the adapter last wrote — not when the condition actually transitioned.
- Con : **`CreatedTime` semantics break.** Currently preserved from the first time a condition appears. Without storage there is no record of when a condition type first existed.
- Con : Every `GET /{id}` now requires two reads: resource row + `adapter_statuses`. Currently a single preloaded read suffices.
- Con : List queries become heavier: a page of N resources requires fetching `adapter_statuses` for all N IDs (one batched query, but significantly more data).
- Con : Aggregation cost moves from writes (amortized, triggered only on change) to reads (on every request). Under read-heavy workloads this increases CPU and DB load proportionally to request rate.

**Why not chosen:** `LastTransitionTime` and `CreatedTime` are the blocking issue. Both fields record *when* something happened — information that cannot be derived from the current adapter reports alone. Dropping them would be a breaking API contract change and would remove signals that operators rely on to understand how long a cluster has been in a degraded state. Preserving them requires storing at least the previous condition state per resource, which is what the `resource_conditions` table does. Any lighter alternative (e.g., storing only transition timestamps) offers marginal savings while keeping most of the complexity.

If the API contract were ever relaxed to remove `LastTransitionTime` and `CreatedTime`, this approach becomes viable and would meaningfully simplify the write path.

---

### 10.6 Child entity creation via the generic root endpoint

**Chosen:** `POST /api/hyperfleet/v1/resources` is restricted to top-level entity types. Child entities must be created through their generated nested route (`POST /{parent-plural}/{parent_id}/{plural}`), which provides the parent ID in the URL. Attempting to create a child type via the root endpoint returns `422 Unprocessable Entity`.

**Why this constraint exists:** The child's `href` embeds the parent ID (e.g., `/api/hyperfleet/v1/clusters/c-abc/node-pools/np-xyz`). The parent ID is only available from the URL path on the nested route. Without it, the service cannot construct a correct, stable href at creation time.

**Alternative — Accept `owner_references` in `ResourceCreateRequest` for child entities**

Extend `ResourceCreateRequest` with an optional `owner_references` field:

```yaml
ResourceCreateRequest:
  required: [type, name, spec]
  properties:
    type:             { type: string }
    name:             { type: string }
    spec:             { type: object, additionalProperties: true }
    labels:           { type: object, additionalProperties: { type: string } }
    owner_references: { $ref: '#/components/schemas/ObjectReference' }  # optional
```

The service would validate that `owner_references` is present and refers to a valid parent when the entity type has a `ParentType`, then use it to look up the parent resource and construct the child href.

- Pro : The generic `POST /resources` endpoint works uniformly for all entity types — no need for callers to discover and use nested routes
- Con : The request body becomes the authority on ownership — a caller could supply an incorrect or unauthorized parent ID. The nested route derives ownership from the URL, which is easier to authorize via middleware
- Con : `ResourceCreateRequest` becomes partially entity-aware: the `owner_references` field is required for child types and meaningless for top-level types, with no schema-level enforcement of that distinction
- Con: Goes against common REST conventions

**Why not chosen:** The nested routes already encode ownership structurally. Allowing root-level creation of child entities trades route clarity for endpoint uniformity and introduces ownership validation concerns that the URL-based approach avoids by construction.

---

## 11. Risks

### R1 — Single-table database performance

All entity types share the `resources` table. As the number of entity types and total row count grows, queries that filter by `type` (every list operation) compete for the same table, indexes, and WAL. A burst of writes for one entity type increases I/O pressure for all others.

**Remediation:** The `idx_resources_type` index covers the common filter path and limits full-table scans. If a single entity type grows to dominate the table (tens of millions of rows), PostgreSQL declarative partitioning by the `type` column can be applied without changing the application — the table structure and GORM struct are unchanged. Monitor per-type row counts and query latency from the start so partitioning can be introduced before it becomes urgent.

---

### R2 — Loss of domain modeling flexibility

The generic `EntityDescriptor` captures configuration (name constraints, adapters, spec schema, delete policy) but has no slot for entity-specific business logic — pre-create validation, state machine transitions, cross-entity consistency checks, or derived fields. If a future entity type requires rules that go beyond what the descriptor fields can express, there is no standard extension point.

**Remediation:** The Go `Register()` path is the intended escape hatch: an entity that needs custom logic registers its descriptor in code rather than config, and the relevant service methods can be overridden by wrapping `ResourceService` with a type-specific decorator. The pattern should be documented so teams know how to extend without forking the shared infrastructure. If multiple entities accumulate custom logic, introduce a `Hooks` field on `EntityDescriptor` with well-defined `BeforeCreate`, `BeforeDelete`, and `AfterStatusUpdate` callbacks.

**Remediation 2:** If business logic required is not too complex, a CEL expression engine can be added to perform certain checks on entities and customizable through the registry.


---

## Appendix A. Current State

Context on the pre-generalization codebase — the duplication that motivates this design.

### A.1 Entity anatomy

Both Cluster and NodePool share the following structure across all layers:

| Layer | Shared fields / behavior |
|---|---|
| GORM model | `Meta` (ID, timestamps, soft delete), `Kind`, `Name`, `Href`, `CreatedBy`, `UpdatedBy`, `Spec` (JSONB), `Labels` (JSONB), `StatusConditions` (JSONB), `Generation` |
| DAO interface | `Get`, `Create`, `Replace`, `Delete`, `FindByIDs`, `All` |
| Service interface | `Get`, `Create`, `Replace`, `Delete`, `All`, `FindByIDs`, `UpdateStatusFromAdapters`, `ProcessAdapterStatus` |
| Handler | `List`, `Get`, `Create`, `Patch`, `Delete` via `handlerConfig` pipeline |
| Plugin | `RegisterService`, `RegisterRoutes`, `RegisterPath`, `RegisterKind` |

### A.2 What differs per entity

| Dimension | Cluster | NodePool |
|---|---|---|
| Name max length | 53 chars | 15 chars |
| Parent reference | None (top-level) | `owner_id` → Cluster |
| Name uniqueness scope | Global per type | Per parent per type |
| Route prefix | `/clusters` | `/clusters/{id}/node-pools` |
| Adapter config accessor | `RequiredClusterAdapters()` | `RequiredNodePoolAdapters()` |
| Spec schema name | `ClusterSpec` | `NodePoolSpec` |

### A.3 Existing generic abstractions (must be preserved and extended)

- `pkg/dao/generic.go` — chainable query builder for List (pagination, TSL search, ordering, joins)
- `pkg/services/generic.go` — reflection-based List with JSONB field support (~417 lines)
- `pkg/services/aggregation.go` — `AggregateResourceStatus()` is fully entity-agnostic
- `pkg/api/adapter_status_types.go` — `AdapterStatus` already uses `ResourceType` + `ResourceID` for polymorphism
- `pkg/middleware/schema_validation.go` — validates `spec` field against a named OpenAPI schema component
- `pkg/validators/schema_validator.go` — loads and evaluates OpenAPI schema components

### A.4 Code duplication quantified

| Layer | Lines per entity | Duplication |
|---|---|---|
| DAO (`cluster.go` / `node_pool.go`) | ~102 | ~95% |
| Service (`cluster.go` / `node_pool.go`) | ~310 | ~80% |
| Presenter (`cluster.go` / `node_pool.go`) | ~150 | ~85% |
| Plugin + handler | ~270 | ~75% |
| **Total** | **~832** | |

---

## Appendix B. Authorization Design

> **Note:** The current version of HyperFleet API contains inherited authorization code but it is not part of the official feature set. Implementation of this section is optional.

Authorization is opt-in per entity type. When `EntityDescriptor.Authz` is `nil`, no authorization checks are performed — the handler incurs only two nil pointer checks per request.

### B.1 `EntityAuthzConfig` (`pkg/registry/authz.go`)

<details>
<summary>EntityAuthzConfig struct</summary>

```go
// EntityAuthzConfig defines authorization requirements for an entity type.
// nil means no authorization checks are performed for this entity.
//
// Split expressibility:
//   - OperationPermissions: plain string map — expressible in config YAML.
//   - ResourceCheck: Go function — requires descriptor registration in Go code.
type EntityAuthzConfig struct {
    // OperationPermissions maps HTTP method to a permission identifier.
    // Only listed methods have permission checks applied.
    // Expressible in the config YAML under authz.operationPermissions.
    //
    // Example:
    //   http.MethodGet:    "hyperfleet.clusters.view"
    //   http.MethodPost:   "hyperfleet.clusters.create"
    //   http.MethodPatch:  "hyperfleet.clusters.update"
    //   http.MethodDelete: "hyperfleet.clusters.delete"
    OperationPermissions map[string]string

    // ResourceCheck is an optional hook for per-resource authorization logic.
    // Called after the operation permission check passes.
    // resource is nil for List operations (no single resource in scope).
    // Use this for ownership checks, tenant isolation, etc.
    // Cannot be expressed in config — requires Go registration via Register().
    ResourceCheck func(r *http.Request, resource *api.Resource) *errors.ServiceError
}
```

</details>

### B.2 Check pattern in handlers

<details>
<summary></summary>

```go
func (h *ResourceHandler) checkOperationAuthz(r *http.Request, method string) *errors.ServiceError {
    if h.descriptor.Authz == nil { return nil }
    perm, ok := h.descriptor.Authz.OperationPermissions[method]
    if !ok { return nil }
    return h.authzMiddleware.CheckPermission(r.Context(), perm)
}

func (h *ResourceHandler) checkResourceAuthz(r *http.Request, resource *api.Resource) *errors.ServiceError {
    if h.descriptor.Authz == nil || h.descriptor.Authz.ResourceCheck == nil { return nil }
    return h.descriptor.Authz.ResourceCheck(r, resource)
}
```

</details>

Operation permission is checked before any DAO call (fast path). Resource-level check is called after the resource is fetched (has access to resource fields).

### B.3 Enabling auth for an entity

No handler or infrastructure changes are needed.

**Config-only (operation permissions):** For standard entities, `operationPermissions` is a plain string map and can be declared in the config YAML. This covers the common case of per-operation access control with no Go code required.

<details>
<summary>Config-based auth (operationPermissions only)</summary>

```yaml
entities:
  - type: Cluster
    plural: clusters
    # ...
    authz:
      operationPermissions:
        GET: hyperfleet.clusters.view
        POST: hyperfleet.clusters.create
        PATCH: hyperfleet.clusters.update
        DELETE: hyperfleet.clusters.delete
```

</details>

**Go registration (ResourceCheck):** Entities that also need per-resource ownership or tenant isolation logic register the descriptor in Go. `ResourceCheck` is a function and cannot be expressed in YAML.

<details>
<summary>Go-based auth (ResourceCheck escape hatch)</summary>

```go
registry.Register(&registry.EntityDescriptor{
    Type:   "Cluster",
    Plural: "clusters",
    // ...
    Authz: &registry.EntityAuthzConfig{
        OperationPermissions: map[string]string{
            http.MethodGet:    "hyperfleet.clusters.view",
            http.MethodPost:   "hyperfleet.clusters.create",
            http.MethodPatch:  "hyperfleet.clusters.update",
            http.MethodDelete: "hyperfleet.clusters.delete",
        },
        ResourceCheck: func(r *http.Request, resource *api.Resource) *errors.ServiceError {
            org := auth.GetOrgFromContext(r.Context())
            if resource.Labels["org"] != org {
                return errors.Forbidden("HYPERFLEET-FBD-001", "resource belongs to a different organization")
            }
            return nil
        },
    },
})
```

</details>
