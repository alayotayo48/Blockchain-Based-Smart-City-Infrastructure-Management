;; Performance Analytics Contract
;; Tracks efficiency and service levels of city infrastructure

(define-data-var last-metric-id uint u0)

;; Metric types
(define-constant METRIC_TYPE_UPTIME u1)
(define-constant METRIC_TYPE_RESPONSE_TIME u2)
(define-constant METRIC_TYPE_UTILIZATION u3)
(define-constant METRIC_TYPE_EFFICIENCY u4)
(define-constant METRIC_TYPE_SATISFACTION u5)
(define-constant METRIC_TYPE_COST u6)

;; Define metrics map: id -> metric details
(define-map metrics
  { id: uint }
  {
    name: (string-utf8 100),
    metric-type: uint,
    asset-id: uint,
    description: (string-utf8 200),
    target-value: int,
    created-by: principal
  }
)

;; Define metric readings map: id -> reading details
(define-map metric-readings
  { id: uint }
  {
    metric-id: uint,
    timestamp: uint,
    value: int,
    notes: (optional (string-utf8 200)),
    recorded-by: principal
  }
)

;; Define aggregated metrics map: metric-id, period -> aggregated data
(define-map aggregated-metrics
  { metric-id: uint, period: uint }
  {
    min-value: int,
    max-value: int,
    avg-value: int,
    reading-count: uint,
    last-updated: uint
  }
)

;; Register a new performance metric
(define-public (register-metric
    (name (string-utf8 100))
    (metric-type uint)
    (asset-id uint)
    (description (string-utf8 200))
    (target-value int))
  (let ((new-id (+ (var-get last-metric-id) u1)))
    (asserts! (is-valid-metric-type metric-type) (err u1))
    (var-set last-metric-id new-id)
    (map-set metrics
      { id: new-id }
      {
        name: name,
        metric-type: metric-type,
        asset-id: asset-id,
        description: description,
        target-value: target-value,
        created-by: tx-sender
      }
    )
    (ok new-id)
  )
)

;; Record a new metric reading
(define-public (record-metric-reading
    (metric-id uint)
    (value int)
    (notes (optional (string-utf8 200))))
  (let (
    (metric (unwrap! (map-get? metrics { id: metric-id }) (err u404)))
    (new-id (+ (var-get last-metric-id) u1))
    (current-period (/ block-height u100)) ;; Group by every 100 blocks
  )
    (var-set last-metric-id new-id)

    ;; Record the individual reading
    (map-set metric-readings
      { id: new-id }
      {
        metric-id: metric-id,
        timestamp: block-height,
        value: value,
        notes: notes,
        recorded-by: tx-sender
      }
    )

    ;; Update the aggregated metrics
    (update-aggregated-metrics metric-id current-period value)

    (ok new-id)
  )
)

;; Get metric details
(define-read-only (get-metric (metric-id uint))
  (map-get? metrics { id: metric-id })
)

;; Get metric reading
(define-read-only (get-metric-reading (reading-id uint))
  (map-get? metric-readings { id: reading-id })
)

;; Get aggregated metrics for a period
(define-read-only (get-aggregated-metrics (metric-id uint) (period uint))
  (map-get? aggregated-metrics { metric-id: metric-id, period: period })
)

;; Check if a metric is meeting its target
(define-read-only (is-meeting-target (metric-id uint) (period uint))
  (let (
    (metric (unwrap! (map-get? metrics { id: metric-id }) false))
    (aggregated (map-get? aggregated-metrics { metric-id: metric-id, period: period }))
  )
    (if (is-some aggregated)
      (let ((agg (unwrap! aggregated false)))
        (>= (get avg-value agg) (get target-value metric))
      )
      false
    )
  )
)

;; Helper functions
(define-private (is-valid-metric-type (metric-type uint))
  (or
    (is-eq metric-type METRIC_TYPE_UPTIME)
    (is-eq metric-type METRIC_TYPE_RESPONSE_TIME)
    (is-eq metric-type METRIC_TYPE_UTILIZATION)
    (is-eq metric-type METRIC_TYPE_EFFICIENCY)
    (is-eq metric-type METRIC_TYPE_SATISFACTION)
    (is-eq metric-type METRIC_TYPE_COST)
  )
)

(define-private (update-aggregated-metrics (metric-id uint) (period uint) (new-value int))
  (let (
    (existing-data (map-get? aggregated-metrics { metric-id: metric-id, period: period }))
  )
    (if (is-some existing-data)
      (let (
        (data (unwrap! existing-data { min-value: new-value, max-value: new-value, avg-value: new-value, reading-count: u0, last-updated: block-height }))
        (count (get reading-count data))
        (current-avg (get avg-value data))
        (current-min (get min-value data))
        (current-max (get max-value data))
        (new-count (+ count u1))
        (new-avg (/ (+ (* current-avg (to-int count)) new-value) (to-int new-count)))
      )
        (map-set aggregated-metrics
          { metric-id: metric-id, period: period }
          {
            min-value: (if (< new-value current-min) new-value current-min),
            max-value: (if (> new-value current-max) new-value current-max),
            avg-value: new-avg,
            reading-count: new-count,
            last-updated: block-height
          }
        )
      )
      ;; First reading for this period
      (map-set aggregated-metrics
        { metric-id: metric-id, period: period }
        {
          min-value: new-value,
          max-value: new-value,
          avg-value: new-value,
          reading-count: u1,
          last-updated: block-height
        }
      )
    )
    (ok true)
  )
)
