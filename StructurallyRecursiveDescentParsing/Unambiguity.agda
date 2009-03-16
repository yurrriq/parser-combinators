------------------------------------------------------------------------
-- Unambiguity
------------------------------------------------------------------------

module StructurallyRecursiveDescentParsing.Unambiguity where

open import Coinduction
open import Data.Bool
open import Data.List
open import Relation.Binary.PropositionalEquality

open import StructurallyRecursiveDescentParsing.Type

------------------------------------------------------------------------
-- Definition

-- A parser is unambiguous if it can yield at most one result for any
-- given input.
--
-- Note that this definition is a bit more general than the following
-- definition of unambiguity: "A grammar is unambiguous if there is at
-- most one parse tree which flattens to any given string."
--
-- Note also that this definition uses propositional equality, both
-- for the return values (x₁ and x₂) and for the input string (s). In
-- some cases other choices may be more useful.

Unambiguous : ∀ {Tok R e} → Parser Tok e R → Set1
Unambiguous p = ∀ {x₁ x₂ s} → x₁ ∈ p · s → x₂ ∈ p · s → x₁ ≡ x₂

------------------------------------------------------------------------
-- A more concrete characterisation of unambiguity

-- Note that this definition is inductive.

data Unambiguous′ {Tok} : ∀ {e R} → Parser Tok e R → Set1 where
  return : ∀ {R} {x : R} → Unambiguous′ (return x)
  fail   : ∀ {R} → Unambiguous′ (fail {R = R})
  token  : Unambiguous′ token
  choice : ∀ {R e₁ e₂} {p₁ : Parser Tok e₁ R} {p₂ : Parser Tok e₂ R}
           (u₁ : Unambiguous′ p₁) (u₂ : Unambiguous′ p₂) →
           (u : ∀ {x₁ x₂ s} → x₁ ∈ p₁ · s → x₂ ∈ p₂ · s → x₁ ≡ x₂) →
           Unambiguous′ (p₁ ∣ p₂)
  ?bind  : ∀ {R₁ R₂ e₂}
             {p₁ : Parser Tok true R₁} {p₂ : R₁ → Parser Tok e₂ R₂}
           (u : ∀ {x₁ x₂ y₁ y₂ s s₁ s₂ s₃ s₄} →
              x₁ ∈ p₁ · s₁ → y₁ ∈ p₂ x₁ · s₂ → s₁ ++ s₂ ≡ s →
              x₂ ∈ p₁ · s₃ → y₂ ∈ p₂ x₂ · s₄ → s₃ ++ s₄ ≡ s →
              y₁ ≡ y₂) →
           Unambiguous′ (p₁ ?>>= p₂)
  !bind  : ∀ {R₁ R₂} {e₂ : R₁ → Bool}
             {p₁ : Parser Tok false R₁}
             {p₂ : (x : R₁) → ∞₁ (Parser Tok (e₂ x) R₂)}
           (u : ∀ {x₁ x₂ y₁ y₂ s s₁ s₂ s₃ s₄} →
              x₁ ∈ p₁ · s₁ → y₁ ∈ ♭₁ (p₂ x₁) · s₂ → s₁ ++ s₂ ≡ s →
              x₂ ∈ p₁ · s₃ → y₂ ∈ ♭₁ (p₂ x₂) · s₄ → s₃ ++ s₄ ≡ s →
              y₁ ≡ y₂) →
           Unambiguous′ (p₁ !>>= p₂)

-- The two definitions are equivalent.

sound : ∀ {Tok e R} {p : Parser Tok e R} →
        Unambiguous′ p → Unambiguous p
sound return           return      return      = refl
sound fail             ()          ()
sound token            token       token       = refl
sound (choice u₁ u₂ u) (∣ˡ x∈p₁·s) (∣ˡ y∈p₁·s) =      sound u₁ x∈p₁·s y∈p₁·s
sound (choice u₁ u₂ u) (∣ˡ x∈p₁·s) (∣ʳ y∈p₂·s) =      u        x∈p₁·s y∈p₂·s
sound (choice u₁ u₂ u) (∣ʳ x∈p₂·s) (∣ˡ y∈p₁·s) = sym (u        y∈p₁·s x∈p₂·s)
sound (choice u₁ u₂ u) (∣ʳ x∈p₂·s) (∣ʳ y∈p₂·s) =      sound u₂ x∈p₂·s y∈p₂·s
sound (?bind {p₁ = p₁} {p₂} u) x∈p·s y∈p·s     = helper x∈p·s y∈p·s refl
  where
  helper : ∀ {x₁ x₂ s₁ s₂} →
           x₁ ∈ p₁ ?>>= p₂ · s₁ → x₂ ∈ p₁ ?>>= p₂ · s₂ →
           s₁ ≡ s₂ → x₁ ≡ x₂
  helper (x∈p₁·s₁₁ ?>>= y∈p₂x·s₁₂) (x∈p₁·s₂₁ ?>>= y∈p₂x·s₂₂) eq =
    u x∈p₁·s₁₁ y∈p₂x·s₁₂ eq x∈p₁·s₂₁ y∈p₂x·s₂₂ refl
sound (!bind {p₁ = p₁} {p₂} u) x∈p·s y∈p·s = helper x∈p·s y∈p·s refl
  where
  helper : ∀ {x₁ x₂ s₁ s₂} →
           x₁ ∈ p₁ !>>= p₂ · s₁ → x₂ ∈ p₁ !>>= p₂ · s₂ →
           s₁ ≡ s₂ → x₁ ≡ x₂
  helper (x∈p₁·s₁₁ !>>= y∈p₂x·s₁₂) (x∈p₁·s₂₁ !>>= y∈p₂x·s₂₂) eq =
    u x∈p₁·s₁₁ y∈p₂x·s₁₂ eq x∈p₁·s₂₁ y∈p₂x·s₂₂ refl

complete : ∀ {Tok e R} (p : Parser Tok e R) →
           Unambiguous p → Unambiguous′ p
complete (return x)   _ = return
complete fail         _ = fail
complete token        _ = token
complete (p₁ ∣ p₂)    u = choice (complete p₁ (λ x₁∈ x₂∈ → u (∣ˡ x₁∈) (∣ˡ x₂∈)))
                                 (complete p₂ (λ x₁∈ x₂∈ → u (∣ʳ {p₁ = p₁} x₁∈)
                                                             (∣ʳ {p₁ = p₁} x₂∈)))
                                 (λ x₁∈ x₂∈ → u (∣ˡ x₁∈) (∣ʳ {p₁ = p₁} x₂∈))
complete (p₁ ?>>= p₂) u = ?bind (λ x₁∈ y₁∈ eq₁ x₂∈ y₂∈ eq₂ →
                                   u (x₁∈ ?>>= y₁∈) (cast (trans eq₂ (sym eq₁))
                                                          (x₂∈ ?>>= y₂∈)))
complete (p₁ !>>= p₂) u = !bind (λ x₁∈ y₁∈ eq₁ x₂∈ y₂∈ eq₂ →
                                   u (x₁∈ !>>= y₁∈) (cast (trans eq₂ (sym eq₁))
                                                          (x₂∈ !>>= y₂∈)))
