(define-constant ERR_UNAUTHORIZED (err u5001))
(define-constant ERR_NOT_FOUND (err u5002))
(define-constant ERR_INVALID_TYPE (err u5003))
(define-constant ERR_ORDER_INACTIVE (err u5004))

(define-data-var next-amendment-id uint u1)

(define-map amendments
    uint
    {
        order-id: uint,
        court: principal,
        amendment-type: (string-ascii 20),
        description: (string-ascii 300),
        amended-at: uint,
        previous-value: (string-ascii 100),
        new-value: (string-ascii 100),
    }
)

(define-map order-amendments
    uint
    (list 15 uint)
)

(define-public (amend-order
        (order-id uint)
        (amendment-type (string-ascii 20))
        (description (string-ascii 300))
        (previous-value (string-ascii 100))
        (new-value (string-ascii 100))
    )
    (let (
            (amendment-id (var-get next-amendment-id))
            (order (unwrap! (contract-call? .Clarity-Powered-Court-Orders-Registry get-court-order order-id) ERR_NOT_FOUND))
            (order-data (unwrap! order ERR_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get court order-data)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status order-data) "active") ERR_ORDER_INACTIVE)
        (asserts!
            (or
                (is-eq amendment-type "conditions")
                (is-eq amendment-type "details")
                (is-eq amendment-type "correction")
                (is-eq amendment-type "extension")
            )
            ERR_INVALID_TYPE
        )
        (map-set amendments amendment-id {
            order-id: order-id,
            court: tx-sender,
            amendment-type: amendment-type,
            description: description,
            amended-at: block-height,
            previous-value: previous-value,
            new-value: new-value,
        })
        (let ((existing-amendments (default-to (list) (map-get? order-amendments order-id))))
            (map-set order-amendments order-id
                (unwrap! (as-max-len? (append existing-amendments amendment-id) u15) ERR_INVALID_TYPE)
            )
        )
        (var-set next-amendment-id (+ amendment-id u1))
        (ok amendment-id)
    )
)

(define-read-only (get-amendment (amendment-id uint))
    (ok (map-get? amendments amendment-id))
)

(define-read-only (get-order-amendments (order-id uint))
    (ok (map-get? order-amendments order-id))
)

(define-read-only (get-amendment-count (order-id uint))
    (ok (len (default-to (list) (map-get? order-amendments order-id))))
)
