------------------------------------------------------------------------
-- A terminating parser data type and the accompanying interpreter
------------------------------------------------------------------------

-- This code is based on "Parallel Parsing Processes" by Koen
-- Claessen.

-- Note that the type Base.Parser below is assumed to be coinductive.

module CoinductiveParser where

open import CoinductiveParser.Index

import Data.Product as Prod; open Prod using () renaming (_,_ to pair)
open import Data.Bool
open import Data.Nat
open import Data.Product.Record
open import Data.List
open import Category.Monad.State
open import Logic
open import Data.Function

------------------------------------------------------------------------
-- Parser monad

P : Set -> (Set -> Set)
P tok = StateT [ tok ] [_]

------------------------------------------------------------------------
-- Basic parsers (no CPS)

private
 module Base where

  -- returnPlus below takes a _list_ of immediate results, since
  -- otherwise the returnPlus/returnPlus case of _∣'_ would not type
  -- check. (Its type would have to be changed.)

  {- co -}
  data Parser (tok r : Set) : Index -> Set where
    symbolBind : forall {i} ->
                 (tok -> Parser tok r i) -> Parser tok r 0I
    fail       : Parser tok r 0I
    returnPlus : forall {e c} ->
                 [ r ] -> Parser tok r (e , c) ->
                 Parser tok r (true , suc c)

  cast : forall {tok i₁ i₂ r} ->
         i₁ ≡ i₂ -> Parser tok r i₁ -> Parser tok r i₂
  cast ≡-refl p = p

  -- Note that this function is productive.

  _∣_ : forall {tok r i₁ i₂} ->
         Parser tok r i₁ -> Parser tok r i₂ ->
         Parser tok r (i₁ ∣I i₂)
  fail                ∣ p₂                = p₂
  p₁@(returnPlus _ _) ∣ fail              = p₁
  p₁@(symbolBind _)   ∣ fail              = p₁
  symbolBind f₁       ∣ symbolBind f₂     = symbolBind (\c -> f₁ c ∣ f₂ c)
  p₁@(symbolBind _)   ∣ returnPlus xs p₂  = returnPlus xs (p₁ ∣ p₂)
  returnPlus xs p₁    ∣ p₂@(symbolBind _) = returnPlus xs (p₂ ∣ p₁)
  returnPlus xs₁ p₁   ∣ returnPlus xs₂ p₂ = returnPlus (xs₁ ++ xs₂) (p₁ ∣ p₂)

  -- parse is structurally recursive over the following lexicographic
  -- measure:
  --
  -- ⑴ The input string.
  -- ⑵ The Corners index.
  --
  -- Note that Parser is viewed as being coinductive.

  parse : forall {tok r e c} ->
           Parser tok r (e , c) -> P tok r
  parse (symbolBind f)    (c ∷ s) = parse (f c) s
  parse (symbolBind f)    []      = []
  parse fail              _       = []
  parse (returnPlus xs p) s       = map (\x -> pair x s) xs ++ parse p s

------------------------------------------------------------------------
-- CPS transformation

-- The code below manually applies the continuation-passing monad
-- transformer to the Base parser above to improve the efficiency of
-- left-nested uses of bind.

Parser : Set -> Set -> Index -> Set1
Parser tok r i = forall {r' i'} ->
                 (r -> Base.Parser tok r' i') ->
                 Base.Parser tok r' (i ·I i')

symbol : forall {tok} -> Parser tok tok 0I
symbol = Base.symbolBind

fail : forall {tok r} -> Parser tok r 0I
fail = \k -> Base.fail

return : forall {tok r} -> r -> Parser tok r 1I
return x = \k -> k x

_>>=_ : forall {tok r₁ r₂ i₁ i₂} ->
        Parser tok r₁ i₁ -> (r₁ -> Parser tok r₂ i₂) ->
        Parser tok r₂ (i₁ ·I i₂)
_>>=_ {i₁ = i₁} {i₂ = i₂} p f {i' = i₃} k =
  Base.cast (sym $ *-assoc i₁ i₂ i₃) (p \x -> f x k)
  where open IndexSemiring

_∣_ : forall {tok r i₁ i₂} ->
      Parser tok r i₁ ->
      Parser tok r i₂ ->
      Parser tok r (i₁ ∣I i₂)
_∣_ {i₁ = i₁} {i₂ = i₂} p₁ p₂ {i' = i₃} k =
  Base.cast (sym $ Prod.proj₂ distrib i₃ i₁ i₂)
            (Base._∣_ (p₁ k) (p₂ k))
  where open IndexSemiring

parse : forall {tok r i} ->
        Parser tok r i -> P tok r
parse {tok} {r} p = Base.parse (p k)
  where
  k : r -> Base.Parser tok r (true , 1)
  k x = Base.returnPlus (x ∷ []) Base.fail
