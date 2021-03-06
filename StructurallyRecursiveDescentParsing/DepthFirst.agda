------------------------------------------------------------------------
-- A depth-first backend
------------------------------------------------------------------------

-- Based on the parser combinators in Wadler's "How to Replace Failure
-- by a List of Successes".

module StructurallyRecursiveDescentParsing.DepthFirst where

open import Data.Bool
open import Data.Product as Prod
open import Data.BoundedVec.Inefficient
import Data.List as L; open L using (List)
import Data.List.Categorical
open import Data.Nat
open import Function
open import Category.Applicative.Indexed
open import Category.Monad.Indexed
open import Category.Monad.State
open import Coinduction
import Level

open import StructurallyRecursiveDescentParsing.Simplified

------------------------------------------------------------------------
-- Parser monad

private

  P : Set → IFun ℕ Level.zero
  P Tok = IStateT (BoundedVec Tok) List

  open module M₁ {Tok : Set} =
    RawIMonadPlus (StateTIMonadPlus (BoundedVec Tok)
                     Data.List.Categorical.monadPlus)
    using ()
    renaming ( return to return′
             ; _>>=_  to _>>=′_
             ; _>>_   to _>>′_
             ; ∅      to fail′
             ; _∣_    to _∣′_
             )

  open module M₂ {Tok : Set} =
    RawIMonadState (StateTIMonadState (BoundedVec Tok)
                      Data.List.Categorical.monad)
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
  parse↓ n       (_∣_ {true}          p₁ p₂) = parse↓ n       p₁   ∣′       parse↑ n     p₂
  parse↓ n       (_∣_ {false} {true}  p₁ p₂) = parse↑ n       p₁   ∣′       parse↓ n     p₂
  parse↓ n       (_∣_ {false} {false} p₁ p₂) = parse↓ n       p₁   ∣′       parse↓ n     p₂
  parse↓ n       (p₁ ?>>= p₂)                = parse↓ n       p₁ >>=′ λ x → parse↓ n    (p₂ x)
  parse↓ zero    (p₁ !>>= p₂)                = fail′
  parse↓ (suc n) (p₁ !>>= p₂)                = parse↓ (suc n) p₁ >>=′ λ x → parse↑ n (♭ (p₂ x))
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

parse : ∀ {Tok i R} → Parser Tok i R → List Tok → List (R × List Tok)
parse p s = L.map (Prod.map id toList) (parse↓ _ p (fromList s))

-- A variant which only returns parses which leave no remaining input.

parseComplete : ∀ {Tok i R} → Parser Tok i R → List Tok → List R
parseComplete p s =
  L.map proj₁ (L.boolFilter (L.null ∘ proj₂) (parse p s))
