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
(define-constant err-voting-period-ended (err u109))
(define-constant err-voting-period-active (err u110))
(define-constant err-already-voted (err u111))
(define-constant err-insufficient-voting-power (err u112))
(define-constant err-tier-not-found (err u113))
(define-constant err-invalid-tier-config (err u114))

(define-data-var next-movie-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var oracle-address (optional principal) none)
(define-data-var platform-fee uint u250)
(define-data-var early-bird-duration uint u144)

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

(define-map voting-proposals
  { proposal-id: uint }
  {
    movie-id: uint,
    proposer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    proposal-type: uint,
    start-block: uint,
    end-block: uint,
    votes-for: uint,
    votes-against: uint,
    is-executed: bool,
    is-active: bool
  }
)

(define-map proposal-votes
  { proposal-id: uint, voter: principal }
  { vote: bool, voting-power: uint, voted-at: uint }
)

(define-map investment-tiers
  { movie-id: uint, tier: uint }
  {
    min-amount: uint,
    max-amount: uint,
    bonus-percentage: uint,
    tier-name: (string-ascii 50)
  }
)

(define-map investor-tier-status
  { movie-id: uint, investor: principal }
  {
    tier-level: uint,
    early-bird-bonus: uint,
    total-bonus-tokens: uint,
    investment-block: uint
  }
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
    (unwrap-panic (setup-default-tiers movie-id target-amount))
    (var-set next-movie-id (+ movie-id u1))
    (ok movie-id)
  )
)

(define-public (invest-in-movie (movie-id uint) (amount uint))
  (let (
    (movie (unwrap! (map-get? movies { movie-id: movie-id }) err-not-found))
    (current-balance (default-to u0 (get balance (map-get? investor-balances { movie-id: movie-id, investor: tx-sender }))))
    (investor-info (unwrap! (map-get? movie-investors { movie-id: movie-id }) err-not-found))
    (base-tokens (calculate-tokens-for-investment movie-id amount))
    (tier-info (calculate-investment-tier movie-id amount))
    (tier-bonus (calculate-tier-bonus movie-id amount (get tier tier-info)))
    (early-bird-bonus (calculate-early-bird-bonus movie-id amount))
    (total-bonus-tokens (+ tier-bonus early-bird-bonus))
    (tokens-to-mint (+ base-tokens total-bonus-tokens))
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
    
    (map-set investor-tier-status
      { movie-id: movie-id, investor: tx-sender }
      {
        tier-level: (get tier tier-info),
        early-bird-bonus: early-bird-bonus,
        total-bonus-tokens: (+ (get total-bonus-tokens (default-to {tier-level: u1, early-bird-bonus: u0, total-bonus-tokens: u0, investment-block: u0} (map-get? investor-tier-status { movie-id: movie-id, investor: tx-sender }))) total-bonus-tokens),
        investment-block: stacks-block-height
      }
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

(define-public (configure-investment-tier (movie-id uint) (tier uint) (min-amount uint) (max-amount uint) (bonus-percentage uint) (tier-name (string-ascii 50)))
  (let (
    (movie (unwrap! (map-get? movies { movie-id: movie-id }) err-not-found))
  )
    (asserts! (is-eq tx-sender (get creator movie)) err-unauthorized)
    (asserts! (get is-active movie) err-movie-not-active)
    (asserts! (> min-amount u0) err-invalid-amount)
    (asserts! (> max-amount min-amount) err-invalid-amount)
    (asserts! (<= bonus-percentage u5000) err-invalid-tier-config)
    
    (map-set investment-tiers
      { movie-id: movie-id, tier: tier }
      {
        min-amount: min-amount,
        max-amount: max-amount,
        bonus-percentage: bonus-percentage,
        tier-name: tier-name
      }
    )
    (ok true)
  )
)

(define-public (set-early-bird-duration (duration uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= duration u1440) err-invalid-amount)
    (ok (var-set early-bird-duration duration))
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

(define-public (create-proposal (movie-id uint) (title (string-ascii 100)) (description (string-ascii 500)) (proposal-type uint) (voting-duration uint))
  (let (
    (proposal-id (var-get next-proposal-id))
    (movie (unwrap! (map-get? movies { movie-id: movie-id }) err-not-found))
    (investor-balance (unwrap! (map-get? investor-balances { movie-id: movie-id, investor: tx-sender }) err-not-found))
  )
    (asserts! (get is-active movie) err-movie-not-active)
    (asserts! (> (get balance investor-balance) u0) err-insufficient-voting-power)
    (asserts! (> voting-duration u0) err-invalid-amount)
    (asserts! (<= voting-duration u1440) err-invalid-amount)
    
    (map-set voting-proposals
      { proposal-id: proposal-id }
      {
        movie-id: movie-id,
        proposer: tx-sender,
        title: title,
        description: description,
        proposal-type: proposal-type,
        start-block: stacks-block-height,
        end-block: (+ stacks-block-height voting-duration),
        votes-for: u0,
        votes-against: u0,
        is-executed: false,
        is-active: true
      }
    )
    
    (var-set next-proposal-id (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote bool))
  (let (
    (proposal (unwrap! (map-get? voting-proposals { proposal-id: proposal-id }) err-not-found))
    (movie-id (get movie-id proposal))
    (investor-balance (unwrap! (map-get? investor-balances { movie-id: movie-id, investor: tx-sender }) err-not-found))
    (voting-power (get balance investor-balance))
    (existing-vote (map-get? proposal-votes { proposal-id: proposal-id, voter: tx-sender }))
  )
    (asserts! (get is-active proposal) err-movie-not-active)
    (asserts! (< stacks-block-height (get end-block proposal)) err-voting-period-ended)
    (asserts! (is-none existing-vote) err-already-voted)
    (asserts! (> voting-power u0) err-insufficient-voting-power)
    
    (map-set proposal-votes
      { proposal-id: proposal-id, voter: tx-sender }
      { vote: vote, voting-power: voting-power, voted-at: stacks-block-height }
    )
    
    (map-set voting-proposals
      { proposal-id: proposal-id }
      (merge proposal {
        votes-for: (if vote (+ (get votes-for proposal) voting-power) (get votes-for proposal)),
        votes-against: (if vote (get votes-against proposal) (+ (get votes-against proposal) voting-power))
      })
    )
    
    (ok voting-power)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (map-get? voting-proposals { proposal-id: proposal-id }) err-not-found))
    (movie-id (get movie-id proposal))
    (movie (unwrap! (map-get? movies { movie-id: movie-id }) err-not-found))
  )
    (asserts! (get is-active proposal) err-movie-not-active)
    (asserts! (>= stacks-block-height (get end-block proposal)) err-voting-period-active)
    (asserts! (not (get is-executed proposal)) err-already-exists)
    (asserts! (> (get votes-for proposal) (get votes-against proposal)) err-invalid-amount)
    (asserts! (is-eq tx-sender (get proposer proposal)) err-unauthorized)
    
    (map-set voting-proposals
      { proposal-id: proposal-id }
      (merge proposal { is-executed: true })
    )
    
    (ok true)
  )
)

(define-read-only (get-proposal-info (proposal-id uint))
  (map-get? voting-proposals { proposal-id: proposal-id })
)

(define-read-only (get-vote-info (proposal-id uint) (voter principal))
  (map-get? proposal-votes { proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-proposal-result (proposal-id uint))
  (match (map-get? voting-proposals { proposal-id: proposal-id })
    proposal (let (
      (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
      (movie (unwrap-panic (map-get? movies { movie-id: (get movie-id proposal) })))
    )
      (some {
        total-votes: total-votes,
        votes-for: (get votes-for proposal),
        votes-against: (get votes-against proposal),
        is-passed: (> (get votes-for proposal) (get votes-against proposal)),
        is-active: (and (get is-active proposal) (< stacks-block-height (get end-block proposal))),
        participation-rate: (if (> total-votes u0) 
                             (/ (* total-votes u10000) (get total-supply movie))
                             u0)
      })
    )
    none
  )
)

(define-read-only (get-next-proposal-id)
  (var-get next-proposal-id)
)

(define-private (setup-default-tiers (movie-id uint) (target-amount uint))
  (let (
    (tier1-max (/ target-amount u10))
    (tier2-max (/ target-amount u4))
    (tier3-max (/ target-amount u2))
  )
    (map-set investment-tiers
      { movie-id: movie-id, tier: u1 }
      { min-amount: u1, max-amount: tier1-max, bonus-percentage: u500, tier-name: "Bronze Supporter" }
    )
    (map-set investment-tiers
      { movie-id: movie-id, tier: u2 }
      { min-amount: (+ tier1-max u1), max-amount: tier2-max, bonus-percentage: u1000, tier-name: "Silver Producer" }
    )
    (map-set investment-tiers
      { movie-id: movie-id, tier: u3 }
      { min-amount: (+ tier2-max u1), max-amount: tier3-max, bonus-percentage: u1500, tier-name: "Gold Executive" }
    )
    (map-set investment-tiers
      { movie-id: movie-id, tier: u4 }
      { min-amount: (+ tier3-max u1), max-amount: target-amount, bonus-percentage: u2500, tier-name: "Platinum Backer" }
    )
    (ok true)
  )
)

(define-read-only (calculate-investment-tier (movie-id uint) (amount uint))
  (let (
    (tier1 (map-get? investment-tiers { movie-id: movie-id, tier: u1 }))
    (tier2 (map-get? investment-tiers { movie-id: movie-id, tier: u2 }))
    (tier3 (map-get? investment-tiers { movie-id: movie-id, tier: u3 }))
    (tier4 (map-get? investment-tiers { movie-id: movie-id, tier: u4 }))
  )
    (if (and (is-some tier4) (<= (get min-amount (unwrap-panic tier4)) amount) (<= amount (get max-amount (unwrap-panic tier4))))
      { tier: u4, tier-info: (unwrap-panic tier4) }
      (if (and (is-some tier3) (<= (get min-amount (unwrap-panic tier3)) amount) (<= amount (get max-amount (unwrap-panic tier3))))
        { tier: u3, tier-info: (unwrap-panic tier3) }
        (if (and (is-some tier2) (<= (get min-amount (unwrap-panic tier2)) amount) (<= amount (get max-amount (unwrap-panic tier2))))
          { tier: u2, tier-info: (unwrap-panic tier2) }
          { tier: u1, tier-info: (unwrap-panic tier1) }
        )
      )
    )
  )
)

(define-read-only (calculate-tier-bonus (movie-id uint) (amount uint) (tier uint))
  (match (map-get? investment-tiers { movie-id: movie-id, tier: tier })
    tier-info
    (let (
      (base-tokens (calculate-tokens-for-investment movie-id amount))
      (bonus-percentage (get bonus-percentage tier-info))
    )
      (/ (* base-tokens bonus-percentage) u10000)
    )
    u0
  )
)

(define-read-only (calculate-early-bird-bonus (movie-id uint) (amount uint))
  (match (map-get? movies { movie-id: movie-id })
    movie
    (let (
      (creation-block (get creation-block movie))
      (early-bird-end (+ creation-block (var-get early-bird-duration)))
      (current-block stacks-block-height)
    )
      (if (<= current-block early-bird-end)
        (let (
          (base-tokens (calculate-tokens-for-investment movie-id amount))
          (early-bird-percentage u1000)
        )
          (/ (* base-tokens early-bird-percentage) u10000)
        )
        u0
      )
    )
    u0
  )
)

(define-read-only (get-investment-tier-info (movie-id uint) (tier uint))
  (map-get? investment-tiers { movie-id: movie-id, tier: tier })
)

(define-read-only (get-investor-tier-status (movie-id uint) (investor principal))
  (map-get? investor-tier-status { movie-id: movie-id, investor: investor })
)

(define-read-only (get-investment-preview (movie-id uint) (amount uint))
  (let (
    (base-tokens (calculate-tokens-for-investment movie-id amount))
    (movie-data (map-get? movies { movie-id: movie-id }))
  )
    (match movie-data
      movie
      (let (
        (tier-info (calculate-investment-tier movie-id amount))
        (tier-bonus (calculate-tier-bonus movie-id amount (get tier tier-info)))
        (early-bird-bonus (calculate-early-bird-bonus movie-id amount))
        (total-tokens (+ base-tokens tier-bonus early-bird-bonus))
      )
        {
          base-tokens: base-tokens,
          tier-level: (get tier tier-info),
          tier-name: (get tier-name (get tier-info tier-info)),
          tier-bonus: tier-bonus,
          early-bird-bonus: early-bird-bonus,
          total-tokens: total-tokens,
          bonus-percentage: (if (> base-tokens u0) (/ (* (+ tier-bonus early-bird-bonus) u10000) base-tokens) u0),
          early-bird-active: (<= stacks-block-height (+ (get creation-block movie) (var-get early-bird-duration)))
        }
      )
      {
        base-tokens: u0,
        tier-level: u0,
        tier-name: "",
        tier-bonus: u0,
        early-bird-bonus: u0,
        total-tokens: u0,
        bonus-percentage: u0,
        early-bird-active: false
      }
    )
  )
)

(define-read-only (get-all-movie-tiers (movie-id uint))
  (let (
    (tier1 (map-get? investment-tiers { movie-id: movie-id, tier: u1 }))
    (tier2 (map-get? investment-tiers { movie-id: movie-id, tier: u2 }))
    (tier3 (map-get? investment-tiers { movie-id: movie-id, tier: u3 }))
    (tier4 (map-get? investment-tiers { movie-id: movie-id, tier: u4 }))
  )
    {
      tier1: tier1,
      tier2: tier2,
      tier3: tier3,
      tier4: tier4
    }
  )
)

(define-read-only (get-early-bird-status (movie-id uint))
  (match (map-get? movies { movie-id: movie-id })
    movie
    (let (
      (creation-block (get creation-block movie))
      (early-bird-end (+ creation-block (var-get early-bird-duration)))
      (current-block stacks-block-height)
    )
      {
        is-active: (<= current-block early-bird-end),
        blocks-remaining: (if (<= current-block early-bird-end) (- early-bird-end current-block) u0),
        bonus-percentage: u1000,
        duration-blocks: (var-get early-bird-duration)
      }
    )
    {
      is-active: false,
      blocks-remaining: u0,
      bonus-percentage: u0,
      duration-blocks: u0
    }
  )
)
