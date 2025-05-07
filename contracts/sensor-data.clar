;; Sensor Data Contract
;; Tracks conditions of city systems through sensor data

(define-data-var last-reading-id uint u0)

;; Sensor types
(define-constant SENSOR_TYPE_TEMPERATURE u1)
(define-constant SENSOR_TYPE_HUMIDITY u2)
(define-constant SENSOR_TYPE_TRAFFIC u3)
(define-constant SENSOR_TYPE_AIR_QUALITY u4)
(define-constant SENSOR_TYPE_STRUCTURAL u5)
(define-constant SENSOR_TYPE_WATER_LEVEL u6)

;; Define sensor map: id -> sensor details
(define-map sensors
  { id: uint }
  {
    name: (string-utf8 100),
    sensor-type: uint,
    asset-id: uint,
    location: (string-utf8 100),
    owner: principal
  }
)

;; Define sensor readings map: reading-id -> reading details
(define-map sensor-readings
  { id: uint }
  {
    sensor-id: uint,
    timestamp: uint,
    value: int,
    notes: (optional (string-utf8 200))
  }
)

;; Register a new sensor
(define-public (register-sensor
    (name (string-utf8 100))
    (sensor-type uint)
    (asset-id uint)
    (location (string-utf8 100)))
  (let ((new-id (+ (var-get last-reading-id) u1)))
    (asserts! (is-valid-sensor-type sensor-type) (err u1))
    (var-set last-reading-id new-id)
    (map-set sensors
      { id: new-id }
      {
        name: name,
        sensor-type: sensor-type,
        asset-id: asset-id,
        location: location,
        owner: tx-sender
      }
    )
    (ok new-id)
  )
)

;; Record a new sensor reading
(define-public (record-sensor-reading
    (sensor-id uint)
    (value int)
    (notes (optional (string-utf8 200))))
  (let (
    (sensor (unwrap! (map-get? sensors { id: sensor-id }) (err u404)))
    (new-id (+ (var-get last-reading-id) u1))
  )
    (asserts! (is-sensor-owner sensor-id) (err u3))
    (var-set last-reading-id new-id)
    (map-set sensor-readings
      { id: new-id }
      {
        sensor-id: sensor-id,
        timestamp: block-height,
        value: value,
        notes: notes
      }
    )
    (ok new-id)
  )
)

;; Get sensor details
(define-read-only (get-sensor (sensor-id uint))
  (map-get? sensors { id: sensor-id })
)

;; Get sensor reading
(define-read-only (get-sensor-reading (reading-id uint))
  (map-get? sensor-readings { id: reading-id })
)

;; Helper functions
(define-private (is-valid-sensor-type (sensor-type uint))
  (or
    (is-eq sensor-type SENSOR_TYPE_TEMPERATURE)
    (is-eq sensor-type SENSOR_TYPE_HUMIDITY)
    (is-eq sensor-type SENSOR_TYPE_TRAFFIC)
    (is-eq sensor-type SENSOR_TYPE_AIR_QUALITY)
    (is-eq sensor-type SENSOR_TYPE_STRUCTURAL)
    (is-eq sensor-type SENSOR_TYPE_WATER_LEVEL)
  )
)

(define-private (is-sensor-owner (sensor-id uint))
  (let ((sensor (unwrap! (map-get? sensors { id: sensor-id }) false)))
    (is-eq (get owner sensor) tx-sender)
  )
)
