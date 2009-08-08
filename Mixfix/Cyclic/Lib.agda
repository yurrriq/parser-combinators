------------------------------------------------------------------------
-- Small parser combinator library used by Mixfix.Cyclic.Grammar
------------------------------------------------------------------------

module Mixfix.Cyclic.Lib where

open import Coinduction
open import Data.Function using (const)
open import Data.Bool using (Bool; true; false)
open import Data.Nat using (ℕ; zero; suc; _+_)
open import Data.List using (List; []; _∷_; _++_)
open import Data.List.NonEmpty using (List⁺; [_]; _∷_; _∷ʳ_)
open import Data.Vec using (Vec; []; _∷_)
open import Data.Product
import Data.String as String
open import Relation.Binary
open DecSetoid String.decSetoid using (_≟_)
open import Relation.Nullary
open import Relation.Binary.PropositionalEquality using (_≡_; refl)

open import StructurallyRecursiveDescentParsing.Coinduction
open import StructurallyRecursiveDescentParsing.Parser
open import StructurallyRecursiveDescentParsing.Parser.Semantics
  hiding (cast∈; sound; complete)
open import Mixfix.Operator using (NamePart)

------------------------------------------------------------------------
-- Programs

-- Agda's termination checker only accepts corecursive definitions if
-- they are /syntactically/ guarded by constructors. The following
-- small language of "parser programs" reifies a selection of parser
-- combinators as /constructors/. These constructors are then used in
-- Mixfix.Cyclic.Grammar in order to ensure that Agda accepts the
-- grammars defined there.

infix  55 _+
infixl 50 _⊛_ _<$>_
infixl  5 _∣_
infixr  5 _∥_

data ParserProg : Set → Set1 where
  fail      : ∀ {R} → ParserProg R
  _∣_       : ∀ {R}
              (p₁ : ParserProg R)
              (p₂ : ParserProg R) →
                    ParserProg R
  _⊛_       : ∀ {R₁ R₂}
              (p₁ : ∞₁ (ParserProg (R₁ → R₂)))
              (p₂ : ∞₁ (ParserProg R₁)) →
                        ParserProg R₂
  _<$>_     : ∀ {R₁ R₂} (f : R₁ → R₂)
              (p : ParserProg R₁) →
                   ParserProg R₂
  _+        : ∀ {R} (p : ParserProg R) →
                         ParserProg (List⁺ R)
  _between_ : ∀ {R n}
              (p : ∞₁ (ParserProg R)) (toks : Vec NamePart (1 + n)) →
              ParserProg (Vec R n)
  _∥_       : ∀ {I i} {R : I → Set}
              (p₁ : ParserProg (R i))
              (p₂ : ParserProg (∃ R)) →
                    ParserProg (∃ R)

-- Parses a given token (or, really, a given equivalence class of
-- tokens).

theToken : NamePart → Parser NamePart NamePart []
theToken tok = token >>= λ tok′ → ♯₁ ok tok′
  module TheToken where
  okIndex : NamePart → List NamePart
  okIndex tok′ with tok ≟ tok′
  ... | yes _ = tok′ ∷ []
  ... | no  _ = []

  ok : (tok′ : NamePart) → Parser NamePart NamePart (okIndex tok′)
  ok tok′ with tok ≟ tok′
  ... | yes _ = return tok′
  ... | no  _ = fail

-- Interprets the parser programs as parsers.

private
  infix 10 ♯′_

  ♯′_ : ∀ {A} → A → ∞₁ A
  ♯′ x = ♯₁ x

⟦_⟧ : ∀ {R} → ParserProg R → Parser NamePart R []
⟦ fail                    ⟧ = fail
⟦ p₁ ∣ p₂                 ⟧ = ⟦ p₁ ⟧ ∣ ⟦ p₂ ⟧
⟦ p₁ ⊛ p₂                 ⟧ = [] ∶ ♯₁ ⟦ ♭₁ p₁ ⟧ ⊛ (♯₁ ⟦ ♭₁ p₂ ⟧)
⟦ f <$> p                 ⟧ = [] ∶ ♯′ return f ⊛ ⟦ p ⟧
⟦ p +                     ⟧ = ⟦ p ⟧ >>= λ x → ♯₁
                              (⟦ _∷_ x <$> p + ⟧ ∣ return [ x ])
⟦ p between (t ∷ [])      ⟧ = [] ∶ ♯′ return (const []) ⊛ theToken t
⟦ p between (t ∷ t′ ∷ ts) ⟧ = theToken t >>= λ _ → ♯₁
                              ⟦ (♯′ _∷_ <$> ♭₁ p) ⊛
                                (♯′ (p between (t′ ∷ ts)))
                              ⟧
⟦ p₁ ∥ p₂                 ⟧ = [] ∶ ♯′ return ,_ ⊛ ⟦ p₁ ⟧
                            ∣                     ⟦ p₂ ⟧

------------------------------------------------------------------------
-- Semantics of the programs

-- This definition may seem unnecessary: why not simply define
--
--   x ⊕ s′ ∈⟦ p ⟧· s  =  x ⊕ s′ ∈ ⟦ p ⟧ · s?
--
-- The reason is that it is hard for Agda to infer the value of p from
-- ⟦ p ⟧ (note that ⟦_⟧ is a function which evaluates). By using the
-- definition below this problem is avoided.

infix 4 _⊕_∈⟦_⟧·_

data _⊕_∈⟦_⟧·_ : ∀ {R} →
                 R → List NamePart →
                 ParserProg R → List NamePart → Set₁ where
  ∣ˡ         : ∀ {R x s s₁}
                 {p₁ : ParserProg R} {p₂ : ParserProg R}
               (x∈p₁ : x ⊕ s₁ ∈⟦ p₁ ⟧· s) → x ⊕ s₁ ∈⟦ p₁ ∣ p₂ ⟧· s
  ∣ʳ         : ∀ {R x s s₁}
                 {p₁ : ParserProg R} {p₂ : ParserProg R}
               (x∈p₂ : x ⊕ s₁ ∈⟦ p₂ ⟧· s) → x ⊕ s₁ ∈⟦ p₁ ∣ p₂ ⟧· s
  _⊛_        : ∀ {s s₁ s₂ R₁ R₂ f x}
                 {p₁ : ∞₁ (ParserProg (R₁ → R₂))}
                 {p₂ : ∞₁ (ParserProg R₁)}
               (f∈p₁ : f ⊕ s₁ ∈⟦ ♭₁ p₁ ⟧· s)
               (x∈p₂ : x ⊕ s₂ ∈⟦ ♭₁ p₂ ⟧· s₁) →
               f x ⊕ s₂ ∈⟦ p₁ ⊛ p₂ ⟧· s
  _<$>_      : ∀ {s s′ R₁ R₂ x} (f : R₁ → R₂) {p : ParserProg R₁}
               (x∈p : x ⊕ s′ ∈⟦ p ⟧· s) → f x ⊕ s′ ∈⟦ f <$> p ⟧· s
  +-[]       : ∀ {R x s s₁} {p : ParserProg R}
               (x∈p : x ⊕ s₁ ∈⟦ p ⟧· s) → [ x ] ⊕ s₁ ∈⟦ p + ⟧· s
  +-∷        : ∀ {R x s s₁ s₂ xs} {p : ParserProg R}
               (x∈p : x ⊕ s₁ ∈⟦ p ⟧· s) (xs∈p : xs ⊕ s₂ ∈⟦ p + ⟧· s₁) →
               x ∷ xs ⊕ s₂ ∈⟦ p + ⟧· s
  between-[] : ∀ {R t s} {p : ∞₁ (ParserProg R)} →
               [] ⊕ s ∈⟦ p between (t ∷ []) ⟧· t ∷ s
  between-∷  : ∀ {R n t x xs s s₁ s₂}
                 {p : ∞₁ (ParserProg R)} {ts : Vec NamePart (suc n)}
               (x∈p : x ⊕ s₁ ∈⟦ ♭₁ p ⟧· s)
               (xs∈⋯ : xs ⊕ s₂ ∈⟦ p between ts ⟧· s₁) →
               x ∷ xs ⊕ s₂ ∈⟦ p between (t ∷ ts) ⟧· t ∷ s
  ∥ˡ         : ∀ {I i} {R : I → Set} {x s s′}
                 {p₁ : ParserProg (R i)}
                 {p₂ : ParserProg (∃ R)}
               (x∈p₁ : x ⊕ s′ ∈⟦ p₁ ⟧· s) → (, x) ⊕ s′ ∈⟦ p₁ ∥ p₂ ⟧· s
  ∥ʳ         : ∀ {I i} {R : I → Set} {x s s′}
                 {p₁ : ParserProg (R i)}
                 {p₂ : ParserProg (∃ R)}
               (x∈p₂ : x ⊕ s′ ∈⟦ p₂ ⟧· s) → x ⊕ s′ ∈⟦ p₁ ∥ p₂ ⟧· s

-- The semantics is correct.

private

  theToken-sound : ∀ {t t′ s₁ s} →
                   t′ ⊕ s₁ ∈ theToken t · s →
                   t ≡ t′ × s ≡ t′ ∷ s₁
  theToken-sound {t} (_>>=_ {x = t″} token t′∈) with t ≟ t″
  theToken-sound (token >>= return) | yes t≈t″ = (t≈t″ , refl)
  theToken-sound (token >>= ())     | no  t≉t″

  theToken-complete : ∀ {t s} → t ⊕ s ∈ theToken t · t ∷ s
  theToken-complete {t} {s} = token >>= ok-lemma
    where
    ok-lemma : t ⊕ s ∈ TheToken.ok t t · s
    ok-lemma with t ≟ t
    ... | yes refl = return
    ... | no  t≢t  with t≢t refl
    ...   | ()

sound : ∀ {R x s s′} {p : ParserProg R} →
        x ⊕ s′ ∈⟦ p ⟧· s → x ⊕ s′ ∈ ⟦ p ⟧ · s
sound (∣ˡ x∈p₁)      = ∣ˡ    (sound x∈p₁)
sound (∣ʳ x∈p₂)      = ∣ʳ [] (sound x∈p₂)
sound (f∈p₁ ⊛ x∈p₂)  = sound f∈p₁ ⊛ sound x∈p₂
sound (f <$> x∈p)    = return ⊛ sound x∈p
sound (+-[] x∈p)     = sound x∈p >>= ∣ʳ [] return
sound (+-∷ x∈p xs∈p) = sound x∈p >>= ∣ˡ (return ⊛ sound xs∈p)
sound (∥ˡ x∈p₁)      = ∣ˡ (return ⊛ sound x∈p₁)
sound (∥ʳ x∈p₂)      = ∣ʳ [] (sound x∈p₂)
sound between-[]     = return ⊛ theToken-complete
sound (between-∷ {ts = _ ∷ _} x∈p xs∈⋯) =
  theToken-complete >>= return ⊛ sound x∈p ⊛ sound xs∈⋯

complete : ∀ {R x s s′} (p : ParserProg R) →
           x ⊕ s′ ∈ ⟦ p ⟧ · s → x ⊕ s′ ∈⟦ p ⟧· s
complete fail      ()

complete (p₁ ∣ p₂) (∣ˡ     x∈p₁) = ∣ˡ (complete p₁ x∈p₁)
complete (p₁ ∣ p₂) (∣ʳ .[] x∈p₂) = ∣ʳ (complete p₂ x∈p₂)

complete (p₁ ⊛ p₂) (f∈p₁ ⊛ y∈p₂) =
  complete (♭₁ p₁) f∈p₁ ⊛ complete (♭₁ p₂) y∈p₂

complete (f <$> p) (return ⊛ x∈p) = f <$> complete p x∈p

complete (p +) (x∈p >>= ∣ˡ (return ⊛ xs∈p+)) = +-∷  (complete p x∈p) (complete (p +) xs∈p+)
complete (p +) (x∈p >>= ∣ʳ .[] return)       = +-[] (complete p x∈p)

complete (p between (t ∷ [])) (return ⊛ t∈) with theToken-sound t∈
... | (refl , refl) = between-[]
complete (p between (t ∷ t′ ∷ ts))
         (t∈ >>= (return ⊛ x∈p ⊛ xs∈)) with theToken-sound t∈
... | (refl , refl) =
  between-∷ (complete (♭₁ p) x∈p) (complete (p between (t′ ∷ ts)) xs∈)

complete (p₁ ∥ p₂) (∣ˡ (return ⊛ x∈p₁)) = ∥ˡ (complete p₁ x∈p₁)
complete (p₁ ∥ p₂) (∣ʳ .[] x∈p₂)        = ∥ʳ (complete p₂ x∈p₂)

-- Some lemmas.

+-∷ʳ : ∀ {R x s s₁ s₂ xs} {p : ParserProg R} →
       xs ⊕ s₁ ∈⟦ p + ⟧· s → x ⊕ s₂ ∈⟦ p ⟧· s₁ →
       xs ∷ʳ x ⊕ s₂ ∈⟦ p + ⟧· s
+-∷ʳ (+-[] x∈p)     y∈p = +-∷ x∈p (+-[] y∈p)
+-∷ʳ (+-∷ x∈p xs∈p) y∈p = +-∷ x∈p (+-∷ʳ xs∈p y∈p)

cast∈ : ∀ {R x₁ x₂ s s′} {p : ParserProg R} →
        x₁ ≡ x₂ → x₁ ⊕ s′ ∈⟦ p ⟧· s → x₂ ⊕ s′ ∈⟦ p ⟧· s
cast∈ refl x∈p = x∈p