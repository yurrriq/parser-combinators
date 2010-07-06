------------------------------------------------------------------------
-- The backend does not remove any ambiguity
------------------------------------------------------------------------

-- This module contains a proof showing that
-- TotalParserCombinators.BreadthFirst.Derivative.complete is a right
-- inverse of TotalParserCombinators.BreadthFirst.Derivative.sound.
-- This implies that the (finite) type x ∈ parseComplete p s contains
-- at least as many proofs as x ∈ p · s. In other words, if the output
-- of parseComplete p s contains n copies of x, then there are at most
-- n distinct parse trees in x ∈ p · s.

module TotalParserCombinators.BreadthFirst.RightInverse where

open import Data.List
open import Data.Maybe
open import Relation.Binary.HeterogeneousEquality as H using (_≅_; refl)
open import Relation.Binary.PropositionalEquality

open import TotalParserCombinators.BreadthFirst.SoundComplete
open import TotalParserCombinators.Lib
import TotalParserCombinators.InitialBag as I
open import TotalParserCombinators.Parser
open import TotalParserCombinators.Semantics hiding (_≅_)

mutual

  ∂-sound∘∂-complete : ∀ {Tok R xs x s t} {p : Parser Tok R xs} →
                       (x∈p : x ∈ p · t ∷ s) →
                       ∂-sound p (∂-complete x∈p) ≡ x∈p
  ∂-sound∘∂-complete x∈p = H.≅-to-≡ (∂-sound∘∂-complete′ x∈p refl)

  ∂-sound∘∂-complete′ :
    ∀ {Tok R xs x s′ s t} {p : Parser Tok R xs}
    (x∈p : x ∈ p · s′) (eq : s′ ≡ t ∷ s) →
    ∂-sound p (∂-complete′ p x∈p eq) ≅ x∈p
  ∂-sound∘∂-complete′ token       refl = refl

  ∂-sound∘∂-complete′ (∣ˡ   x∈p₁) refl rewrite ∂-sound∘∂-complete x∈p₁ = refl
  ∂-sound∘∂-complete′ (∣ʳ _ x∈p₂) refl rewrite ∂-sound∘∂-complete x∈p₂ = refl

  ∂-sound∘∂-complete′ (<$> x∈p)   refl rewrite ∂-sound∘∂-complete x∈p  = refl

  ∂-sound∘∂-complete′       (_⊛_ {s₁ = _ ∷ _} {fs = nothing} {xs = just _}  f∈p₁ x∈p₂) refl
    rewrite ∂-sound∘∂-complete f∈p₁ = refl
  ∂-sound∘∂-complete′       (_⊛_ {s₁ = _ ∷ _} {fs = just _}  {xs = just _}  f∈p₁ x∈p₂) refl
    rewrite ∂-sound∘∂-complete f∈p₁ = refl
  ∂-sound∘∂-complete′ {Tok} (_⊛_ {s₁ = []}    {fs = just _}  {xs = just _}  f∈p₁ x∈p₂) refl
    rewrite Return⋆.sound∘complete {Tok = Tok} (I.complete f∈p₁)
          | I.sound∘complete f∈p₁
          | ∂-sound∘∂-complete x∈p₂ = refl

  ∂-sound∘∂-complete′       (_⊛_ {s₁ = _ ∷ _} {fs = nothing} {xs = nothing} f∈p₁ x∈p₂) refl
    rewrite ∂-sound∘∂-complete f∈p₁ = refl
  ∂-sound∘∂-complete′       (_⊛_ {s₁ = _ ∷ _} {fs = just _}  {xs = nothing} f∈p₁ x∈p₂) refl
    rewrite ∂-sound∘∂-complete f∈p₁ = refl
  ∂-sound∘∂-complete′ {Tok} (_⊛_ {s₁ = []}    {fs = just _}  {xs = nothing} f∈p₁ x∈p₂) refl
    rewrite Return⋆.sound∘complete {Tok = Tok} (I.complete f∈p₁)
          | I.sound∘complete f∈p₁
          | ∂-sound∘∂-complete x∈p₂ = refl

  ∂-sound∘∂-complete′       (_>>=_ {s₁ = _ ∷ _} {xs = nothing} {f = just _}  x∈p₁ y∈p₂x) refl
    rewrite ∂-sound∘∂-complete x∈p₁ = refl
  ∂-sound∘∂-complete′       (_>>=_ {s₁ = _ ∷ _} {xs = just _}  {f = just _}  x∈p₁ y∈p₂x) refl
    rewrite ∂-sound∘∂-complete x∈p₁ = refl
  ∂-sound∘∂-complete′ {Tok} (_>>=_ {s₁ = []}    {xs = just _}  {f = just _}  x∈p₁ y∈p₂x) refl
    rewrite Return⋆.sound∘complete {Tok = Tok} (I.complete x∈p₁)
          | I.sound∘complete x∈p₁
          | ∂-sound∘∂-complete y∈p₂x = refl

  ∂-sound∘∂-complete′       (_>>=_ {s₁ = _ ∷ _} {xs = nothing} {f = nothing} x∈p₁ y∈p₂x) refl
    rewrite ∂-sound∘∂-complete x∈p₁ = refl
  ∂-sound∘∂-complete′       (_>>=_ {s₁ = _ ∷ _} {xs = just _}  {f = nothing} x∈p₁ y∈p₂x) refl
    rewrite ∂-sound∘∂-complete x∈p₁ = refl
  ∂-sound∘∂-complete′ {Tok} (_>>=_ {s₁ = []}    {xs = just _}  {f = nothing} x∈p₁ y∈p₂x) refl
    rewrite Return⋆.sound∘complete {Tok = Tok} (I.complete x∈p₁)
          | I.sound∘complete x∈p₁
          | ∂-sound∘∂-complete y∈p₂x = refl

  ∂-sound∘∂-complete′ (nonempty x∈p) refl rewrite ∂-sound∘∂-complete x∈p = refl

  ∂-sound∘∂-complete′ (cast x∈p)     refl rewrite ∂-sound∘∂-complete x∈p = refl

  ∂-sound∘∂-complete′ (_⊛_   {s₁ = []} {fs = nothing} f∈p₁ _) _ with I.complete f∈p₁
  ... | ()
  ∂-sound∘∂-complete′ (_>>=_ {s₁ = []} {xs = nothing} x∈p₁ _) _ with I.complete x∈p₁
  ... | ()

  ∂-sound∘∂-complete′ return ()

sound∘complete : ∀ {Tok R xs x} {p : Parser Tok R xs}
                 (s : List Tok) (x∈p : x ∈ p · s) →
                 sound s (complete s x∈p) ≡ x∈p
sound∘complete []      x∈p = I.sound∘complete x∈p
sound∘complete (t ∷ s) x∈p
  rewrite sound∘complete s (∂-complete x∈p) = ∂-sound∘∂-complete x∈p
