(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_NOT_FOUND (err u1002))
(define-constant ERR_ALREADY_EXISTS (err u1003))
(define-constant ERR_INVALID_STATUS (err u1004))
(define-constant ERR_INVALID_PRIORITY (err u1005))

(define-data-var next-order-id uint u1)

(define-map authorized-courts
    principal
    bool
)
(define-map court-orders
    uint
    {
        court: principal,
        case-number: (string-ascii 50),
        ruling-hash: (buff 32),
        status: (string-ascii 20),
        priority: (string-ascii 10),
        issued-at: uint,
        deadline: uint,
        subject: principal,
        compliance-status: (string-ascii 20),
        last-updated: uint,
    }
)

(define-map court-order-subjects
    principal
    (list 50 uint)
)
(define-map compliance-history
    uint
    (list 20
        {
        timestamp: uint,
        status: (string-ascii 20),
        reporter: principal,
    })
)

(define-public (authorize-court (court principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set authorized-courts court true)
        (ok true)
    )
)

(define-public (revoke-court (court principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-delete authorized-courts court)
        (ok true)
    )
)

(define-public (issue-court-order
        (case-number (string-ascii 50))
        (ruling-hash (buff 32))
        (priority (string-ascii 10))
        (deadline uint)
        (subject principal)
    )
    (let (
            (order-id (var-get next-order-id))
            (current-height stacks-block-height)
        )
        (asserts! (default-to false (map-get? authorized-courts tx-sender))
            ERR_UNAUTHORIZED
        )
        (asserts!
            (or
                (is-eq priority "high")
                (is-eq priority "medium")
                (is-eq priority "low")
            )
            ERR_INVALID_PRIORITY
        )
        (asserts! (> deadline current-height) ERR_INVALID_STATUS)
        (map-set court-orders order-id {
            court: tx-sender,
            case-number: case-number,
            ruling-hash: ruling-hash,
            status: "active",
            priority: priority,
            issued-at: current-height,
            deadline: deadline,
            subject: subject,
            compliance-status: "pending",
            last-updated: current-height,
        })
        (let ((existing-orders (default-to (list) (map-get? court-order-subjects subject))))
            (map-set court-order-subjects subject
                (unwrap! (as-max-len? (append existing-orders order-id) u50)
                    ERR_INVALID_STATUS
                ))
        )
        (map-set compliance-history order-id
            (list {
                timestamp: current-height,
                status: "pending",
                reporter: tx-sender,
            })
        )
        (var-set next-order-id (+ order-id u1))
        (ok order-id)
    )
)

(define-public (update-compliance-status
        (order-id uint)
        (new-status (string-ascii 20))
    )
    (let (
            (order (unwrap! (map-get? court-orders order-id) ERR_NOT_FOUND))
            (current-height stacks-block-height)
        )
        (asserts! (default-to false (map-get? authorized-courts tx-sender))
            ERR_UNAUTHORIZED
        )
        (asserts!
            (or
                (is-eq new-status "compliant")
                (is-eq new-status "non-compliant")
                (is-eq new-status "pending")
            )
            ERR_INVALID_STATUS
        )
        (map-set court-orders order-id
            (merge order {
                compliance-status: new-status,
                last-updated: current-height,
            })
        )
        (let ((existing-history (default-to (list) (map-get? compliance-history order-id))))
            (map-set compliance-history order-id
                (unwrap!
                    (as-max-len?
                        (append existing-history {
                            timestamp: current-height,
                            status: new-status,
                            reporter: tx-sender,
                        })
                        u20
                    )
                    ERR_INVALID_STATUS
                ))
        )
        (ok true)
    )
)

(define-public (extend-deadline
        (order-id uint)
        (new-deadline uint)
    )
    (let ((order (unwrap! (map-get? court-orders order-id) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get court order)) ERR_UNAUTHORIZED)
        (asserts! (> new-deadline (get deadline order)) ERR_INVALID_STATUS)
        (map-set court-orders order-id
            (merge order {
                deadline: new-deadline,
                last-updated: stacks-block-height,
            })
        )
        (ok true)
    )
)

(define-public (close-order (order-id uint))
    (let ((order (unwrap! (map-get? court-orders order-id) ERR_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get court order)) ERR_UNAUTHORIZED)
        (map-set court-orders order-id
            (merge order {
                status: "closed",
                last-updated: stacks-block-height,
            })
        )
        (ok true)
    )
)

(define-public (flag-pending-obligation (order-id uint))
    (let (
            (order (unwrap! (map-get? court-orders order-id) ERR_NOT_FOUND))
            (current-height stacks-block-height)
        )
        (asserts! (default-to false (map-get? authorized-courts tx-sender))
            ERR_UNAUTHORIZED
        )
        (asserts!
            (and (> current-height (get deadline order)) (is-eq (get compliance-status order) "pending"))
            ERR_INVALID_STATUS
        )
        (map-set court-orders order-id
            (merge order {
                compliance-status: "overdue",
                last-updated: current-height,
            })
        )
        (let ((existing-history (default-to (list) (map-get? compliance-history order-id))))
            (map-set compliance-history order-id
                (unwrap!
                    (as-max-len?
                        (append existing-history {
                            timestamp: current-height,
                            status: "overdue",
                            reporter: tx-sender,
                        })
                        u20
                    )
                    ERR_INVALID_STATUS
                ))
        )
        (ok true)
    )
)

(define-read-only (get-court-order (order-id uint))
    (ok (map-get? court-orders order-id))
)

(define-read-only (get-orders-by-subject (subject principal))
    (ok (map-get? court-order-subjects subject))
)

(define-read-only (get-compliance-history (order-id uint))
    (ok (map-get? compliance-history order-id))
)

(define-read-only (is-court-authorized (court principal))
    (ok (default-to false (map-get? authorized-courts court)))
)

(define-private (check-high-priority (order-id uint))
    (match (map-get? court-orders order-id)
        some-order (is-eq (get priority some-order) "high")
        false
    )
)

(define-private (check-medium-priority (order-id uint))
    (match (map-get? court-orders order-id)
        some-order (is-eq (get priority some-order) "medium")
        false
    )
)

(define-private (check-low-priority (order-id uint))
    (match (map-get? court-orders order-id)
        some-order (is-eq (get priority some-order) "low")
        false
    )
)

(define-read-only (get-overdue-orders)
    (ok (filter check-overdue
        (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19
            u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34 u35 u36
            u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47 u48 u49 u50)
    ))
)

(define-read-only (get-orders-by-priority (target-priority (string-ascii 10)))
    (if (is-eq target-priority "high")
        (ok (filter check-high-priority
            (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18
                u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34
                u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47 u48 u49 u50)
        ))
        (if (is-eq target-priority "medium")
            (ok (filter check-medium-priority
                (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17
                    u18 u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32
                    u33 u34 u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47
                    u48 u49 u50)
            ))
            (ok (filter check-low-priority
                (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17
                    u18 u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32
                    u33 u34 u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47
                    u48 u49 u50)
            ))
        )
    )
)

(define-private (check-active-status (order-id uint))
    (match (map-get? court-orders order-id)
        some-order (is-eq (get status some-order) "active")
        false
    )
)

(define-private (check-closed-status (order-id uint))
    (match (map-get? court-orders order-id)
        some-order (is-eq (get status some-order) "closed")
        false
    )
)

(define-read-only (get-orders-by-status (target-status (string-ascii 20)))
    (if (is-eq target-status "active")
        (ok (filter check-active-status
            (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18
                u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34
                u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47 u48 u49 u50)
        ))
        (ok (filter check-closed-status
            (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18
                u19 u20 u21 u22 u23 u24 u25 u26 u27 u28 u29 u30 u31 u32 u33 u34
                u35 u36 u37 u38 u39 u40 u41 u42 u43 u44 u45 u46 u47 u48 u49 u50)
        ))
    )
)

(define-read-only (get-next-order-id)
    (ok (var-get next-order-id))
)

(define-private (check-overdue (order-id uint))
    (match (map-get? court-orders order-id)
        some-order (and
            (> stacks-block-height (get deadline some-order))
            (is-eq (get compliance-status some-order) "pending")
        )
        false
    )
)

(map-set authorized-courts CONTRACT_OWNER true)
