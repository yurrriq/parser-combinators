------------------------------------------------------------------------
-- Semantics of the parsers
------------------------------------------------------------------------

-- Currently it is only specified when a string is _accepted_ by a
-- parser; semantic actions are not included.

module Parser.Semantics where

open import Parser

open import Data.List
open import Data.Product.Record
open import Data.Maybe
open import Logic

infix 3 _∈⟦_⟧_

mutual

  _∈⟦_⟧_ : forall {tok nt i r} ->
           [ tok ] -> Parser tok nt i r -> Grammar tok nt -> Set1
  s ∈⟦ p ⟧ g = Semantics g s p

  data Semantics {tok : Set} {nt : ParserType} (g : Grammar tok nt)
                 : forall {i r} ->
                   [ tok ] -> Parser tok nt i r -> Set1 where
    !-sem      : forall {e c r} s (x : nt (e , c) r) ->
                 s ∈⟦ g x ⟧ g -> s ∈⟦ ! x ⟧ g
    return-sem : forall {r} (x : r) -> [] ∈⟦ return x ⟧ g
    sat-sem    : forall {r} (p : tok -> Maybe r) c x -> p c ≡ just x ->
                 c ∷ [] ∈⟦ sat p ⟧ g
    forget-sem : forall {e c r s} {p : Parser tok nt (e , c) r} ->
                 s ∈⟦ p ⟧ g -> s ∈⟦ forget p ⟧ g
    -- The following rule should really describe the intended
    -- semantics of _>>=_, not _⊛_.
    ⊛-sem      : forall {i₁ i₂ r₁ r₂ s₁ s₂}
                        {p₁ : Parser tok nt i₁ (r₁ -> r₂)}
                        {p₂ : Parser tok nt i₂ r₁} ->
                 s₁ ∈⟦ p₁ ⟧ g -> s₂ ∈⟦ p₂ ⟧ g -> s₁ ++ s₂ ∈⟦ p₁ ⊛ p₂ ⟧ g
    ∣ˡ-sem     : forall {i₁ i₂ r s}
                        {p₁ : Parser tok nt i₁ r}
                        {p₂ : Parser tok nt i₂ r} ->
                 s ∈⟦ p₁ ⟧ g -> s ∈⟦ p₁ ∣ p₂ ⟧ g
    ∣ʳ-sem     : forall {i₁ i₂ r s}
                        {p₁ : Parser tok nt i₁ r}
                        {p₂ : Parser tok nt i₂ r} ->
                 s ∈⟦ p₂ ⟧ g -> s ∈⟦ p₁ ∣ p₂ ⟧ g

------------------------------------------------------------------------
-- Soundness of recognition

data NonEmpty {a : Set} : [ a ] -> Set where
  nonEmpty : forall x xs -> NonEmpty (x ∷ xs)

postulate
  sound : forall {tok nt i r}
          (p : Parser tok nt i r) (g : Grammar tok nt) (s : [ tok ]) ->
          NonEmpty (parse-complete p g s) -> s ∈⟦ p ⟧ g
