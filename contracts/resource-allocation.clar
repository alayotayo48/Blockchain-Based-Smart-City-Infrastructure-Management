;; Resource Allocation Contract
;; Optimizes deployment of city services and resources

(define-data-var last-resource-id uint u0)
(define-data-var last-allocation-id uint u0)

;; Resource types
(define-constant RESOURCE_TYPE_VEHICLE u1)
(define-constant RESOURCE_TYPE_EQUIPMENT u2)
(define-constant RESOURCE_TYPE_PERSONNEL u3)
(define-constant RESOURCE_TYPE_MATERIAL u4)
(define-constant RESOURCE_TYPE_BUDGET u5)

;; Allocation status
(define-constant STATUS_PENDING u1)
(define-constant STATUS_ACTIVE u2)
(define-constant STATUS_COMPLETED u3)
(define-constant STATUS_CANCELLED u4)

;; Define resources map: id -> resource details
(define-map resources
  { id: uint }
  {
    name: (string-utf8 100),
    resource-type: uint,
    capacity: uint,
    available: uint,
    department: (string-utf8 100),
    owner: principal
  }
)

;; Define allocations map: id -> allocation details
(define-map allocations
  { id: uint }
  {
    resource-id: uint,
    task-id: uint,
    amount: uint,
    start-time: uint,
    end-time: (optional uint),
    status: uint,
    allocated-by: principal
  }
)

;; Register a new resource
(define-public (register-resource
    (name (string-utf8 100))
    (resource-type uint)
    (capacity uint)
    (department (string-utf8 100)))
  (let ((new-id (+ (var-get last-resource-id) u1)))
    (asserts! (is-valid-resource-type resource-type) (err u1))
    (var-set last-resource-id new-id)
    (map-set resources
      { id: new-id }
      {
        name: name,
        resource-type: resource-type,
        capacity: capacity,
        available: capacity,
        department: department,
        owner: tx-sender
      }
    )
    (ok new-id)
  )
)

;; Allocate a resource to a task
(define-public (allocate-resource
    (resource-id uint)
    (task-id uint)
    (amount uint)
    (start-time uint))
  (let (
    (resource (unwrap! (map-get? resources { id: resource-id }) (err u404)))
    (new-id (+ (var-get last-allocation-id) u1))
    (available (get available resource))
  )
    (asserts! (>= available amount) (err u5))
    (asserts! (is-resource-owner resource-id) (err u3))

    ;; Update resource availability
    (map-set resources
      { id: resource-id }
      (merge resource { available: (- available amount) })
    )

    ;; Create allocation record
    (var-set last-allocation-id new-id)
    (map-set allocations
      { id: new-id }
      {
        resource-id: resource-id,
        task-id: task-id,
        amount: amount,
        start-time: start-time,
        end-time: none,
        status: STATUS_ACTIVE,
        allocated-by: tx-sender
      }
    )
    (ok new-id)
  )
)

;; Complete a resource allocation
(define-public (complete-allocation (allocation-id uint))
  (let (
    (allocation (unwrap! (map-get? allocations { id: allocation-id }) (err u404)))
    (resource-id (get resource-id allocation))
    (amount (get amount allocation))
    (resource (unwrap! (map-get? resources { id: resource-id }) (err u405)))
    (current-available (get available resource))
  )
    (asserts! (is-eq (get status allocation) STATUS_ACTIVE) (err u6))
    (asserts! (is-allocation-owner allocation-id) (err u3))

    ;; Return resource to available pool
    (map-set resources
      { id: resource-id }
      (merge resource { available: (+ current-available amount) })
    )

    ;; Update allocation status
    (map-set allocations
      { id: allocation-id }
      (merge allocation {
        status: STATUS_COMPLETED,
        end-time: (some block-height)
      })
    )
    (ok true)
  )
)

;; Get resource details
(define-read-only (get-resource (resource-id uint))
  (map-get? resources { id: resource-id })
)

;; Get allocation details
(define-read-only (get-allocation (allocation-id uint))
  (map-get? allocations { id: allocation-id })
)

;; Helper functions
(define-private (is-valid-resource-type (resource-type uint))
  (or
    (is-eq resource-type RESOURCE_TYPE_VEHICLE)
    (is-eq resource-type RESOURCE_TYPE_EQUIPMENT)
    (is-eq resource-type RESOURCE_TYPE_PERSONNEL)
    (is-eq resource-type RESOURCE_TYPE_MATERIAL)
    (is-eq resource-type RESOURCE_TYPE_BUDGET)
  )
)

(define-private (is-resource-owner (resource-id uint))
  (let ((resource (unwrap! (map-get? resources { id: resource-id }) false)))
    (is-eq (get owner resource) tx-sender)
  )
)

(define-private (is-allocation-owner (allocation-id uint))
  (let ((allocation (unwrap! (map-get? allocations { id: allocation-id }) false)))
    (is-eq (get allocated-by allocation) tx-sender)
  )
)
