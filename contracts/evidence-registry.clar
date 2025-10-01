(define-constant ERR_UNAUTHORIZED (err u3001))
(define-constant ERR_NOT_FOUND (err u3002))
(define-constant ERR_INVALID_TYPE (err u3003))
(define-constant ERR_ORDER_CLOSED (err u3004))

(define-data-var next-evidence-id uint u1)

(define-map evidence-registry
    uint
    {
        order-id: uint,
        court: principal,
        evidence-hash: (buff 32),
        evidence-type: (string-ascii 20),
        description: (string-ascii 100),
        submitted-at: uint,
        verified: bool,
        chain-of-custody: (list 5 principal),
    }
)

(define-map order-evidence
    uint
    (list 10 uint)
)

(define-public (submit-evidence
        (order-id uint)
        (evidence-hash (buff 32))
        (evidence-type (string-ascii 20))
        (description (string-ascii 100))
    )
    (let (
            (evidence-id (var-get next-evidence-id))
            (order (unwrap! (contract-call? .Clarity-Powered-Court-Orders-Registry get-court-order order-id) ERR_NOT_FOUND))
        )
        (asserts! (is-some order) ERR_NOT_FOUND)
        (asserts! (is-court-authorized tx-sender) ERR_UNAUTHORIZED)
        (asserts!
            (or
                (is-eq evidence-type "document")
                (is-eq evidence-type "physical")
                (is-eq evidence-type "digital")
                (is-eq evidence-type "multimedia")
            )
            ERR_INVALID_TYPE
        )
        (let ((order-data (unwrap-panic order)))
            (asserts! (is-eq (get status order-data) "active") ERR_ORDER_CLOSED)
            (map-set evidence-registry evidence-id {
                order-id: order-id,
                court: tx-sender,
                evidence-hash: evidence-hash,
                evidence-type: evidence-type,
                description: description,
                submitted-at: stacks-block-height,
                verified: false,
                chain-of-custody: (list tx-sender),
            })
            (let ((existing-evidence (default-to (list) (map-get? order-evidence order-id))))
                (map-set order-evidence order-id
                    (unwrap-panic (as-max-len? (append existing-evidence evidence-id) u10))
                )
            )
            (var-set next-evidence-id (+ evidence-id u1))
            (ok evidence-id)
        )
    )
)

(define-public (verify-evidence (evidence-id uint))
    (let ((evidence (unwrap! (map-get? evidence-registry evidence-id) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get court evidence)) ERR_UNAUTHORIZED)
        (map-set evidence-registry evidence-id
            (merge evidence { verified: true })
        )
        (ok true)
    )
)

(define-read-only (get-evidence (evidence-id uint))
    (ok (map-get? evidence-registry evidence-id))
)

(define-read-only (get-order-evidence (order-id uint))
    (ok (map-get? order-evidence order-id))
)

(define-read-only (is-court-authorized (court principal))
    (is-ok (contract-call? .Clarity-Powered-Court-Orders-Registry is-court-authorized court))
)
