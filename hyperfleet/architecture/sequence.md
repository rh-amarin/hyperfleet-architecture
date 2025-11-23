# Happy path


00:00 - User: creates Cluster (generation=1)
00:00 - Hyperfleet API: creates Cluster (gen=1)
00:01 - Sentinel: polls, sees phase=NotReady, lastUpdated=any generation=any
  00:01 - Sentinel: publishes reconcile event (gen=1)
00:02 - Validation adapter: receives event
  00:02 - Validation adapter:  fetches Cluster (gen=1)
  00:02 - Validation adapter: checks: no existing job
  00:02 - Validation adapter: creates job "validation-cls-123-gen1" 🟢
  00:02 - Validation adapter: reports: observedGeneration=1, Applied=True 🟢, Available=False
    00:03 - Hyperfleet API: stores validation adapter status: 
            observedGeneration=1, Applied=True, Available=False
            created_at=00:02 last_updated_time=00:02
00:02 - DNS adapter: receives event
  00:02 - DNS adapter: fetches Cluster (gen=1)
  00:02 - DNS adapter: checks preconditions: validation_Available=false
  00:02 - DNS adapter: reports: observedGeneration=1, Applied=False 🟢, Available=False
    00:03 - Hyperfleet API: stores DNS adapter status:
            observedGeneration=1, Applied=False, Available=False
            created_at=00:02 last_updated_time=00:02
00:02 - Hyperfleet adapter: receives event
  00:02 - Hyperfleet adapter: fetches Cluster (gen=1)
  00:02 - Hyperfleet adapter: checks preconditions: validation_Available=false, DNS_Available=false
  00:02 - Hyperfleet adapter: reports: observedGeneration=1, Applied=False🟢, Available=False
    00:03 - Hyperfleet API: stores Hyperfleet adapter status:
          - observedGeneration=1, Applied=False, Available=False
          - created_at=00:02 last_updated_time=00:02

       ---  validaton k8s job already running 

00:11 - Sentinel: polls, sees phase=NotReady, lastUpdated=any generation=any
  00:11 - Sentinel: publishes reconcile event (gen=1)
00:12 - Validation adapter: receives event
  00:12 - Validation adapter: fetches Cluster (gen=1)
  00:12 - Validation adapter: checks: existing job running 🟢
  00:12 - Validation adapter: reports: observedGeneration=1, Applied=True, Available=False
    00:13 - Hyperfleet API: stores validation adapter status: 
          - observedGeneration=1, Applied=True, Available=False
          - created_at=00:02 last_updated_time=00:12
00:12 - DNS adapter: receives event
  00:12 - DNS adapter: fetches Cluster (gen=1)
  00:12 - DNS adapter: checks preconditions: validation_Available=false
  00:12 - DNS adapter: reports: observedGeneration=1, Applied=False, Available=False
    00:13 - Hyperfleet API: stores DNS adapter status: 
          - observedGeneration=1, Applied=False, Available=False
          - created_at=00:02 last_updated_time=00:12
00:12 - Hyperfleet adapter: receives event
  00:12 - Hyperfleet adapter: fetches Cluster (gen=1)
  00:12 - Hyperfleet adapter: checks preconditions: validation_Available=false, DNS_Available=false
  00:12 - Hyperfleet adapter: reports: observedGeneration=1, Applied=False, Available=False
    00:13 - Hyperfleet API: stores Hyperfleet adapter status: 
          - observedGeneration=1, Applied=False, Available=False
          - created_at=00:02 last_updated_time=00:12

       ---  validaton k8s job finished 

00:21 - Sentinel: polls, sees phase=NotReady, lastUpdated=any generation=any
  00:21 - Sentinel: publishes reconcile event (gen=1)
00:22 - Validation adapter: receives event
  00:22 - Validation adapter: fetches Cluster (gen=1)
  00:22 - Validation adapter: checks: existing job finished OK 🟢
  00:22 - Validation adapter: reports: observedGeneration=1, Applied=True, Available=True
    00:23 - Hyperfleet API: stores validation adapter status: 
            observedGeneration=1, Applied=True, Available=True
            created_at=00:02 last_updated_time=00:22
00:22 - DNS adapter: receives event
  00:22 - DNS adapter: fetches Cluster (gen=1)
  00:22 - DNS adapter: checks preconditions: validation_Available=false
  00:22 - DNS adapter: reports: observedGeneration=1, Applied=False, Available=False
    00:23 - Hyperfleet API: stores DNS adapter status: 
          - observedGeneration=1, Applied=False, Available=False
          - created_at=00:02 last_updated_time=00:22
00:22 - Hyperfleet adapter: receives event
  00:22 - Hyperfleet adapter: fetches Cluster (gen=1)
  00:22 - Hyperfleet adapter: checks preconditions: validation_Available=false, DNS_Available=false
  00:22 - Hyperfleet adapter: reports: observedGeneration=1, Applied=False, Available=False
    00:23 - Hyperfleet API: stores Hyperfleet adapter status: 
          - observedGeneration=1, Applied=False, Available=False
          - created_at=00:02 last_updated_time=00:22

--- validation_Available=true

00:31 - Sentinel: polls, sees phase=NotReady, lastUpdated=any generation=any
  00:31 - Sentinel: publishes reconcile event (gen=1)
00:32 - Validation adapter: receives event
  00:32 - Validation adapter: fetches Cluster (gen=1)
  00:32 - Validation adapter: checks: existing job finished OK
        - ??? what to do here? 
        how to differentiate this event, from one that deserves re-creating the job?
  00:32 - Validation adapter: reports: observedGeneration=1, Applied=True, Available=True
    00:33 - Hyperfleet API: stores validation adapter status: 
          - observedGeneration=1, Applied=True, Available=True
          - created_at=00:02 last_updated_time=00:32
00:32 - DNS adapter: receives event
  00:32 - DNS adapter: fetches Cluster (gen=1)
  00:32 - DNS adapter: checks preconditions: validation_Available=true
  00:32 - DNS adapter: creates DNS CRD 🟢
  00:32 - DNS adapter: reports: observedGeneration=1, Applied=true, Available=False
    00:33 - Hyperfleet API: stores DNS adapter status: 
          - observedGeneration=1, Applied=True, Available=False
          - created_at=00:02 last_updated_time=00:32
00:32 - Hyperfleet adapter: receives event
  00:32 - Hyperfleet adapter: fetches Cluster (gen=1)
  00:32 - Hyperfleet adapter: checks preconditions: validation_Available=true, DNS_Available=false
  00:32 - Hyperfleet adapter: reports: observedGeneration=1, Applied=False, Available=False
    00:33 - Hyperfleet API: stores Hyperfleet adapter status: 
          - observedGeneration=1, Applied=False, Available=False
          - created_at=00:02 last_updated_time=00:32

---  DNS CRD is ready

00:41 - Sentinel: polls, sees phase=NotReady, lastUpdated=any generation=any
  00:41 - Sentinel: publishes reconcile event (gen=1)
00:42 - Validation adapter: receives event
  00:42 - Validation adapter: fetches Cluster (gen=1)
  00:42 - Validation adapter: checks: existing job finished OK
        - ??? what to do here? 
        how to differentiate this event, from one that deserves re-creating the job?
  00:42 - Validation adapter: reports: observedGeneration=1, Applied=True, Available=True
    00:43 - Hyperfleet API: stores validation adapter status: 
          - observedGeneration=1, Applied=True, Available=True
          - created_at=00:02 last_updated_time=00:42
00:42 - DNS adapter: receives event
  00:42 - DNS adapter: fetches Cluster (gen=1)
  00:42 - DNS adapter: checks preconditions: validation_Available=true
  00:42 - DNS adapter: queries existing DNS CRD 🟢
  00:42 - DNS adapter: reports: observedGeneration=1, Applied=true, Available=True
    00:43 - Hyperfleet API: stores DNS adapter status: 
          - observedGeneration=1, Applied=True, Available=True 🟢
          - created_at=00:02 last_updated_time=00:42
          - data_DNS=whatever.domain.com 🟢
00:42 - Hyperfleet adapter: receives event
  00:42 - Hyperfleet adapter: fetches Cluster (gen=1)
  00:42 - Hyperfleet adapter: checks preconditions: validation_Available=true, DNS_Available=false
  00:42 - Hyperfleet adapter: reports: observedGeneration=1, Applied=False, Available=False
    00:43 - Hyperfleet API: stores Hyperfleet adapter status: 
          - observedGeneration=1, Applied=False, Available=False
          - created_at=00:02 last_updated_time=00:42

---  validation and DNS Available

00:51 - Sentinel: polls, sees phase=NotReady, lastUpdated=any generation=any
  00:51 - Sentinel: publishes reconcile event (gen=1)
00:52 - Validation adapter: receives event
  00:52 - Validation adapter: fetches Cluster (gen=1)
  00:52 - Validation adapter: checks: existing job finished OK
        - ??? what to do here? 
        how to differentiate this event, from one that deserves re-creating the job?
  00:52 - Validation adapter: reports: observedGeneration=1, Applied=True, Available=True
    00:53 - Hyperfleet API: stores validation adapter status: 
          - observedGeneration=1, Applied=True, Available=True
          - created_at=00:02 last_updated_time=00:52
00:52 - DNS adapter: receives event
  00:52 - DNS adapter: fetches Cluster (gen=1)
  00:52 - DNS adapter: checks preconditions: validation_Available=true
  00:52 - DNS adapter: queries existing DNS CRD 
          ??? is this necessary for every event ?
  00:52 - DNS adapter: reports: observedGeneration=1, Applied=true, Available=True
    00:53 - Hyperfleet API: stores DNS adapter status: 
          - observedGeneration=1, Applied=True, Available=True 
          - created_at=00:02 last_updated_time=00:52
          - data_DNS=whatever.domain.com 
00:52 - Hyperfleet adapter: receives event
  00:52 - Hyperfleet adapter: fetches Cluster (gen=1)
  00:52 - Hyperfleet adapter: checks preconditions: validation_Available=true, DNS_Available=true
  00:52 - Hyperfleet adapter: creates ACM job 🟢
  00:52 - Hyperfleet adapter: reports: observedGeneration=1, Applied=true🟢, Available=False
    00:53 - Hyperfleet API: stores Hyperfleet adapter status: 
          - observedGeneration=1, Applied=true, Available=False
          - created_at=00:02 last_updated_time=00:52

---  Cluster creation in progress, not yet ready (this repeats for minutes )

01:01 - Sentinel: polls, sees phase=NotReady, lastUpdated=any generation=any
  01:01 - Sentinel: publishes reconcile event (gen=1)
01:02 - Validation adapter: receives event
  01:02 - Validation adapter: fetches Cluster (gen=1)
  01:02 - Validation adapter: checks: existing job finished OK
        - ??? what to do here? 
        how to differentiate this event, from one that deserves re-creating the job?
  01:02 - Validation adapter: reports: observedGeneration=1, Applied=True, Available=True
    01:03 - Hyperfleet API: stores validation adapter status: 
          - observedGeneration=1, Applied=True, Available=True
          - created_at=00:02 last_updated_time=01:02
01:02 - DNS adapter: receives event
  01:02 - DNS adapter: fetches Cluster (gen=1)
  01:02 - DNS adapter: checks preconditions: validation_Available=true
  01:02 - DNS adapter: queries existing DNS CRD 
          ??? is this necessary for every event ?
  01:02 - DNS adapter: reports: observedGeneration=1, Applied=true, Available=True
    01:03 - Hyperfleet API: stores DNS adapter status: 
          - observedGeneration=1, Applied=True, Available=True 
          - created_at=00:02 last_updated_time=01:02
          - data_DNS=whatever.domain.com 
01:02 - Hyperfleet adapter: receives event
  01:02 - Hyperfleet adapter: fetches Cluster (gen=1)
  01:02 - Hyperfleet adapter: checks preconditions: validation_Available=true, DNS_Available=true
  01:02 - Hyperfleet adapter: queries ACM job 🟢
  01:02 - Hyperfleet adapter: reports: observedGeneration=1, Applied=true, Available=False
    01:03 - Hyperfleet API: stores Hyperfleet adapter status: 
          - observedGeneration=1, Applied=true, Available=False
          - created_at=00:02 last_updated_time=01:02

--- Cluster is ready for ACM

11:01 - Sentinel: polls, sees phase=NotReady, lastUpdated=any generation=any
  11:01 - Sentinel: publishes reconcile event (gen=1)
11:02 - Validation adapter: receives event
  11:02 - Validation adapter: fetches Cluster (gen=1)
  11:02 - Validation adapter: checks: existing job finished OK
        - ??? what to do here? 
        how to differentiate this event, from one that deserves re-creating the job?
  11:02 - Validation adapter: reports: observedGeneration=1, Applied=True, Available=True
    11:03 - Hyperfleet API: stores validation adapter status: 
          - observedGeneration=1, Applied=True, Available=True
          - created_at=00:02 last_updated_time=11:02
11:02 - DNS adapter: receives event
  11:02 - DNS adapter: fetches Cluster (gen=1)
  11:02 - DNS adapter: checks preconditions: validation_Available=true
  11:02 - DNS adapter: queries existing DNS CRD 
          ??? is this necessary for every event ?
  11:02 - DNS adapter: reports: observedGeneration=1, Applied=true, Available=True
    11:03 - Hyperfleet API: stores DNS adapter status: 
          - observedGeneration=1, Applied=True, Available=True 
          - created_at=00:02 last_updated_time=11:02
          - data_DNS=whatever.domain.com 
11:02 - Hyperfleet adapter: receives event
  11:02 - Hyperfleet adapter: fetches Cluster (gen=1)
  11:02 - Hyperfleet adapter: checks preconditions: validation_Available=true, DNS_Available=true
  11:02 - Hyperfleet adapter: queries creates ACM job 
  11:02 - Hyperfleet adapter: reports: observedGeneration=1, Applied=true, Available=true🟢
    11:03 - Hyperfleet API: stores Hyperfleet adapter status: 
          - observedGeneration=1, Applied=true, Available=true
          - created_at=00:02 last_updated_time=11:02
    11:03 - Hyperfleet API: marks status.phase=Ready 🟢
          - last_transition_time=11:02

--- Cluster is Ready for Hyperfleet API, no lastUpdate and generation are meaningful

11:11 - Sentinel: polls, sees phase=Ready, lastUpdated=11:02 generation=1
  11:11 - Sentinel: No-op

11:21 - Sentinel: polls, sees phase=Ready, lastUpdated=11:02 generation=1
  11:21 - Sentinel: No-op

--- 30min passed from Ready

41:11 - Sentinel: polls, sees phase=Ready, lastUpdated=11:02 generation=1
  41:11 - Sentinel: publishes reconcile event (gen=1)
41:02 - Validation adapter: receives event
  41:02 - Validation adapter: fetches Cluster (gen=1)
  41:02 - Validation adapter: checks: existing job finished OK
        - ??? what to do here? 🟥 
        how to differentiate this event, from one that deserves re-creating the job?
  41:02 - Validation adapter: reports: observedGeneration=1, Applied=True, Available=True
    41:03 - Hyperfleet API: stores validation adapter status: 
          - observedGeneration=1, Applied=True, Available=True
          - created_at=00:02 last_updated_time=41:02
41:02 - DNS adapter: receives event
  41:02 - DNS adapter: fetches Cluster (gen=1)
  41:02 - DNS adapter: checks preconditions: validation_Available=true
  41:02 - DNS adapter: queries existing DNS CRD 
  41:02 - DNS adapter: reports: observedGeneration=1, Applied=true, Available=True
    41:03 - Hyperfleet API: stores DNS adapter status: 
          - observedGeneration=1, Applied=True, Available=True 
          - created_at=00:02 last_updated_time=41:02
          - data_DNS=whatever.domain.com 
41:02 - Hyperfleet adapter: receives event
  41:02 - Hyperfleet adapter: fetches Cluster (gen=1)
  41:02 - Hyperfleet adapter: checks preconditions: validation_Available=true, DNS_Available=true
  41:02 - Hyperfleet adapter: queries creates ACM job 
  41:02 - Hyperfleet adapter: reports: observedGeneration=1, Applied=true, Available=true🟢
    41:03 - Hyperfleet API: stores Hyperfleet adapter status: 
          - observedGeneration=1, Applied=true, Available=true
          - created_at=00:02 last_updated_time=41:02

--- User modifies cluster
42:00 - User: modifies Cluster (generation=2) 🟢
42:00 - Hyperfleet API: modifies Cluster (gen=2)
42:01 - Sentinel: polls, sees phase=Ready, lastUpdated=01:12 generation=2
  42:01 - Sentinel: publishes reconcile event (gen=2)
42:02 - Validation adapter: receives event
  42:02 - Validation adapter: fetches Cluster (gen=2)
  42:02 - Validation adapter: checks existing job for gen 2
  42:02 - Validation adapter: creates validation job for gen 2 🟢
  42:02 - Validation adapter: reports: observedGeneration=1, Applied=True, Available=True
  42:02 - Validation adapter: ??? should it report from:
          current job: gen=2 Applied=true Available=false
          old job: gen=1 Applied=true Available=true
          both?
    42:03 - Hyperfleet API: stores validation adapter status: 
          - observedGeneration=1 🟧, Applied=True, Available=True
          - created_at=00:02 last_updated_time=42:02
42:02 - DNS adapter: receives event
  42:02 - DNS adapter: fetches Cluster (gen=2)
  42:02 - DNS adapter: checks preconditions: validation_Available=true
  42:02 - DNS adapter: queries existing DNS CRD 
  42:02 - DNS adapter: updates existing DNS CRD 🟢, patch annotation gen=2
  42:02 - DNS adapter: reports: observedGeneration=2 🟢, Applied=true, Available=True
  42:02 - DNS adapter: ??? patch is a synchronous operation
          we report already result with gen=2, 
          this adapter by itself does not retrigger a reconcile
    42:03 - Hyperfleet API: stores DNS adapter status: 
          - observedGeneration=2 🟢, Applied=True, Available=True 
          - created_at=00:02 last_updated_time=42:02
          - data_DNS=whatever.domain.com 
42:02 - Hyperfleet adapter: receives event
  42:02 - Hyperfleet adapter: fetches Cluster (gen=2)
  42:02 - Hyperfleet adapter: checks preconditions: validation_Available=true, DNS_Available=true
  42:02 - Hyperfleet adapter: queries creates ACM job 
  42:02 - Hyperfleet adapter: updates ACM job with annotation gen=2 🟢
  42:02 - Hyperfleet adapter: reports: observedGeneration=2, Applied=true, Available=true🟢
    42:03 - Hyperfleet API: stores Hyperfleet adapter status: 
          - observedGeneration=2 🟢, Applied=true, Available=true
          - created_at=00:02 last_updated_time=42:02

