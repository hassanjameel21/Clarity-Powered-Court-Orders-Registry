(define-constant ERR_UNAUTHORIZED (err u4001))
(define-constant ERR_NOT_FOUND (err u4002))
(define-constant ERR_INVALID_STATUS (err u4003))
(define-constant ERR_APPEAL_EXISTS (err u4004))
(define-constant ERR_DEADLINE_PASSED (err u4005))

(define-data-var next-appeal-id uint u1)

(define-map appeals
    uint
    {
        order-id: uint,
        appellant: principal,
        grounds: (string-ascii 200),
        filed-at: uint,
        status: (string-ascii 20),
        reviewing-court: (optional principal),
        decision: (optional (string-ascii 200)),
        decided-at: (optional uint),
    }
)

(define-map order-appeals
    uint
    (list 5 uint)
)

(define-map appeal-history
    uint
    (list 10 {timestamp: uint, status: (string-ascii 20), actor: principal})
)

(define-public (file-appeal
        (order-id uint)
        (grounds (string-ascii 200))
    )
    (let (
            (appeal-id (var-get next-appeal-id))
            (order (unwrap! (contract-call? .Clarity-Powered-Court-Orders-Registry get-court-order order-id) ERR_NOT_FOUND))
            (order-data (unwrap! order ERR_NOT_FOUND))
        )
        (asserts! (is-eq tx-sender (get subject order-data)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status order-data) "active") ERR_INVALID_STATUS)
        (asserts! (< stacks-block-height (+ (get deadline order-data) u1440)) ERR_DEADLINE_PASSED)
        (map-set appeals appeal-id {
            order-id: order-id,
            appellant: tx-sender,
            grounds: grounds,
            filed-at: stacks-block-height,
            status: "pending",
            reviewing-court: none,
            decision: none,
            decided-at: none,
        })
        (let ((existing-appeals (default-to (list) (map-get? order-appeals order-id))))
            (map-set order-appeals order-id
                (unwrap! (as-max-len? (append existing-appeals appeal-id) u5) ERR_INVALID_STATUS)
            )
        )
        (map-set appeal-history appeal-id
            (list {timestamp: stacks-block-height, status: "pending", actor: tx-sender})
        )
        (var-set next-appeal-id (+ appeal-id u1))
        (ok appeal-id)
    )
)

(define-public (review-appeal
        (appeal-id uint)
        (decision (string-ascii 200))
        (new-status (string-ascii 20))
    )
    (let ((appeal (unwrap! (map-get? appeals appeal-id) ERR_NOT_FOUND)))
        (asserts! (is-court-authorized tx-sender) ERR_UNAUTHORIZED)
        (asserts!
            (or
                (is-eq new-status "approved")
                (is-eq new-status "denied")
            )
            ERR_INVALID_STATUS
        )
        (map-set appeals appeal-id
            (merge appeal {
                status: new-status,
                reviewing-court: (some tx-sender),
                decision: (some decision),
                decided-at: (some stacks-block-height),
            })
        )
        (let ((existing-history (default-to (list) (map-get? appeal-history appeal-id))))
            (map-set appeal-history appeal-id
                (unwrap! (as-max-len? (append existing-history {timestamp: stacks-block-height, status: new-status, actor: tx-sender}) u10) ERR_INVALID_STATUS)
            )
        )
        (ok true)
    )
)

(define-read-only (get-appeal (appeal-id uint))
    (ok (map-get? appeals appeal-id))
)

(define-read-only (get-order-appeals (order-id uint))
    (ok (map-get? order-appeals order-id))
)

(define-read-only (get-appeal-history (appeal-id uint))
    (ok (map-get? appeal-history appeal-id))
)

(define-read-only (is-court-authorized (court principal))
    (is-ok (contract-call? .Clarity-Powered-Court-Orders-Registry is-court-authorized court))
)