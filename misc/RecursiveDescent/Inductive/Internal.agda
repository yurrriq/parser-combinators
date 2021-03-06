------------------------------------------------------------------------
-- A terminating parser data type and the accompanying interpreter
------------------------------------------------------------------------

module RecursiveDescent.Inductive.Internal where

open import Data.Bool
open import Data.Product.Record
open import Data.Maybe
open import Data.BoundedVec.Inefficient
import Data.List as L
open import Data.Nat
open import Category.Applicative.Indexed
open import Category.Monad.Indexed
open import Category.Monad.State

open import RecursiveDescent.Index
open import Utilities

------------------------------------------------------------------------
-- Parser data type

-- A type for parsers which can be implemented using recursive
-- descent. The types used ensure that the implementation below is
-- structurally recursive.

-- The parsers are indexed on a type of nonterminals.

data Parser (tok : Set) (nt : ParserType₁) : ParserType₁ where
  !_     :  forall {e c r}
         -> nt (e , c) r -> Parser tok nt (e , step c) r
  symbol :  Parser tok nt (false , leaf) tok
  ret    :  forall {r} -> r -> Parser tok nt (true , leaf) r
  fail   :  forall {r} -> Parser tok nt (false , leaf) r
  bind₁  :  forall {c₁ e₂ c₂ r₁ r₂}
         -> Parser tok nt (true , c₁) r₁
         -> (r₁ -> Parser tok nt (e₂ , c₂) r₂)
         -> Parser tok nt (e₂ , node c₁ c₂) r₂
  bind₂  :  forall {c₁ r₁ r₂} {i₂ : r₁ -> Index}
         -> Parser tok nt (false , c₁) r₁
         -> ((x : r₁) -> Parser tok nt (i₂ x) r₂)
         -> Parser tok nt (false , step c₁) r₂
  alt    :  forall e₁ e₂ {c₁ c₂ r}
         -> Parser tok nt (e₁      , c₁)         r
         -> Parser tok nt (e₂      , c₂)         r
         -> Parser tok nt (e₁ ∨ e₂ , node c₁ c₂) r

------------------------------------------------------------------------
-- Run function for the parsers

-- Grammars.

Grammar : Set -> ParserType₁ -> Set1
Grammar tok nt = forall {i r} -> nt i r -> Parser tok nt i r

-- Parser monad.

P : Set -> IFun ℕ
P tok = IStateT (BoundedVec tok) L.List

PIMonadPlus : (tok : Set) -> RawIMonadPlus (P tok)
PIMonadPlus tok = StateTIMonadPlus (BoundedVec tok) L.monadPlus

PIMonadState : (tok : Set) -> RawIMonadState (BoundedVec tok) (P tok)
PIMonadState tok = StateTIMonadState (BoundedVec tok) L.monad

private
  open module LM {tok} = RawIMonadPlus  (PIMonadPlus  tok)
  open module SM {tok} = RawIMonadState (PIMonadState tok)
                           using (get; put; modify)

-- For every successful parse the run function returns the remaining
-- string. (Since there can be several successful parses a list of
-- strings is returned.)

-- This function is structurally recursive with respect to the
-- following lexicographic measure:
--
-- 1) The upper bound of the length of the input string.
-- 2) The parser's proper left corner tree.

private

 module Dummy {tok nt} (g : Grammar tok nt) where

  mutual
    parse : forall n {e c r} ->
            Parser tok nt (e , c) r ->
            P tok n (if e then n else pred n) r
    parse n       (! x)                   = parse n (g x)
    parse zero    symbol                  = ∅
    parse (suc n) symbol                  = eat =<< get
    parse n       (ret x)                 = return x
    parse n       fail                    = ∅
    parse n       (bind₁           p₁ p₂) = parse  n      p₁ >>= parse  n ∘′ p₂
    parse zero    (bind₂           p₁ p₂) = ∅
    parse (suc n) (bind₂           p₁ p₂) = parse (suc n) p₁ >>= parse↑ n ∘′ p₂
    parse n       (alt true  _     p₁ p₂) = parse  n      p₁ ∣   parse↑ n    p₂
    parse n       (alt false true  p₁ p₂) = parse↑ n      p₁ ∣   parse  n    p₂
    parse n       (alt false false p₁ p₂) = parse  n      p₁ ∣   parse  n    p₂

    parse↑ : forall n {e c r} -> Parser tok nt (e , c) r -> P tok n n r
    parse↑ n       {true}  p = parse n p
    parse↑ zero    {false} p = ∅
    parse↑ (suc n) {false} p = parse (suc n) p >>= \r ->
                               modify ↑ >>
                               return r

    eat : forall {n} -> BoundedVec tok (suc n) -> P tok (suc n) n tok
    eat []      = ∅
    eat (c ∷ s) = put s >> return c

open Dummy public
