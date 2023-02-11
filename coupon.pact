;; MODULE Couponing System ;;

; Namespace on public blockchain
;(namespace "free")

; Namespace for REPL-Tests
(namespace (read-msg 'ns))

; Capability to sign a transfer
;(free.couponsystem.TRANSFER "k:alice" "k:bob" "collection1" 1)

(module couponsystem GOVERNANCE

(defschema coupon-collection-schema ; Key = Name
  description:string
  max_supply:integer
  current_supply:integer
  discount:integer
)

(defschema coupon-ledger-schema ; Key = (generate-collection-id collection id)
  collection:string
  id:integer
  account:string
  guard:keyset
  password-hash:string
)

(deftable coupon-collection-table:{coupon-collection-schema})
(deftable coupon-ledger-table:{coupon-ledger-schema})

(defcap GOVERNANCE()
  @doc "Give the admin full access to call and upgrade the module."
  (enforce-keyset "free.fmg-dev-fabian")
)

(defcap VENDOR()
  @doc "Makes sure only authorized stores can issue coupons."
  true
)

(defcap OWNER (collection:string id:integer)
  @doc "Makes sure that users can only use their coupons."
  (with-read coupon-ledger-table (generate-collection-id collection id) {'account := nft-owner}
  (compose-capability (ACCOUNT_GUARD nft-owner))
  )
)

(defcap ACCOUNT_GUARD(account:string)
  @doc "Makes sure that users can only use their coupons. Reads from native 'coin' Smart Contract."
  (enforce-guard (at "guard" (coin.details account)))
)

(defcap PRIVATE()
  @doc "can only be called from a this Smart Contract."
  true
)

;; DEFINE Constants ;;
(defconst BURN_ACCOUNT "k:burn")
(defconst EXC_NAME_LENGTH "Name can not be empty or longer than 64 characters.")
(defconst EXC_DESCRIPTION_LENGTH "Description must be longer than 20.")
(defconst EXC_VALID_UNTIL "Expiry Date must be in the future.")
(defconst EXC_UNKNOWN_TYPE "Expiry Date must be in the future.")
(defconst EXC_INVALID_COLLECTION_SIZE "Supply must be greater than 0.")
(defconst EXC_DISCOUNT "Discount can not be a negative number or greater than 100.")
(defconst EXC_MAX_SUPPLY_REACHED "Maximum number of cupouns generated.")
(defconst EXC_K_ACCOOUNT "For security, only support k: accounts.")
(defconst EXC_RECEIVER "Invalid Receiver.")
(defconst EXC_SENDER "Invalid Sender.")
(defconst EXC_NO_PASSWORD_HASH "Please add a password-hashed first.")
(defconst EXC_PASSWORD_HASH "password-hash already provided.")
(defconst EXC_INVALID_PASSWORD_HASH "Wrong password!")

(defun get-current-time:time()
  @doc "Returns current chain's block-time in time type"
  (at 'block-time (chain-data))
)

(defun create-collection:string(name:string description:string max_supply:integer discount:integer)
@doc "Creates a new collection. Supply is limited to max_supply. Discount in percent (min 1%, max 100%)"
  (with-capability (VENDOR)
    (enforce (!= name "") EXC_NAME_LENGTH)
    (enforce (<= (length name) 64) EXC_NAME_LENGTH)
    (enforce (> (length description) 20) EXC_DESCRIPTION_LENGTH)
    (enforce (>= max_supply 1) EXC_INVALID_COLLECTION_SIZE)
    (enforce (> discount 0) EXC_DISCOUNT)
    (enforce (<= discount 100) EXC_DISCOUNT)

    (insert coupon-collection-table name {
      'description:description,
      'max_supply:max_supply,
      'discount:discount,
      'current_supply:0
    })
  )
  (format "Collection {} created. Supply: {}. Discount: {}" [name, max_supply, discount])
)

(defun mint-coupon(collection:string account:string)
@doc "Generates a coupon from a collection for 'account'."
  (with-read coupon-collection-table collection {
    'current_supply := current_supply,
    'max_supply := max_supply
  }
  (enforce (< current_supply max_supply) EXC_MAX_SUPPLY_REACHED)
  )

  (with-capability (VENDOR)
    (enforce (= "k:" (take 2 account)) EXC_K_ACCOOUNT)
    (insert coupon-ledger-table (generate-collection-id collection (get-next-id collection)) {
      'id:(get-next-id collection),
      'collection:collection,
      'account:account,
      'guard:(at 'guard (coin.details account)),
      'password-hash:""
      })
    (update coupon-collection-table collection {
      'current_supply:(get-next-id collection)
    })
  )
  (format "Created coupon {} for {}" [collection, account])
)

(defun transfer-coupon(sender:string receiver:string collection:string id:integer)
@doc "Sends coupon to another user."
  (enforce (!= sender "") EXC_SENDER)
  (enforce (!= receiver "") EXC_RECEIVER)
  (with-capability (OWNER collection id)
    (update coupon-ledger-table (generate-collection-id collection id) {
      'account: receiver, 
      'guard:(at 'guard (coin.details receiver))
    })
  (format "Transfer for {} completed. New owner: {}" [(generate-collection-id collection id), receiver])
  )
)

(defun redeem-coupon(sender:string collection:string id:integer)
@doc "Used when redemption process takes place on the blockchain. You can call / do whatever you want."
  (transfer-coupon sender BURN_ACCOUNT collection id)
  ; Action
  true
)

(defun add-password-hash(sender:string collection:string id:integer password-hash:string)
@doc "Add a hashed password to your coupon. Used for redeeming in a physical store."
  (let ((password-hash (get-password-hash collection id)))
  (enforce (= password-hash "") EXC_PASSWORD_HASH)
)

(with-capability (OWNER collection id)
  (update coupon-ledger-table (generate-collection-id collection id) {
    'password-hash:password-hash
  })
)
  (format "Make sure to remember your payment proof." [])
)

(defun redeem-coupon-payment-proof(sender:string collection:string id:integer)
@doc "Used for redeeming in a physical store. Initiates redemption process."
  (let ((password-hash (get-password-hash collection id)))
    (enforce (!= password-hash "") EXC_NO_PASSWORD_HASH)
  )

  (transfer-coupon sender BURN_ACCOUNT collection id)
  (format "Coupon redeemed." [])
)

(defun mark-coupon-payment-proof(collection:string id:integer password:string)
@doc "Marks coupon as invaled to prevent multiple redemption."
  (with-read coupon-ledger-table (generate-collection-id collection id) {"password-hash":= password-hash}
  (enforce (= password-hash (hash password)) EXC_INVALID_PASSWORD_HASH)

    (update coupon-ledger-table (generate-collection-id collection id) {
      'password-hash:""
    }
    )
  "Coupon redeemed."
  )
)

(defun generate-collection-id:string(collection:string id:integer)
@doc "Generates primary key for coupon ledger."
  (format "{}-{}" [collection (int-to-str 10 id)])
)

(defun get-next-id:integer(collection:string)
@doc "Returns next ID for coupon."
  (+ (get-current-supply collection) 1)
)

(defun get-coupons-by-account(account:string)
@doc "Returns user's coupons."
  ; Workaround https://github.com/kadena-io/pact/pull/1090
  ;(select coupon-ledger-table ['collection, 'id] (where 'account (= account)) )
  true
)

(defun get-password-hash(collection:string id:integer)
@doc "returns hashed password for coupon. If no value is present, '' is returned."
  (with-read coupon-ledger-table (generate-collection-id collection id) {"password-hash":= password-hash}
    password-hash
  )
)

(defun get-current-supply(collection:string)
@doc "Return collection's supply."
  (with-read coupon-collection-table collection { "current_supply":= current-supply}
    current-supply
  )
)

(defun get-max-supply(collection:string)
@doc "Return collection's maximum supply."
  (with-read coupon-collection-table collection { "max_supply":= max-supply}
    max-supply
  )
)

(defun get-discount(collection:string)
@doc "Returns granted discount for collection."
  (with-read coupon-collection-table collection { "discount":= discount}
    discount
  )
)

(defun get-current-and-max-supply(collection:string)
@doc "Return collection's minimum and maximum supply."
  (with-read coupon-collection-table collection { "max_supply":= max-supply}
    (with-read coupon-collection-table collection { "current_supply":= current-supply}
      (format "{}/{}" [current-supply, max-supply])
    )
  )
)
)

; Used when initating Smart Contract. Only used once.
;(create-table coupon-collection-table)
;(create-table coupon-ledger-table)
