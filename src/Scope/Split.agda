module Scope.Split where

open import Haskell.Prelude

open import Haskell.Extra.Dec
open import Haskell.Extra.Erase
open import Haskell.Extra.Refinement
open import Haskell.Law.Equality hiding (subst)
open import Haskell.Law.Monoid

open import Scope.Core

open import Utils.Misc

private variable
  @0 name : Set
  @0 x : name
  @0 α α₁ α₂ β β₁ β₂ γ δ ε : Scope name

-- This datatype has to use the actual [] and _∷_ constructors instead of
-- ∅ and _◃_, because otherwise the erased constructor arguments are not
-- recognized as being forced (see https://github.com/agda/agda/issues/6744).

data ListSplit {@0 name : Set} : (@0 α β γ : List (Erase name)) → Set where
  EmptyL : ∀ {@0 β} → ListSplit [] β β
  EmptyR : ∀ {@0 α} → ListSplit α [] α
  ConsL  : ∀ {@0 α β γ} (@0 x : name)
         → ListSplit             α  β             γ
         → ListSplit (Erased x ∷ α) β (Erased x ∷ γ)
  ConsR  : ∀ {@0 α β γ} (@0 y : name)
         → ListSplit α             β              γ
         → ListSplit α (Erased y ∷ β) (Erased y ∷ γ)
{-# COMPILE AGDA2HS ListSplit deriving Show #-}

opaque
  unfolding Scope

  -- OPI (Order-Preserving Interleaving)
  Split : (@0 α β γ : Scope name) → Set
  Split = ListSplit

  {-# COMPILE AGDA2HS Split inline #-}

  syntax Split α β γ = α ⋈ β ≡ γ

opaque
  unfolding Split

  splitEmptyLeft : mempty ⋈ β ≡ β
  splitEmptyLeft = EmptyL
  {-# COMPILE AGDA2HS splitEmptyLeft inline #-}

  splitEmptyRight : α ⋈ mempty ≡ α
  splitEmptyRight = EmptyR
  {-# COMPILE AGDA2HS splitEmptyRight inline #-}

  splitRefl : Rezz β → α ⋈ β ≡ (α <> β)
  splitRefl (rezz []) = splitEmptyRight
  splitRefl (rezz (Erased x ∷ β)) = ConsR x (splitRefl (rezz β))
  {-# COMPILE AGDA2HS splitRefl #-}

  splitComm : α ⋈ β ≡ γ → β ⋈ α ≡ γ
  splitComm EmptyL = EmptyR
  splitComm EmptyR = EmptyL
  splitComm (ConsL x p) = ConsR x (splitComm p)
  splitComm (ConsR y p) = ConsL y (splitComm p)
  {-# COMPILE AGDA2HS splitComm #-}

  splitAssoc
    : α ⋈ β ≡ γ
    → γ ⋈ δ ≡ ε
    → Σ0 _ λ ζ → (α ⋈ ζ ≡ ε) × (β ⋈ δ ≡ ζ)
  splitAssoc EmptyL q = < EmptyL , q >
  splitAssoc EmptyR q = < q , EmptyL >
  splitAssoc p EmptyR = < p , EmptyR >
  splitAssoc (ConsL x p) (ConsL .x q) =
    let < r , s > = splitAssoc p q
    in  < ConsL x r , s >
  splitAssoc (ConsR y p) (ConsL .y q) =
    let < r , s > = splitAssoc p q
    in  < ConsR y r , ConsL y s >
  splitAssoc p (ConsR y q) =
    let < r , s > = splitAssoc p q
    in  < ConsR y r , ConsR y s >
  {-# COMPILE AGDA2HS splitAssoc #-}

  -- NOTE(flupe): we force the use of 2-uples instead of 3/4-uples
  --              because compilation of the latter is buggy

  splitQuad
    : α₁ ⋈ α₂ ≡ γ
    → β₁ ⋈ β₂ ≡ γ
    → Σ0 ((Scope name × Scope name) × (Scope name × Scope name)) λ ((γ₁ , γ₂) , (γ₃ , γ₄)) →
        ((γ₁ ⋈ γ₂ ≡ α₁) × (γ₃ ⋈ γ₄ ≡ α₂)) ×
        ((γ₁ ⋈ γ₃ ≡ β₁) × (γ₂ ⋈ γ₄ ≡ β₂))
  splitQuad EmptyL q = < (EmptyL , q) , (EmptyL , EmptyL) >
  splitQuad EmptyR q = < (q , EmptyR) , (EmptyR , EmptyR) >
  splitQuad p EmptyL = < (EmptyL , EmptyL) , (EmptyL , p) >
  splitQuad p EmptyR = < (EmptyR , EmptyR) , (p , EmptyR) >
  splitQuad (ConsL x p) (ConsL x q) =
    let < (        r , s) , (        t , u) > = splitQuad p q
    in  < (ConsL x r , s) , (ConsL x t , u) >
  splitQuad (ConsL x p) (ConsR x q) =
    let < (        r , s) , (t ,         u) > = splitQuad p q
    in  < (ConsR x r , s) , (t , ConsL x u) >
  splitQuad (ConsR x p) (ConsL x q) =
    let < (r ,         s) , (        t , u) > = splitQuad p q
    in  < (r , ConsL x s) , (ConsR x t , u) >
  splitQuad (ConsR x p) (ConsR x q) =
    let < (r ,         s) , (t ,         u) > = splitQuad p q
    in  < (r , ConsR x s) , (t , ConsR x u) >
  {-# COMPILE AGDA2HS splitQuad #-}

opaque
  unfolding Split

  rezzSplit : α ⋈ β ≡ γ → Rezz γ → Rezz α × Rezz β
  rezzSplit EmptyL r = rezz [] , r
  rezzSplit EmptyR r = r , rezz []
  rezzSplit (ConsL x p) r =
    let (r1 , r2) = rezzSplit p (rezzTail r)
    in  (rezzBind r1) , r2
  rezzSplit (ConsR x p) r =
    let (r1 , r2) = rezzSplit p (rezzTail r)
    in  r1 , rezzBind r2
  {-# COMPILE AGDA2HS rezzSplit #-}

opaque
  unfolding Split

  rezzSplitLeft : α ⋈ β ≡ γ → Rezz γ → Rezz α
  rezzSplitLeft p r = fst (rezzSplit p r)
  {-# COMPILE AGDA2HS rezzSplitLeft #-}

  rezzSplitRight : α ⋈ β ≡ γ → Rezz γ → Rezz β
  rezzSplitRight p r = snd (rezzSplit p r)
  {-# COMPILE AGDA2HS rezzSplitRight #-}

  splitJoinLeft : Rezz β → α₁ ⋈ α₂ ≡ α → (α₁ <> β) ⋈ α₂ ≡ (α <> β)
  splitJoinLeft (rezz []) p = p
  splitJoinLeft (rezz (Erased x ∷ α)) p = ConsL x (splitJoinLeft (rezz α) p)
  {-# COMPILE AGDA2HS splitJoinLeft #-}

  splitJoinRight : Rezz β → α₁ ⋈ α₂ ≡ α → α₁ ⋈ (α₂ <> β) ≡ (α <> β)
  splitJoinRight (rezz []) p = p
  splitJoinRight (rezz (Erased x ∷ α)) p = ConsR x (splitJoinRight (rezz α) p)
  {-# COMPILE AGDA2HS splitJoinRight #-}

  splitJoin
    : Rezz β
    → α₁ ⋈ α₂ ≡ α
    → β₁ ⋈ β₂ ≡ β
    → (α₁ <> β₁) ⋈ (α₂ <> β₂) ≡ (α <> β)
  splitJoin r p EmptyL      = splitJoinRight r p
  splitJoin r p EmptyR      = splitJoinLeft  r p
  splitJoin r p (ConsL x q) = ConsL x (splitJoin (rezzTail r) p q)
  splitJoin r p (ConsR x q) = ConsR x (splitJoin (rezzTail r) p q)
  {-# COMPILE AGDA2HS splitJoin #-}

splitJoinLeftr : Rezz β → β₁ ⋈ β₂ ≡ β → (α <> β₁) ⋈ β₂ ≡ (α <> β)
splitJoinLeftr {β = β} {β₁ = β₁} {β₂ = β₂} {α = α} r p =
  subst (λ γ → (α <> β₁) ⋈ γ ≡ (α <> β)) (leftIdentity β₂) (splitJoin r splitEmptyRight p)
{-# COMPILE AGDA2HS splitJoinLeftr #-}

splitJoinRightr : Rezz β → β₁ ⋈ β₂ ≡ β → β₁ ⋈ (α <> β₂) ≡ (α <> β)
splitJoinRightr {β = β} {β₁ = β₁} {β₂ = β₂} {α = α} r p =
  subst (λ γ → γ ⋈ (α <> β₂) ≡ (α <> β)) (leftIdentity β₁) (splitJoin r splitEmptyLeft p)
{-# COMPILE AGDA2HS splitJoinRightr #-}

opaque
  unfolding Split

  splitBindLeft : α ⋈ β ≡ γ → (α ▸ x) ⋈ β ≡ (γ ▸ x)
  splitBindLeft {x = x} = splitJoinLeft (rezz [ x ])
  {-# COMPILE AGDA2HS splitBindLeft #-}

  splitBindRight : α ⋈ β ≡ γ → α ⋈ (β ▸ x) ≡ (γ ▸ x)
  splitBindRight {x = x} = splitJoinRight (rezz [ x ])
  {-# COMPILE AGDA2HS splitBindRight #-}

{-
The following statement is FALSE:
  ⋈-unique-left : α₁ ⋈ β ≡ γ → α₂ ⋈ β ≡ γ → α₁ ≡ α₂

Counterexample:

  left  left right right done : 1 2 ⋈ 1 2 ≡ 1 2 1 2
  right left left  right done : 2 1 ⋈ 1 2 ≡ 1 2 1 2

-}

opaque
  unfolding Split

  decSplit : (p q : α ⋈ β ≡ γ) → Dec (p ≡ q)
  decSplit (EmptyL   ) (EmptyL   ) = True ⟨ refl ⟩
  decSplit (EmptyR   ) (EmptyR   ) = True ⟨ refl ⟩
  decSplit (ConsL x p) (ConsL x q) = mapDec (cong (ConsL x)) (λ where refl → refl) (decSplit p q)
  decSplit (ConsR x p) (ConsR x q) = mapDec (cong (ConsR x)) (λ where refl → refl) (decSplit p q)
  decSplit (EmptyL   ) (EmptyR   ) = False ⟨ (λ ()) ⟩
  decSplit (EmptyL   ) (ConsR y q) = False ⟨ (λ ()) ⟩
  decSplit (EmptyR   ) (EmptyL   ) = False ⟨ (λ ()) ⟩
  decSplit (EmptyR   ) (ConsL x q) = False ⟨ (λ ()) ⟩
  decSplit (ConsL x p) (EmptyR   ) = False ⟨ (λ ()) ⟩
  decSplit (ConsL x p) (ConsR x q) = False ⟨ (λ ()) ⟩
  decSplit (ConsR x p) (EmptyL   ) = False ⟨ (λ ()) ⟩
  decSplit (ConsR x p) (ConsL x q) = False ⟨ (λ ()) ⟩
  {-# COMPILE AGDA2HS decSplit #-}

  syntax decSplit p q = p ⋈-≟ q

  @0 ∅-⋈-injective : mempty ⋈ α ≡ β → α ≡ β
  ∅-⋈-injective EmptyL = refl
  ∅-⋈-injective EmptyR = refl
  ∅-⋈-injective (ConsR x p) rewrite ∅-⋈-injective p = refl

opaque
  unfolding Split splitRefl rezzSplit splitJoin splitBindLeft decSplit
  SplitThings : Set₁
  SplitThings = Set
