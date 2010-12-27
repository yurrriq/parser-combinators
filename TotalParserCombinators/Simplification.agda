------------------------------------------------------------------------
-- Simplification of parsers
------------------------------------------------------------------------

module TotalParserCombinators.Simplification where

open import Algebra
open import Coinduction
open import Data.List using (List)
import Data.List.Any.BagAndSetEquality as BSEq
open import Data.Maybe using (Maybe); open Data.Maybe.Maybe
open import Data.Nat
open import Data.Product
open import Data.Product.N-ary
open import Function
open import Relation.Binary.PropositionalEquality using (_≡_; refl)
open import Relation.Binary.HeterogeneousEquality
  using (refl) renaming (_≅_ to _≅H_)

private
  module BSMonoid {k} {A : Set} =
    CommutativeMonoid (BSEq.commutativeMonoid k A)

open import TotalParserCombinators.Congruence
  hiding (return; fail; token) renaming (_∣_ to _∣′_)
import TotalParserCombinators.Congruence.Sound as C
open import TotalParserCombinators.BreadthFirst hiding (correct)
import TotalParserCombinators.InitialBag as I
open import TotalParserCombinators.Laws
open import TotalParserCombinators.Parser
open import TotalParserCombinators.Semantics using (parser)

------------------------------------------------------------------------
-- A helper function

private

  force : ∀ {Tok R xs} (p : ∞ (Parser Tok R xs)) →
          ∃ λ (p′ : Parser _ _ xs) → ♭ p ≅P p′
  force p = (♭ p , (♭ p ∎))

------------------------------------------------------------------------
-- Simplification

-- The function simplify₁ simplifies the first "layer" of a parser,
-- down to the first occurrences of ♯_. The following simplifications
-- are applied in a bottom-up manner:
--
-- f <$> fail                  → fail
-- f <$> return x              → return (f x)
-- fail         ∣ p            → p
-- p            ∣ fail         → p
-- token >>= p₁ ∣ token >>= p₂ → token >>= (λ t → p₁ t ∣ p₂ t)  (*)
-- fail     ⊛ p                → fail
-- p        ⊛ fail             → fail
-- return f ⊛ return x         → return (f x)
-- fail     >>= p              → fail
-- return x >>= p              → p x
-- nonempty fail               → fail
-- cast eq p                   → p
--
-- (*) Currently only when p₁ and p₂ are not delayed.
--
-- An example of a possible future addition:
--
-- (p₁ >>= p₂) >>= p₃ → ♭? p₁ >>= λ x → ♭? (p₂ x) >>= (♭? ∘ p₃)

private
 mutual

  simplify₁ : ∀ {Tok R xs} (p : Parser Tok R xs) →
              ∃₂ λ xs (p′ : Parser Tok R xs) → p ≅P p′

  -- • return:

  simplify₁ (return x) = (_ , return x , (return x ∎))

  -- • fail:

  simplify₁ fail       = (_ , fail     , (fail ∎))

  -- • token:

  simplify₁ token      = (_ , token    , (token ∎))

  -- • _<$>_:

  simplify₁ (f <$> p) with simplify₁ p
  ... | (._ , fail     , p≅∅)  = _ , _ , (
                                 f <$> p     ≅⟨ (λ _ → refl) <$> p≅∅ ⟩
                                 f <$> fail  ≅⟨ <$>.zero ⟩
                                 fail        ∎)
  ... | (._ , return x , p≅ε)  = _ , _ , (
                                 f <$> p         ≅⟨ (λ x → refl {x = f x}) <$> p≅ε ⟩
                                 f <$> return x  ≅⟨ <$>.homomorphism f ⟩
                                 return (f x)    ∎)
  ... | (_  , p′       , p≅p′) = _ , _ , (
                                 f <$> p   ≅⟨ (λ _ → refl) <$> p≅p′ ⟩
                                 f <$> p′  ∎)

  -- • _∣_:

  simplify₁ (p₁ ∣ p₂) with simplify₁ p₁ | simplify₁ p₂
  ... | (._ , fail          , p₁≅∅)
      | (_  , p₂′           , p₂≅p₂′) = _ , _ , (
                                        p₁   ∣ p₂   ≅⟨ p₁≅∅ ∣′ p₂≅p₂′ ⟩
                                        fail ∣ p₂′  ≅⟨ AdditiveMonoid.left-identity p₂′ ⟩
                                        p₂′         ∎)
  ... | (_  , p₁′           , p₁≅p₁′)
      | (._ , fail          , p₂≅∅)   = _ , _ , (
                                        p₁  ∣ p₂    ≅⟨ p₁≅p₁′ ∣′ p₂≅∅ ⟩
                                        p₁′ ∣ fail  ≅⟨ AdditiveMonoid.right-identity p₁′ ⟩
                                        p₁′         ∎)
  ... | (._ , _>>=_ {xs = just ._}
                    {f  = just _}
                    token p₁′ , p₁≅…)
      | (._ , _>>=_ {xs = just ._}
                    {f  = just _}
                    token p₂′ , p₂≅…) = _ , _ , (
                                        p₁            ∣ p₂               ≅⟨ p₁≅… ∣′ p₂≅… ⟩
                                        token >>= p₁′ ∣ token >>= p₂′    ≅⟨ [ ○ - ○ - ○ - ○ ] token ∎ >>= (λ x → p₁′ x ∎) ∣′
                                                                            [ ○ - ○ - ○ - ○ ] token ∎ >>= (λ x → p₂′ x ∎) ⟩
                                        token >>= p₁′ ∣ token >>= p₂′    ≅⟨ sym $ Monad.left-distributive token p₁′ p₂′ ⟩
                                        token >>= (λ t → p₁′ t ∣ p₂′ t)  ∎)
  ... | (_  , p₁′           , p₁≅p₁′)
      | (_  , p₂′           , p₂≅p₂′) = _ , _ , (
                                        p₁  ∣ p₂   ≅⟨ p₁≅p₁′ ∣′ p₂≅p₂′ ⟩
                                        p₁′ ∣ p₂′  ∎)

  -- • _⊛_:

  simplify₁ (p₁ ⊛ p₂) =
    helper _ _ p₁ p₂ (simplify₁′ p₁) (simplify₁′ p₂) refl refl
    where
    -- token ⊛ token is never type correct, but Agda's case-splitting
    -- machinery cannot see this, so instead of a with clause the
    -- following ugly machinery is used.

    cast₁ : ∀ {Tok R R₁ R₁′ xs xs′} {ys : Maybe (List R)} →
            (R≡  : R₁ ≡ R₁′) → xs ≅H xs′ →
            ∞⟨ ys ⟩Parser Tok R₁′ (flatten xs′) →
            ∞⟨ ys ⟩Parser Tok R₁  (flatten xs)
    cast₁ refl refl p = p

    helper : ∀ {Tok R₁ R₁′ R₂} fs xs {xs′}
               (p₁ : ∞⟨ xs ⟩Parser Tok (R₁ → R₂) (flatten fs))
               (p₂ : ∞⟨ fs ⟩Parser Tok  R₁′      (flatten xs′)) →
             (∃₂ λ xs (p₁′ : Parser _ _ xs) → ♭? p₁ ≅P p₁′) →
             (∃₂ λ xs (p₂′ : Parser _ _ xs) → ♭? p₂ ≅P p₂′) →
             (R≡  : R₁ ≡ R₁′) →
             (xs≅ : xs ≅H xs′) →
             ∃₂ λ xs (p′ : Parser _ _ xs) → p₁ ⊛ cast₁ R≡ xs≅ p₂ ≅P p′
    helper fs xs p₁ p₂ (._ , fail , p₁≅∅) _ refl refl = _ , _ , (
      p₁   ⊛ p₂     ≅⟨ [ xs - ○ - fs - ○ ] p₁≅∅ ⊛ (♭? p₂ ∎) ⟩
      fail ⊛ ♭? p₂  ≅⟨ ApplicativeFunctor.left-zero (♭? p₂) ⟩
      fail          ∎)
    helper fs xs p₁ p₂ _ (._ , fail , p₂≅∅) refl refl = _ , _ , (
      p₁    ⊛ p₂    ≅⟨ [ xs - ○ - fs - ○ ] ♭? p₁ ∎ ⊛ p₂≅∅ ⟩
      ♭? p₁ ⊛ fail  ≅⟨ ApplicativeFunctor.right-zero (♭? p₁) ⟩
      fail          ∎)
    helper fs xs p₁ p₂ (._ , return f , p₁≅ε) (._ , return x , p₂≅ε)
           refl refl = _ , _ , (
      p₁       ⊛ p₂        ≅⟨ [ xs - ○ - fs - ○ ] p₁≅ε ⊛ p₂≅ε ⟩
      return f ⊛ return x  ≅⟨ ApplicativeFunctor.homomorphism f x ⟩
      return (f x)         ∎)
    helper fs xs p₁ p₂ p₁′ p₂′ R≡ xs≅ =
      helper′ fs xs p₁ p₂ p₁′ p₂′ R≡ xs≅
      where
      helper′ :
        ∀ {Tok R₁ R₁′ R₂} fs xs {xs′}
          (p₁ : ∞⟨ xs ⟩Parser Tok (R₁ → R₂) (flatten fs))
          (p₂ : ∞⟨ fs ⟩Parser Tok  R₁′      (flatten xs′)) →
        (∃₂ λ xs (p₁′ : Parser _ _ xs) → ♭? p₁ ≅P p₁′) →
        (∃₂ λ xs (p₂′ : Parser _ _ xs) → ♭? p₂ ≅P p₂′) →
        (R≡  : R₁ ≡ R₁′) →
        (xs≅ : xs ≅H xs′) →
        ∃₂ λ xs (p′ : Parser _ _ xs) → p₁ ⊛ cast₁ R≡ xs≅ p₂ ≅P p′
      helper′ fs xs p₁ p₂ (_ , p₁′ , p₁≅p₁′) (_ , p₂′ , p₂≅p₂′)
              refl refl = _ , _ , (
        p₁  ⊛ p₂   ≅⟨ [ xs - ○ - fs - ○ ] p₁≅p₁′ ⊛ p₂≅p₂′ ⟩
        p₁′ ⊛ p₂′  ∎)

  -- • _>>=_:

  simplify₁ (_>>=_ {xs = xs} {f = f} p₁ p₂) with simplify₁′ p₁
  ... | (._ , fail     , p₁≅∅)  = _ , _ , (
                                  p₁   >>= p₂         ≅⟨ [ f - ○ - xs - ○ ] p₁≅∅ >>= (λ x → ♭? (p₂ x) ∎) ⟩
                                  fail >>= (♭? ∘ p₂)  ≅⟨ Monad.left-zero (♭? ∘ p₂) ⟩
                                  fail                ∎)
  ... | (._ , return x , p₁≅ε) with simplify₁′ (p₂ x)
  ...   | (_ , p₂x′ , p₂x≅p₂x′) = _ , _ , (
                                  p₁       >>= p₂         ≅⟨ [ f - ○ - xs - ○ ] p₁≅ε >>= (λ x → ♭? (p₂ x) ∎) ⟩
                                  return x >>= (♭? ∘ p₂)  ≅⟨ Monad.left-identity x (♭? ∘ p₂) ⟩
                                  ♭? (p₂ x)               ≅⟨ p₂x≅p₂x′ ⟩
                                  p₂x′                    ∎)
  simplify₁ (_>>=_ {xs = xs} {f = f} p₁ p₂)
      | (_ , p₁′ , p₁≅p₁′)      = _ , _ , (
                                  p₁  >>= p₂         ≅⟨ [ f - ○ - xs - ○ ] p₁≅p₁′ >>= (λ x → ♭? (p₂ x) ∎) ⟩
                                  p₁′ >>= (♭? ∘ p₂)  ∎)

  -- • nonempty:

  simplify₁ (nonempty p) with simplify₁ p
  ... | (._ , fail , p≅∅)  = _ , _ , (
                             nonempty p     ≅⟨ nonempty p≅∅ ⟩
                             nonempty fail  ≅⟨ Nonempty.zero ⟩
                             fail           ∎)
  ... | (_  , p′   , p≅p′) = _ , _ , (
                             nonempty p   ≅⟨ nonempty p≅p′ ⟩
                             nonempty p′  ∎)

  -- • cast:

  simplify₁ (cast xs₁≈xs₂ p) with simplify₁ p
  ... | (_ , p′ , p≅p′) = _ , _ , (
                          cast xs₁≈xs₂ p  ≅⟨ Cast.correct ⟩
                          p               ≅⟨ p≅p′ ⟩
                          p′              ∎)

  -- Note that if an argument parser is delayed, then simplification
  -- is not applied recursively (because this could lead to
  -- non-termination).

  simplify₁′ : ∀ {Tok R R′ xs} {m : Maybe R′}
               (p : ∞⟨ m ⟩Parser Tok R xs) →
               ∃₂ λ xs (p′ : Parser Tok R xs) → ♭? p ≅P p′
  simplify₁′ {m = nothing} p = (_ , ♭ p , (♭ p ∎))
  simplify₁′ {m = just _}  p = simplify₁ p

-- Deep simplification.
--
-- The function simplify simplifies the first layer, then it traverses
-- the result and simplifies the following layers, and so on. The
-- extra traversals have been implemented to satisfy Agda's
-- termination checker; they could perhaps be avoided.
--
-- One cast constructor is added for every delay constructor, plus one
-- at the top.
--
-- Note that simplifications in an upper layer do not get to take
-- advantage of simplifications performed in lower layers. Consider
-- ♯ p ⊛ token, for instance. If p can be simplified to fail, then one
-- might believe that ♯ p ⊛ token is simplified to fail as well.
-- However, this is only the case if p actually /computes/ to fail.
--
-- If simplification of the upper layer were dependent on complete
-- simplification of lower layers, then simplification could fail to
-- terminate. This does not mean that one cannot propagate /any/
-- information from lower layers to upper layers, though: one could
-- for instance perform partial simplification of lower layers, up to
-- a certain depth, before an upper layer is simplified.

mutual

  simplify : ∀ {Tok R xs} → Parser Tok R xs → Parser Tok R xs
  simplify p = cast (I.same-bag/set $ C.sound $ sym $ proj₂ simp)
                    (simplify↓ (proj₁ simp))
    where simp = proj₂ $ simplify₁ p

  simplify↓ : ∀ {Tok R xs} → Parser Tok R xs → Parser Tok R xs
  simplify↓ (return x)       = return x
  simplify↓ fail             = fail
  simplify↓ token            = token
  simplify↓ (p₁ ∣ p₂)        = simplify↓ p₁ ∣ simplify↓ p₂
  simplify↓ (f <$> p)        = f <$> simplify↓ p
  simplify↓ (p₁ ⊛ p₂)        = simplify↓′ p₁ ⊛ simplify↓′ p₂
  simplify↓ (p₁ >>= p₂)      = simplify↓′ p₁ >>= λ x → simplify↓′ (p₂ x)
  simplify↓ (nonempty p)     = nonempty (simplify↓ p)
  simplify↓ (cast xs₁≈xs₂ p) = cast xs₁≈xs₂ (simplify↓ p)

  simplify↓′ : ∀ {Tok R R′ xs} {m : Maybe R′} →
               ∞⟨ m ⟩Parser Tok R xs → ∞⟨ m ⟩Parser Tok R xs
  simplify↓′ {m = nothing} p = ♯ simplify (♭ p)
  simplify↓′ {m = just _}  p =   simplify↓   p

-- The simplifier is correct.

private

  dup : {A : Set} → A → Maybe A ^ 2
  dup x = (just x , just x)

mutual

  correct : ∀ {Tok R xs} (p : Parser Tok R xs) → simplify p ≅P p
  correct p =
    cast _ (simplify↓ (proj₁ simp))  ≅⟨ Cast.correct ⟩
    simplify↓ (proj₁ simp)           ≅⟨ correct↓ (proj₁ simp) ⟩
    proj₁ simp                       ≅⟨ sym $ proj₂ simp ⟩
    p                                ∎
    where simp = proj₂ $ simplify₁ p

  correct↓ : ∀ {Tok R xs} (p : Parser Tok R xs) → simplify↓ p ≅P p
  correct↓ (return x)       = return x ∎
  correct↓ fail             = fail ∎
  correct↓ token            = token ∎
  correct↓ (p₁ ∣ p₂)        = correct↓ p₁ ∣′ correct↓ p₂
  correct↓ (f <$> p)        = (λ _ → refl) <$> correct↓ p
  correct↓ (nonempty p)     = nonempty (correct↓ p)
  correct↓ (cast xs₁≈xs₂ p) = cast (correct↓ p)

  correct↓ (_⊛_   {fs = nothing} {xs = nothing} p₁ p₂) = [ nothing       - nothing       ] ♯ correct (♭ p₁) ⊛ ♯ correct (♭ p₂)
  correct↓ (_⊛_   {fs = nothing} {xs = just xs} p₁ p₂) = [ just (dup xs) - nothing       ]   correct↓   p₁  ⊛ ♯ correct (♭ p₂)
  correct↓ (_⊛_   {fs = just fs} {xs = nothing} p₁ p₂) = [ nothing       - just (dup fs) ] ♯ correct (♭ p₁) ⊛   correct↓   p₂
  correct↓ (_⊛_   {fs = just fs} {xs = just xs} p₁ p₂) = [ just (dup xs) - just (dup fs) ]   correct↓   p₁  ⊛   correct↓   p₂
  correct↓ (_>>=_ {xs = nothing} {f  = nothing} p₁ p₂) = [ nothing       - nothing       ] ♯ correct (♭ p₁) >>= λ x → ♯ correct (♭ (p₂ x))
  correct↓ (_>>=_ {xs = nothing} {f  = just f } p₁ p₂) = [ just (dup f)  - nothing       ]   correct↓   p₁  >>= λ x → ♯ correct (♭ (p₂ x))
  correct↓ (_>>=_ {xs = just xs} {f  = nothing} p₁ p₂) = [ nothing       - just (dup xs) ] ♯ correct (♭ p₁) >>= λ x →   correct↓   (p₂ x)
  correct↓ (_>>=_ {xs = just xs} {f  = just f } p₁ p₂) = [ just (dup f)  - just (dup xs) ]   correct↓   p₁  >>= λ x →   correct↓   (p₂ x)
