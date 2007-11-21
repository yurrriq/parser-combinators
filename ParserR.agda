------------------------------------------------------------------------
-- Terminating parsers
------------------------------------------------------------------------

-- A DSEL for parsers which can be implemented using recursive
-- descent. The types used ensure that these implementations will
-- always terminate.

module ParserR where

open import Data.Bool
open import Data.Product
open import Data.Function
open import Data.BoundedVec
import Data.List as L
open import Data.Nat
open import Logic
open import Monad
open import Monad.Indexed
open import Monad.State
open import Relation.Nullary
open import Relation.Binary

------------------------------------------------------------------------
-- Indices to the parser type

-- Does the parser accept empty strings?

Empty : Set
Empty = Bool

-- The spine of the parser, except that the right argument of _·_ is
-- omitted if the left one does not accept empty strings. (This is
-- encoded using maybeNode.)

data Depth : Set where
  leaf : Depth
  step : Depth -> Depth
  node : Depth -> Depth -> Depth

------------------------------------------------------------------------
-- Parsers

-- Parsers, indexed on a type of names.

infix  60 !_
infixr 50 _·₀_ _·₁_ _·_
infixr 40 _∣₀_ _∣₁_ _∣_

ParserType : Set2
ParserType = Empty -> Depth -> Set -> Set1

data Parser (tok : Set) (name : ParserType) : ParserType where
  fail  :  forall {r} -> Parser tok name false leaf r
  ret   :  forall {r} -> r -> Parser tok name true  leaf r
  sym   :  (tok -> Bool) -> Parser tok name false leaf tok
  _·₀_  :  forall {d₁ e₂ d₂ r₁ r₂}
        -> Parser tok name true d₁ (r₁ -> r₂) -> Parser tok name e₂ d₂ r₁
        -> Parser tok name e₂ (node d₁ d₂) r₂
  _·₁_  :  forall {d₁ e₂ d₂ r₁ r₂}
        -> Parser tok name false d₁ (r₁ -> r₂) -> Parser tok name e₂ d₂ r₁
        -> Parser tok name false (step d₁) r₂
  _∣₀_  :  forall {d₁ e₂ d₂ r}
        -> Parser tok name true d₁ r -> Parser tok name e₂ d₂ r
        -> Parser tok name true (node d₁ d₂) r
  _∣₁_  :  forall {d₁ e₂ d₂ r}
        -> Parser tok name false d₁ r -> Parser tok name e₂ d₂ r
        -> Parser tok name e₂ (node d₁ d₂) r
  !_    :  forall {e d r}
        -> name e d r -> Parser tok name e (step d) r
  bind₀ :  forall {d₁ e₂ d₂ r₁ r₂}
        -> Parser tok name true d₁ r₁ -> (r₁ -> Parser tok name e₂ d₂ r₂)
        -> Parser tok name e₂ (node d₁ d₂) r₂
  bind₁ :  forall {d₁ e₂ d₂ r₁ r₂}
        -> Parser tok name false d₁ r₁ -> (r₁ -> Parser tok name e₂ d₂ r₂)
        -> Parser tok name false (step d₁) r₂

_·_ : forall {tok name e₁ d₁ e₂ d₂ r₁ r₂} ->
      Parser tok name e₁ d₁ (r₁ -> r₂) -> Parser tok name e₂ d₂ r₁ ->
      Parser tok name (e₁ ∧ e₂) (if e₁ then node d₁ d₂ else step d₁) r₂
_·_ {e₁ = true } = _·₀_
_·_ {e₁ = false} = _·₁_

_∣_ : forall {tok name e₁ d₁ e₂ d₂ r} ->
      Parser tok name e₁ d₁ r -> Parser tok name e₂ d₂ r ->
      Parser tok name (e₁ ∨ e₂) (node d₁ d₂) r
_∣_ {e₁ = true } = _∣₀_
_∣_ {e₁ = false} = _∣₁_


------------------------------------------------------------------------
-- Renaming parsers

-- Is this useful?

{-
rename :  forall {tok name₁ name₂}
       -> (forall {e d r} -> name₁ e d r -> name₂ e d r)
       -> forall {e d r} -> Parser tok name₁ e d r -> Parser tok name₂ e d r
rename f fail      = fail
rename f (ret x)   = ret x
rename f (sym p)   = sym p
rename f (p₁ ·₀ p₂) = rename f p₁ ·₀ rename f p₂
rename f (p₁ ·₁ p₂) = rename f p₁ ·₁ rename f p₂
rename f (p₁ ∣₀ p₂) = rename f p₁ ∣₀ rename f p₂
rename f (p₁ ∣₁ p₂) = rename f p₁ ∣₁ rename f p₂
rename f (! x)     = ! f x
-}

------------------------------------------------------------------------
-- Some derived parsers

module Token (a : DecSetoid) where

  private
    open module D = DecSetoid a
    open module S = Setoid setoid renaming (carrier to tok)

  -- Parses a given token.

  token : forall {name} -> tok -> Parser tok name false leaf tok
  token x = sym p
    where
    p : tok -> Bool
    p y with x ≟ y
    ... | yes _ = true
    ... | no  _ = false

------------------------------------------------------------------------
-- Run function for the parsers

-- Grammars.

Grammar : Set -> ParserType -> Set1
Grammar tok name = forall {e d r} -> name e d r -> Parser tok name e d r

-- Parser monad.

P : Set -> ℕ -> ℕ -> Set -> Set
P tok = IStateT (BoundedVec tok) L.[_]

PIMonadPlus : (tok : Set) -> RawIMonadPlus (P tok)
PIMonadPlus tok = StateTIMonadPlus (BoundedVec tok) L.ListMonadPlus

PIMonadState : (tok : Set) -> RawIMonadState (BoundedVec tok) (P tok) 
PIMonadState tok = StateTIMonadState (BoundedVec tok) L.ListMonad

private
  open module LM {tok : Set} = IMonadPlusOps _ (PIMonadPlus tok)
  open module SM {tok : Set} = IMonadStateOps  (PIMonadState tok)


-- For every successful parse the run function returns the remaining
-- string. (Since there can be several successful parses a list of
-- strings is returned.)

-- This function is structurally recursive with respect to the
-- following lexicographic measure:
--
-- 1) The upper bound of the input string.
-- 2) The depth of the parser.

private

  maybeSuc : Empty -> ℕ -> ℕ
  maybeSuc e = if e then suc else id

  ⟦_⟧' :  forall {tok name e d r}
       -> Parser tok name e d r -> Grammar tok name
       -> forall {n}
       -> P tok (suc n) (maybeSuc e n) r
  ⟦_⟧' {tok = tok} {name = name} {e = e} p g = parse _ p _
    where
    mutual
      parse₀ : forall d {r} ->
               Parser tok name true d r -> (n : ℕ) ->
               P tok n n r
      parse₀ leaf       (ret x)                   n = return x
      parse₀ (node _ _) (p₁ ·₀ p₂)                n = parse₀ _ p₁ n <*> parse₀ _ p₂ n
      parse₀ (node _ _) (_∣₀_ {e₂ = true } p₁ p₂) n = parse₀ _ p₁ n ++  parse₀ _ p₂ n
      parse₀ (node _ _) (_∣₀_ {e₂ = false} p₁ p₂) n = parse₀ _ p₁ n ++  parse₁↑  p₂ n
      parse₀ (node _ _) (p₁ ∣₁ p₂)                n = parse₁↑  p₁ n ++  parse₀ _ p₂ n
      parse₀ (step _)   (! x)                     n = parse₀ _ (g x) n

      parse₁↑ : forall {d r} -> Parser tok name false d r -> (n : ℕ) ->
                P tok n n r
      parse₁↑ p zero    = mzero
      parse₁↑ p (suc n) = parse₁ _ p (suc n) >>= \r -> modify ↑ >> return r

      parse₁ : forall d {r} ->
               Parser tok name false d r -> (n : ℕ) ->
               P tok n (pred n) r
      parse₁ _          _                         zero     = mzero
      parse₁ leaf       fail                      (suc n)  = mzero
      parse₁ leaf       (sym p)                   (suc n)  = eat =<< get
        where
          eat : forall {n} -> BoundedVec tok (suc n) -> P tok (suc n) n tok
          eat []      = mzero
          eat (c ∷ s) with p c
          ... | true  = put s >> return c
          ... | false = mzero
      parse₁ (node _ _) (p₁ ·₀ p₂)                (suc n) = parse₀ _ p₁ (suc n) <*> parse₁ _ p₂ (suc n)
      parse₁ (node _ _) (bind₀ p₁ p₂)             (suc n) = parse₀ _ p₁ (suc n) >>= \x -> parse₁ _ (p₂ x) (suc n)
      parse₁ (step _)   (_·₁_ {e₂ = true } p₁ p₂) (suc n) = parse₁ _ p₁ (suc n) <*> parse₀ _ p₂ n
      parse₁ (step _)   (_·₁_ {e₂ = false} p₁ p₂) (suc n) = parse₁ _ p₁ (suc n) <*> parse₁↑  p₂ n
      parse₁ (step _)   (bind₁ {e₂ = true } p₁ p₂)(suc n) = parse₁ _ p₁ (suc n) >>= \x -> parse₀ _ (p₂ x) n
      parse₁ (step _)   (bind₁ {e₂ = false} p₁ p₂)(suc n) = parse₁ _ p₁ (suc n) >>= \x -> parse₁↑  (p₂ x) n
      parse₁ (node _ _) (p₁ ∣₁ p₂)                (suc n) = parse₁ _ p₁ (suc n) ++  parse₁ _ p₂ (suc n)
      parse₁ (step _)   (! x)                     (suc n) = parse₁ _ (g x) (suc n)

    parse : forall e {d r} ->
            Parser tok name e d r -> (n : ℕ) ->
            P tok (suc n) (maybeSuc e n) r
    parse true  p n = parse₀ _ p (suc n)
    parse false p n = parse₁ _ p (suc n)

open L

⟦_⟧ :  forall {tok name e d r}
    -> Parser tok name e d r -> Grammar tok name
    -> [ tok ] -> [ r × [ tok ] ]
⟦ p ⟧ g s = map (map-× id toList) (⟦ p ⟧' g (↑ (fromList s)))

