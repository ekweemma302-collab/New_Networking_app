(impl-trait 'SP000000000000000000002Q6VF78.pox-4.trait)

;; Networking Liquidity Pool
;; Devices can register, create networking sessions, and deposit STX liquidity
;; into a shared pool that rewards reliable connectivity.

(define-data-var admin principal tx-sender)
(define-data-var next-device-id uint u1)
(define-data-var next-session-id uint u1)

(define-map devices
  ((id uint))
  ((owner principal) (metadata (buff 64))))

(define-map sessions
  ((id uint))
  ((host-device-id uint)
   (guest-device-id (optional uint))
   (liquidity-required uint)
   (liquidity-deposited uint)
   (active bool)))

(define-fungible-token networking-lp)

(define-constant ERR-NOT-ADMIN (err u100))
(define-constant ERR-UNKNOWN-DEVICE (err u101))
(define-constant ERR-NOT-OWNER (err u102))
(define-constant ERR-SESSION-NOT-ACTIVE (err u103))
(define-constant ERR-INSUFFICIENT-LIQUIDITY (err u104))
(define-constant ERR-ALREADY-GUEST (err u105))

(define-read-only (get-admin)
  (ok (var-get admin)))

(define-public (set-admin (new-admin principal))
  (begin
    (if (is-eq tx-sender (var-get admin))
        (begin (var-set admin new-admin) (ok true))
        ERR-NOT-ADMIN)))

(define-public (register-device (metadata (buff 64)))
  (let
      ((id (var-get next-device-id)))
    (begin
      (map-set devices ((id id)) ((owner tx-sender) (metadata metadata)))
      (var-set next-device-id (+ id u1))
      (ok id))))

(define-read-only (get-device (id uint))
  (match (map-get? devices ((id id)))
    device (ok device)
    ERR-UNKNOWN-DEVICE))

(define-public (create-session (device-id uint) (liquidity-required uint))
  (match (map-get? devices ((id device-id)))
    device
    (if (is-eq (get owner device) tx-sender)
        (let ((sid (var-get next-session-id)))
          (begin
            (map-set sessions
              ((id sid))
              ((host-device-id device-id)
               (guest-device-id none)
               (liquidity-required liquidity-required)
               (liquidity-deposited u0)
               (active true)))
            (var-set next-session-id (+ sid u1))
            (ok sid)))
        ERR-NOT-OWNER)
    ERR-UNKNOWN-DEVICE))

(define-read-only (get-session (sid uint))
  (match (map-get? sessions ((id sid)))
    session (ok session)
    (err u106)))

(define-public (join-and-deposit
    (sid uint)
    (guest-device-id uint)
    (amount uint)
  )
  (match (map-get? devices ((id guest-device-id)))
    guest-device
    (match (map-get? sessions ((id sid)))
      session
      (if (and (get active session) (is-none (get guest-device-id session)))
          (if (>= amount (get liquidity-required session))
              (let ((transfer-result (stx-transfer? amount tx-sender (as-contract tx-sender))))
                (match transfer-result
                  transfer-ok
                  (begin
                    (map-set sessions
                      ((id sid))
                      ((host-device-id (get host-device-id session))
                       (guest-device-id (some guest-device-id))
                       (liquidity-required (get liquidity-required session))
                       (liquidity-deposited amount)
                       (active true)))
                    (ft-mint? networking-lp amount tx-sender)
                    (ok true))
                  transfer-err transfer-err))
              ERR-INSUFFICIENT-LIQUIDITY)
          ERR-SESSION-NOT-ACTIVE)
      (err u106))
    ERR-UNKNOWN-DEVICE))

(define-public (close-session (sid uint) (recipient principal))
  (match (map-get? sessions ((id sid)))
    session
    (let
        ((host-id (get host-device-id session)))
      (match (map-get? devices ((id host-id)))
        host-device
        (if (is-eq (get owner host-device) tx-sender)
            (let ((amount (get liquidity-deposited session)))
              (begin
                (map-set sessions
                  ((id sid))
                  ((host-device-id host-id)
                   (guest-device-id (get guest-device-id session))
                   (liquidity-required (get liquidity-required session))
                   (liquidity-deposited u0)
                   (active false)))
                (if (> amount u0)
                    (stx-transfer? amount (as-contract tx-sender) recipient)
                    (ok true))))
            ERR-NOT-OWNER)
        ERR-UNKNOWN-DEVICE))
    (err u106)))
