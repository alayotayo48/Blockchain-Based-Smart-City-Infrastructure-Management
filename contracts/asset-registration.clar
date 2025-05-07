;; Asset Registration Contract
;; Records details of urban infrastructure assets

(define-data-var last-asset-id uint u0)

;; Asset types
(define-constant ASSET_TYPE_ROAD u1)
(define-constant ASSET_TYPE_BRIDGE u2)
(define-constant ASSET_TYPE_BUILDING u3)
(define-constant ASSET_TYPE_UTILITY u4)
(define-constant ASSET_TYPE_PARK u5)

;; Asset status
(define-constant STATUS_ACTIVE u1)
(define-constant STATUS_MAINTENANCE u2)
(define-constant STATUS_INACTIVE u3)
(define-constant STATUS_DEPRECATED u4)

;; Define asset map: id -> asset details
(define-map assets
  { id: uint }
  {
    name: (string-utf8 100),
    asset-type: uint,
    location: (string-utf8 100),
    installation-date: uint,
    last-maintenance: uint,
    status: uint,
    owner: principal
  }
)

;; Register a new asset
(define-public (register-asset
    (name (string-utf8 100))
    (asset-type uint)
    (location (string-utf8 100))
    (installation-date uint))
  (let ((new-id (+ (var-get last-asset-id) u1)))
    (asserts! (is-valid-asset-type asset-type) (err u1))
    (var-set last-asset-id new-id)
    (map-set assets
      { id: new-id }
      {
        name: name,
        asset-type: asset-type,
        location: location,
        installation-date: installation-date,
        last-maintenance: u0,
        status: STATUS_ACTIVE,
        owner: tx-sender
      }
    )
    (ok new-id)
  )
)

;; Update asset status
(define-public (update-asset-status (asset-id uint) (new-status uint))
  (let ((asset (unwrap! (map-get? assets { id: asset-id }) (err u404))))
    (asserts! (is-valid-status new-status) (err u2))
    (asserts! (is-asset-owner asset-id) (err u3))
    (map-set assets
      { id: asset-id }
      (merge asset { status: new-status })
    )
    (ok true)
  )
)

;; Update last maintenance date
(define-public (update-maintenance-date (asset-id uint) (maintenance-date uint))
  (let ((asset (unwrap! (map-get? assets { id: asset-id }) (err u404))))
    (asserts! (is-asset-owner asset-id) (err u3))
    (map-set assets
      { id: asset-id }
      (merge asset { last-maintenance: maintenance-date })
    )
    (ok true)
  )
)

;; Get asset details
(define-read-only (get-asset (asset-id uint))
  (map-get? assets { id: asset-id })
)

;; Get total number of assets
(define-read-only (get-asset-count)
  (var-get last-asset-id)
)

;; Helper functions
(define-private (is-valid-asset-type (asset-type uint))
  (or
    (is-eq asset-type ASSET_TYPE_ROAD)
    (is-eq asset-type ASSET_TYPE_BRIDGE)
    (is-eq asset-type ASSET_TYPE_BUILDING)
    (is-eq asset-type ASSET_TYPE_UTILITY)
    (is-eq asset-type ASSET_TYPE_PARK)
  )
)

(define-private (is-valid-status (status uint))
  (or
    (is-eq status STATUS_ACTIVE)
    (is-eq status STATUS_MAINTENANCE)
    (is-eq status STATUS_INACTIVE)
    (is-eq status STATUS_DEPRECATED)
  )
)

(define-private (is-asset-owner (asset-id uint))
  (let ((asset (unwrap! (map-get? assets { id: asset-id }) false)))
    (is-eq (get owner asset) tx-sender)
  )
)
