------------------------------------------------------------------------
-- This module proves that the parser combinators correspond exactly
-- to functions of type List Bool → List R (when the token type is
-- Bool)
------------------------------------------------------------------------

-- This result could be generalised to arbitrary finite token types.

module TotalParserCombinators.Parser.ExpressiveStrength
  where

open import Coinduction
open import Data.Bool hiding (_∧_)
open import Data.Empty
open import Data.Function
open import Data.List as List
open import Data.List.Any
open Membership-≡
open import Data.List.Reverse
open import Data.Product as Prod
open import Relation.Binary.PropositionalEquality
open import Relation.Nullary
open import Relation.Nullary.Decidable

open import TotalParserCombinators.Coinduction
open import TotalParserCombinators.Parser
open import TotalParserCombinators.Parser.Semantics
  hiding (sound; complete; complete′)
open import TotalParserCombinators.Parser.Lib
private
  open module Tok = Token Bool _≟_ using (tok)
import TotalParserCombinators.Backend.BreadthFirst
  as Backend

------------------------------------------------------------------------
-- Expressive strength

-- One direction of the correspondence has already been established:
-- For every parser there is an equivalent function.

parser⇒fun : ∀ {R xs} (p : Parser Bool R xs) →
             ∃ λ (f : List Bool → List R) →
               ∀ x s → x ∈ p · s ⇔ x ∈ f s
parser⇒fun p =
  ( Backend.parseComplete p
  , λ _ s → (Backend.complete s , Backend.sound s)
  )

-- For every function there is a corresponding parser.

fun⇒parser : ∀ {R} (f : List Bool → List R) →
             ∃ λ (p : Parser Bool R (f [])) →
               ∀ x s → x ∈ p · s ⇔ x ∈ f s
fun⇒parser {R} f = (p f , λ _ s → (sound f , complete f s))
  where
  specialise : ∀ {A B} → (List A → B) → A → (List A → B)
  specialise f x = λ xs → f (xs ∷ʳ x)

  return⋆ : (xs : List R) → Parser Bool R xs
  return⋆ []       = fail
  return⋆ (x ∷ xs) = return x ∣ return⋆ xs

  p : (f : List Bool → List R) → Parser Bool R (f [])
  p f = ⟪ ♯ (const <$> p (specialise f true )) ⟫ ⊛ ♯? (tok true )
      ∣ ⟪ ♯ (const <$> p (specialise f false)) ⟫ ⊛ ♯? (tok false)
      ∣ return⋆ (f [])

  return⋆-sound : ∀ {x s} xs → x ∈ return⋆ xs · s → s ≡ [] × x ∈ xs
  return⋆-sound []       ()
  return⋆-sound (y ∷ ys) (∣ˡ return)        = (refl , here refl)
  return⋆-sound (y ∷ ys) (∣ʳ .([ y ]) x∈ys) =
    Prod.map id there $ return⋆-sound ys x∈ys

  return⋆-complete : ∀ {x xs} → x ∈ xs → x ∈ return⋆ xs · []
  return⋆-complete (here refl)  = ∣ˡ return
  return⋆-complete (there x∈xs) =
    ∣ʳ [ _ ] (return⋆-complete x∈xs)

  sound : ∀ {x s} f → x ∈ p f · s → x ∈ f s
  sound f (∣ʳ ._ x∈) with return⋆-sound (f []) x∈
  ... | (refl , x∈′) = x∈′
  sound f (∣ˡ (∣ˡ (<$> x∈ ⊛ t∈))) with
    Tok.sound (cast∈ refl (♭?♯? (List.map const (f [ true  ]))) refl t∈)
  ... | (refl , refl) = sound (specialise f true ) x∈
  sound f (∣ˡ (∣ʳ ._ (<$> x∈ ⊛ t∈))) with
    Tok.sound (cast∈ refl (♭?♯? (List.map const (f [ false ]))) refl t∈)
  ... | (refl , refl) = sound (specialise f false) x∈

  complete′ : ∀ {x s} f → Reverse s → x ∈ f s → x ∈ p f · s
  complete′ f []                 x∈ = ∣ʳ [] (return⋆-complete x∈)
  complete′ f (bs ∶ rs ∶ʳ true ) x∈ =
    ∣ˡ {xs₁ = []} (∣ˡ (
      <$> complete′ (specialise f true ) rs x∈ ⊛
      cast∈ refl (sym (♭?♯? (List.map const (f [ true  ])))) refl
            Tok.complete))
  complete′ f (bs ∶ rs ∶ʳ false) x∈ =
    ∣ˡ (∣ʳ [] (
      <$> complete′ (specialise f false) rs x∈ ⊛
      cast∈ refl (sym (♭?♯? (List.map const (f [ false ])))) refl
            Tok.complete))

  complete : ∀ {x} f s → x ∈ f s → x ∈ p f · s
  complete f s = complete′ f (reverseView s)