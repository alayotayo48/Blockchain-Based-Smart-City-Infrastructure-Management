;; Maintenance Scheduling Contract
;; Manages service requirements for city infrastructure

(define-data-var last-task-id uint u0)

;; Task priority levels
(define-constant PRIORITY_LOW u1)
(define-constant PRIORITY_MEDIUM u2)
(define-constant PRIORITY_HIGH u3)
(define-constant PRIORITY_EMERGENCY u4)

;; Task status
(define-constant STATUS_SCHEDULED u1)
(define-constant STATUS_IN_PROGRESS u2)
(define-constant STATUS_COMPLETED u3)
(define-constant STATUS_CANCELLED u4)

;; Define maintenance tasks map: id -> task details
(define-map maintenance-tasks
  { id: uint }
  {
    asset-id: uint,
    description: (string-utf8 200),
    priority: uint,
    scheduled-date: uint,
    completion-date: (optional uint),
    status: uint,
    assigned-to: (optional principal),
    created-by: principal
  }
)

;; Create a new maintenance task
(define-public (create-task
    (asset-id uint)
    (description (string-utf8 200))
    (priority uint)
    (scheduled-date uint))
  (let ((new-id (+ (var-get last-task-id) u1)))
    (asserts! (is-valid-priority priority) (err u1))
    (var-set last-task-id new-id)
    (map-set maintenance-tasks
      { id: new-id }
      {
        asset-id: asset-id,
        description: description,
        priority: priority,
        scheduled-date: scheduled-date,
        completion-date: none,
        status: STATUS_SCHEDULED,
        assigned-to: none,
        created-by: tx-sender
      }
    )
    (ok new-id)
  )
)

;; Assign a task to a maintenance worker
(define-public (assign-task (task-id uint) (worker principal))
  (let ((task (unwrap! (map-get? maintenance-tasks { id: task-id }) (err u404))))
    (asserts! (is-task-creator task-id) (err u3))
    (asserts! (is-eq (get status task) STATUS_SCHEDULED) (err u4))
    (map-set maintenance-tasks
      { id: task-id }
      (merge task { assigned-to: (some worker) })
    )
    (ok true)
  )
)

;; Update task status
(define-public (update-task-status (task-id uint) (new-status uint))
  (let ((task (unwrap! (map-get? maintenance-tasks { id: task-id }) (err u404))))
    (asserts! (is-valid-status new-status) (err u2))
    (asserts! (or (is-task-creator task-id) (is-task-assignee task-id)) (err u3))

    ;; If completing the task, set completion date
    (if (is-eq new-status STATUS_COMPLETED)
      (map-set maintenance-tasks
        { id: task-id }
        (merge task {
          status: new-status,
          completion-date: (some block-height)
        })
      )
      (map-set maintenance-tasks
        { id: task-id }
        (merge task { status: new-status })
      )
    )
    (ok true)
  )
)

;; Get task details
(define-read-only (get-task (task-id uint))
  (map-get? maintenance-tasks { id: task-id })
)

;; Helper functions
(define-private (is-valid-priority (priority uint))
  (or
    (is-eq priority PRIORITY_LOW)
    (is-eq priority PRIORITY_MEDIUM)
    (is-eq priority PRIORITY_HIGH)
    (is-eq priority PRIORITY_EMERGENCY)
  )
)

(define-private (is-valid-status (status uint))
  (or
    (is-eq status STATUS_SCHEDULED)
    (is-eq status STATUS_IN_PROGRESS)
    (is-eq status STATUS_COMPLETED)
    (is-eq status STATUS_CANCELLED)
  )
)

(define-private (is-task-creator (task-id uint))
  (let ((task (unwrap! (map-get? maintenance-tasks { id: task-id }) false)))
    (is-eq (get created-by task) tx-sender)
  )
)

(define-private (is-task-assignee (task-id uint))
  (let (
    (task (unwrap! (map-get? maintenance-tasks { id: task-id }) false))
    (assignee (get assigned-to task))
  )
    (and
      (is-some assignee)
      (is-eq (unwrap! assignee false) tx-sender)
    )
  )
)
