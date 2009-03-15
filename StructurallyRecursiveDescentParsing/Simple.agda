------------------------------------------------------------------------
-- A simple backend
------------------------------------------------------------------------

module StructurallyRecursiveDescentParsing.Simple where

open import Data.Bool
open import Data.Product
open import Data.BoundedVec.Inefficient
import Data.List as L; open L using (List)
open import Data.Nat
open import Data.Function
open import Category.Applicative.Indexed
open import Category.Monad.Indexed
open import Category.Monad.State
open import Coinduction

open import StructurallyRecursiveDescentParsing.Type
import StructurallyRecursiveDescentParsing.Grammars as G
open G using (⟦_⟧)

------------------------------------------------------------------------
-- Parser monad

private

  P : Set → IFun ℕ
  P Tok = IStateT (BoundedVec Tok) List

  open module M₁ {Tok} =
    RawIMonadPlus (StateTIMonadPlus (BoundedVec Tok) L.monadPlus)
    using ()
    renaming ( return to return′
             ; _>>=_  to _>>=′_
             ; _>>_   to _>>′_
             ; ∅      to fail′
             ; _∣_    to _∣′_
             )

  open module M₂ {Tok} =
    RawIMonadState (StateTIMonadState (BoundedVec Tok) L.monad)
    using ()
    renaming ( get    to get′
             ; put    to put′
             ; modify to modify′
             )

------------------------------------------------------------------------
-- Run function for the parsers

-- For every successful parse the run function returns the remaining
-- string. (Since there can be several successful parses a list of
-- strings is returned.)

-- This function is structurally recursive with respect to the
-- following lexicographic measure:
--
-- 1) The upper bound of the length of the input string.
-- 2) The parser's proper left corner tree.

mutual
  parse↓ : ∀ {Tok e R} n → Parser Tok e R →
           P Tok n (if e then n else pred n) R
  parse↓ n       (return x)                  = return′ x
  parse↓ n       fail                        = fail′
  parse↓ n       (_∣_ {true}          p₁ p₂) = parse↓ n       p₁   ∣′       parse↑ n      p₂
  parse↓ n       (_∣_ {false} {true}  p₁ p₂) = parse↑ n       p₁   ∣′       parse↓ n      p₂
  parse↓ n       (_∣_ {false} {false} p₁ p₂) = parse↓ n       p₁   ∣′       parse↓ n      p₂
  parse↓ n       (p₁ ?>>= p₂)                = parse↓ n       p₁ >>=′ λ x → parse↓ n     (p₂ x)
  parse↓ zero    (p₁ !>>= p₂)                = fail′
  parse↓ (suc n) (p₁ !>>= p₂)                = parse↓ (suc n) p₁ >>=′ λ x → parse↑ n (♭₁ (p₂ x))
  parse↓ n       token                       = get′ >>=′ eat
    where
    eat : ∀ {Tok n} → BoundedVec Tok n → P Tok n (pred n) Tok
    eat []      = fail′
    eat (c ∷ s) = put′ s >>′ return′ c

  parse↑ : ∀ {e Tok R} n → Parser Tok e R → P Tok n n R
  parse↑ {true}  n       p = parse↓ n p
  parse↑ {false} zero    p = fail′
  parse↑ {false} (suc n) p = parse↓ (suc n) p >>=′ λ r →
                             modify′ ↑        >>′
                             return′ r

-- Exported run function.

parse : ∀ {NT Tok i R} →
        G.Grammar NT Tok → G.Parser NT Tok i R →
        List Tok → List (R × List Tok)
parse g p s = L.map (map id toList) (parse↓ _ (⟦ p ⟧ g) (fromList s))

-- A variant which only returns parses which leave no remaining input.

parseComplete : ∀ {NT Tok i R} →
                G.Grammar NT Tok → G.Parser NT Tok i R →
                List Tok → List R
parseComplete g p s =
  L.map proj₁ (L.filter (L.null ∘ proj₂) (parse g p s))
