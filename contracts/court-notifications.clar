(define-constant ERR_UNAUTHORIZED (err u2001))
(define-constant ERR_NOT_FOUND (err u2002))
(define-constant ERR_INVALID_TYPE (err u2003))
(define-constant ERR_ALREADY_SUBSCRIBED (err u2004))

(define-data-var next-notification-id uint u1)

(define-map notifications
    uint
    {
        court: principal,
        alert-type: (string-ascii 20),
        message: (string-ascii 200),
        target-subject: (optional principal),
        broadcast: bool,
        created-at: uint,
        expires-at: uint,
        priority: (string-ascii 10),
    }
)

(define-map court-subscriptions
    {court: principal, subscriber: principal}
    {
        alert-types: (list 5 (string-ascii 20)),
        subscribed-at: uint,
        active: bool,
    }
)

(define-map subject-notifications
    principal
    (list 20 uint)
)

(define-map notification-subscribers
    uint
    (list 10 principal)
)

(define-public (create-notification
        (alert-type (string-ascii 20))
        (message (string-ascii 200))
        (target-subject (optional principal))
        (broadcast bool)
        (expires-at uint)
        (priority (string-ascii 10))
    )
    (let ((notification-id (var-get next-notification-id)))
        (asserts! (is-court-authorized tx-sender) ERR_UNAUTHORIZED)
        (asserts!
            (or
                (is-eq alert-type "deadline")
                (is-eq alert-type "status-change")
                (is-eq alert-type "compliance")
                (is-eq alert-type "general")
            )
            ERR_INVALID_TYPE
        )
        (asserts!
            (or
                (is-eq priority "high")
                (is-eq priority "medium")
                (is-eq priority "low")
            )
            ERR_INVALID_TYPE
        )
        (map-set notifications notification-id {
            court: tx-sender,
            alert-type: alert-type,
            message: message,
            target-subject: target-subject,
            broadcast: broadcast,
            created-at: stacks-block-height,
            expires-at: expires-at,
            priority: priority,
        })
        (match target-subject some-subject
            (begin (update-subject-notifications some-subject notification-id) true)
            true
        )
        (var-set next-notification-id (+ notification-id u1))
        (ok notification-id)
    )
)

(define-public (subscribe-to-court
        (court principal)
        (alert-types (list 5 (string-ascii 20)))
    )
    (let ((subscription-key {court: court, subscriber: tx-sender}))
        (asserts! (is-court-authorized court) ERR_UNAUTHORIZED)
        (asserts! (is-none (map-get? court-subscriptions subscription-key)) ERR_ALREADY_SUBSCRIBED)
        (map-set court-subscriptions subscription-key {
            alert-types: alert-types,
            subscribed-at: stacks-block-height,
            active: true,
        })
        (ok true)
    )
)

(define-public (unsubscribe-from-court (court principal))
    (let ((subscription-key {court: court, subscriber: tx-sender}))
        (map-delete court-subscriptions subscription-key)
        (ok true)
    )
)

(define-private (update-subject-notifications (subject principal) (notification-id uint))
    (let ((existing-notifications (default-to (list) (map-get? subject-notifications subject))))
        (map-set subject-notifications subject
            (unwrap-panic (as-max-len? (append existing-notifications notification-id) u20))
        )
    )
)

(define-read-only (get-notification (notification-id uint))
    (ok (map-get? notifications notification-id))
)

(define-read-only (get-notifications-for-subject (subject principal))
    (ok (map-get? subject-notifications subject))
)

(define-read-only (get-subscription (court principal) (subscriber principal))
    (ok (map-get? court-subscriptions {court: court, subscriber: subscriber}))
)

(define-read-only (is-court-authorized (court principal))
    (is-ok (contract-call? .Clarity-Powered-Court-Orders-Registry is-court-authorized court))
)