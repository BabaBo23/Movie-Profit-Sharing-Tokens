(define-fungible-token movie-token)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-movie-not-active (err u104))
(define-constant err-insufficient-balance (err u105))
(define-constant err-oracle-not-set (err u106))
(define-constant err-already-exists (err u107))
(define-constant err-distribution-failed (err u108))

(define-data-var next-movie-id uint u1)
(define-data-var oracle-address (optional principal) none)
(define-data-var platform-fee uint u250)

(define-map movies
  { movie-id: uint }
  {
    title: (string-ascii 100),
    creator: principal,
    total-supply: uint,
    funds-raised: uint,
    target-amount: uint,
    box-office-earnings: uint,
    is-active: bool,
    creation-block: uint,
    distribution-count: uint
  }
)

(define-map investor-balances
  { movie-id: uint, investor: principal }
  { balance: uint }
)

(define-map movie-investors
  { movie-id: uint }
  { investor-count: uint }
)

(define-map royalty-claims
  { movie-id: uint, investor: principal }
  { claimed-amount: uint, last-claim-block: uint }
)

(define-map oracle-reports
  { movie-id: uint, report-id: uint }
  { earnings: uint, reported-at: uint, reporter: principal }
)

(define-public (set-oracle (new-oracle principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set oracle-address (some new-oracle)))
  )
)

(define-public (create-movie (title (string-ascii 100)) (target-amount uint) (token-supply uint))
  (let (
    (movie-id (var-get next-movie-id))
  )
    (asserts! (> target-amount u0) err-invalid-amount)
    (asserts! (> token-supply u0) err-invalid-amount)
    (map-set movies
      { movie-id: movie-id }
      {
        title: title,
        creator: tx-sender,
        total-supply: token-supply,
        funds-raised: u0,
        target-amount: target-amount,
        box-office-earnings: u0,
        is-active: true,
        creation-block: stacks-block-height,
        distribution-count: u0
      }
    )
    (map-set movie-investors
      { movie-id: movie-id }
      { investor-count: u0 }
    )
    (var-set next-movie-id (+ movie-id u1))
    (ok movie-id)
  )
)

(define-public (invest-in-movie (movie-id uint) (amount uint))
  (let (
    (movie (unwrap! (map-get? movies { movie-id: movie-id }) err-not-found))
    (current-balance (default-to u0 (get balance (map-get? investor-balances { movie-id: movie-id, investor: tx-sender }))))
    (investor-info (unwrap! (map-get? movie-investors { movie-id: movie-id }) err-not-found))
    (tokens-to-mint (calculate-tokens-for-investment movie-id amount))
  )
    (asserts! (get is-active movie) err-movie-not-active)
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (<= (+ (get funds-raised movie) amount) (get target-amount movie)) err-invalid-amount)
    
    (try! (stx-transfer? amount tx-sender (get creator movie)))
    (try! (ft-mint? movie-token tokens-to-mint tx-sender))
    
    (map-set investor-balances
      { movie-id: movie-id, investor: tx-sender }
      { balance: (+ current-balance tokens-to-mint) }
    )
    
    (map-set movies
      { movie-id: movie-id }
      (merge movie { funds-raised: (+ (get funds-raised movie) amount) })
    )
    
    (if (is-eq current-balance u0)
      (map-set movie-investors
        { movie-id: movie-id }
        { investor-count: (+ (get investor-count investor-info) u1) }
      )
      true
    )
    
    (ok tokens-to-mint)
  )
)

(define-public (report-box-office (movie-id uint) (earnings uint))
  (let (
    (movie (unwrap! (map-get? movies { movie-id: movie-id }) err-not-found))
    (oracle (unwrap! (var-get oracle-address) err-oracle-not-set))
    (report-id (+ (get distribution-count movie) u1))
  )
    (asserts! (is-eq tx-sender oracle) err-unauthorized)
    (asserts! (get is-active movie) err-movie-not-active)
    (asserts! (> earnings u0) err-invalid-amount)
    
    (map-set oracle-reports
      { movie-id: movie-id, report-id: report-id }
      {
        earnings: earnings,
        reported-at: stacks-block-height,
        reporter: tx-sender
      }
    )
    
    (map-set movies
      { movie-id: movie-id }
      (merge movie { 
        box-office-earnings: (+ (get box-office-earnings movie) earnings),
        distribution-count: report-id
      })
    )
    
    (ok report-id)
  )
)

(define-public (claim-royalties (movie-id uint))
  (let (
    (movie (unwrap! (map-get? movies { movie-id: movie-id }) err-not-found))
    (investor-balance (unwrap! (map-get? investor-balances { movie-id: movie-id, investor: tx-sender }) err-not-found))
    (claim-info (default-to { claimed-amount: u0, last-claim-block: u0 } 
                            (map-get? royalty-claims { movie-id: movie-id, investor: tx-sender })))
    (royalty-amount (calculate-royalty-amount movie-id tx-sender))
    (unclaimed-amount (- royalty-amount (get claimed-amount claim-info)))
  )
    (asserts! (> unclaimed-amount u0) err-invalid-amount)
    (asserts! (> (get box-office-earnings movie) u0) err-invalid-amount)
    
    (let (
      (platform-fee-amount (/ (* unclaimed-amount (var-get platform-fee)) u10000))
      (net-amount (- unclaimed-amount platform-fee-amount))
    )
      (try! (as-contract (stx-transfer? net-amount tx-sender tx-sender)))
      (try! (as-contract (stx-transfer? platform-fee-amount tx-sender contract-owner)))
      
      (map-set royalty-claims
        { movie-id: movie-id, investor: tx-sender }
        { 
          claimed-amount: royalty-amount,
          last-claim-block: stacks-block-height
        }
      )
      
      (ok net-amount)
    )
  )
)

(define-public (withdraw-funds (movie-id uint))
  (let (
    (movie (unwrap! (map-get? movies { movie-id: movie-id }) err-not-found))
  )
    (asserts! (is-eq tx-sender (get creator movie)) err-unauthorized)
    (asserts! (get is-active movie) err-movie-not-active)
    (asserts! (>= (get funds-raised movie) (get target-amount movie)) err-invalid-amount)
    
    (try! (as-contract (stx-transfer? (get funds-raised movie) tx-sender (get creator movie))))
    
    (map-set movies
      { movie-id: movie-id }
      (merge movie { funds-raised: u0 })
    )
    
    (ok (get funds-raised movie))
  )
)

(define-public (deactivate-movie (movie-id uint))
  (let (
    (movie (unwrap! (map-get? movies { movie-id: movie-id }) err-not-found))
  )
    (asserts! (is-eq tx-sender (get creator movie)) err-unauthorized)
    (asserts! (get is-active movie) err-movie-not-active)
    
    (map-set movies
      { movie-id: movie-id }
      (merge movie { is-active: false })
    )
    
    (ok true)
  )
)

(define-public (update-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u1000) err-invalid-amount)
    (ok (var-set platform-fee new-fee))
  )
)

(define-read-only (get-movie-info (movie-id uint))
  (map-get? movies { movie-id: movie-id })
)

(define-read-only (get-investor-balance (movie-id uint) (investor principal))
  (map-get? investor-balances { movie-id: movie-id, investor: investor })
)

(define-read-only (get-royalty-info (movie-id uint) (investor principal))
  (map-get? royalty-claims { movie-id: movie-id, investor: investor })
)

(define-read-only (get-oracle-report (movie-id uint) (report-id uint))
  (map-get? oracle-reports { movie-id: movie-id, report-id: report-id })
)

(define-read-only (get-current-oracle)
  (var-get oracle-address)
)

(define-read-only (get-platform-fee)
  (var-get platform-fee)
)

(define-read-only (get-next-movie-id)
  (var-get next-movie-id)
)

(define-read-only (calculate-tokens-for-investment (movie-id uint) (amount uint))
  (let (
    (movie (unwrap! (map-get? movies { movie-id: movie-id }) u0))
  )
    (if (is-eq (get target-amount movie) u0)
      u0
      (/ (* amount (get total-supply movie)) (get target-amount movie))
    )
  )
)

(define-read-only (calculate-royalty-amount (movie-id uint) (investor principal))
  (let (
    (movie (unwrap! (map-get? movies { movie-id: movie-id }) u0))
    (investor-balance (unwrap! (map-get? investor-balances { movie-id: movie-id, investor: investor }) u0))
  )
    (if (is-eq (get total-supply movie) u0)
      u0
      (/ (* (get box-office-earnings movie) (get balance investor-balance)) (get total-supply movie))
    )
  )
)

(define-read-only (get-investor-count (movie-id uint))
  (map-get? movie-investors { movie-id: movie-id })
)

(define-read-only (get-movie-funding-progress (movie-id uint))
  (let (
    (movie (unwrap! (map-get? movies { movie-id: movie-id }) u0))
  )
    (if (is-eq (get target-amount movie) u0)
      u0
      (/ (* (get funds-raised movie) u10000) (get target-amount movie))
    )
  )
)

(define-read-only (get-claimable-royalties (movie-id uint) (investor principal))
  (let (
    (total-royalty (calculate-royalty-amount movie-id investor))
    (claim-info (default-to { claimed-amount: u0, last-claim-block: u0 } 
                            (map-get? royalty-claims { movie-id: movie-id, investor: investor })))
  )
    (if (> total-royalty (get claimed-amount claim-info))
      (- total-royalty (get claimed-amount claim-info))
      u0
    )
  )
)
