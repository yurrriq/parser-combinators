------------------------------------------------------------------------
-- Linearisation of mixfix operators
------------------------------------------------------------------------

open import Mixfix.Expr

module Mixfix.Cyclic.Show
         (i : PrecedenceGraphInterface)
         (g : PrecedenceGraphInterface.PrecedenceGraph i)
         where

open import Data.Nat using (ℕ; zero; suc; _+_)
open import Data.List using (List)
open import Data.List.Any using (here; there)
open import Data.List.Any.Membership.Propositional using (_∈_)
open import Data.Vec using (Vec; []; _∷_)
open import Data.DifferenceList as DiffList
  using (DiffList; _++_) renaming (_∷_ to cons; [_] to singleton)
open import Data.Product using (∃; _,_; ,_)
open import Function using (_∘_)
open import Relation.Binary.PropositionalEquality
  using (_≡_; refl)

open PrecedenceCorrect i g
open import TotalParserCombinators.Parser
open import TotalParserCombinators.Semantics
open import TotalParserCombinators.Semantics.Continuation as ContSem
open import Mixfix.Fixity
open import Mixfix.Operator
open import Mixfix.Cyclic.Lib as Lib
open Lib.Semantics-⊕
import Mixfix.Cyclic.Grammar
private
  module Grammar = Mixfix.Cyclic.Grammar i g

------------------------------------------------------------------------
-- Linearisation

-- Note: The code assumes that the grammar is unambiguous.

module Show where

  mutual

    expr : ∀ {ps} → Expr ps → DiffList NamePart
    expr (_ ∙ e) = exprIn e

    exprIn : ∀ {p assoc} → ExprIn p assoc → DiffList NamePart
    exprIn    ⟪ op ⟫     =            inner op
    exprIn (l ⟨ op ⟫   ) = outer l ++ inner op
    exprIn (  ⟪ op ⟩  r) =            inner op ++ outer r
    exprIn (l ⟨ op ⟩  r) = expr  l ++ inner op ++ expr  r
    exprIn (l ⟨ op ⟩ˡ r) = outer l ++ inner op ++ expr  r
    exprIn (l ⟨ op ⟩ʳ r) = expr  l ++ inner op ++ outer r

    outer : ∀ {p assoc} → Outer p assoc → DiffList NamePart
    outer (similar e) = exprIn e
    outer (tighter e) = expr   e

    inner : ∀ {fix} {ops : List (∃ (Operator fix))} →
            Inner ops → DiffList NamePart
    inner (_∙_ {op = op} _ args) = inner′ (nameParts op) args

    inner′ : ∀ {arity} →
             Vec NamePart (1 + arity) →
             Vec (Expr anyPrecedence) arity →
             DiffList NamePart
    inner′ (n ∷ []) []           = singleton n
    inner′ (n ∷ ns) (arg ∷ args) = cons n (expr arg ++ inner′ ns args)

show : ∀ {ps} → Expr ps → List NamePart
show = DiffList.toList ∘ Show.expr

------------------------------------------------------------------------
-- Correctness

module Correctness where

  mutual

    expr : ∀ {ps s} (e : Expr ps) →
           e ⊕ s ∈⟦ Grammar.precs ps ⟧· Show.expr e s
    expr (here refl  ∙ e) = ∣ˡ (<$> exprIn e)
    expr (there x∈xs ∙ e) = ∣ʳ (<$> expr (x∈xs ∙ e))

    exprIn : ∀ {p assoc s} (e : ExprIn p assoc) →
             (, e) ⊕ s ∈⟦ Grammar.prec p ⟧· Show.exprIn e s
    exprIn {p} e = exprIn′ _ e
      where
      module N = Grammar.Prec p

      mutual

        outerʳ : ∀ {s} (e : Outer p right) →
                 e ⊕ s ∈⟦ similar <$> N.preRight⁺
                        ∣ tighter <$> N.p↑
                        ⟧· Show.outer e s
        outerʳ (tighter e) = ∣ʳ (<$> expr e)
        outerʳ (similar e) = ∣ˡ (<$> preRight⁺ e)

        preRight⁺ : ∀ {s} (e : ExprIn p right) →
                    e ⊕ s ∈⟦ N.preRight⁺ ⟧· Show.exprIn e s
        preRight⁺ (  ⟪ op ⟩  e) = ∣ˡ (<$>          inner op) ⊛∞ outerʳ e
        preRight⁺ (l ⟨ op ⟩ʳ e) = ∣ʳ (<$> expr l ⊛ inner op) ⊛∞ outerʳ e

      mutual

        outerˡ : ∀ {s} (e : Outer p left) →
                 e ⊕ s ∈⟦ similar <$> N.postLeft⁺
                        ∣ tighter <$> N.p↑
                        ⟧· Show.outer e s
        outerˡ (tighter e) = ∣ʳ (<$> expr e)
        outerˡ (similar e) = ∣ˡ (<$> postLeft⁺ e)

        postLeft⁺ : ∀ {s} (e : ExprIn p left) →
                    e ⊕ s ∈⟦ N.postLeft⁺ ⟧· Show.exprIn e s
        postLeft⁺ (e ⟨ op ⟫   ) = <$> outerˡ e ⊛∞ ∣ˡ (<$> inner op)
        postLeft⁺ (e ⟨ op ⟩ˡ r) = <$> outerˡ e ⊛∞ ∣ʳ (<$> inner op ⊛ expr r)

      exprIn′ : ∀ assoc {s} (e : ExprIn p assoc) →
                (, e) ⊕ s ∈⟦ Grammar.prec p ⟧· Show.exprIn e s
      exprIn′ non      ⟪ op ⟫    = ∥ˡ (<$> inner op)
      exprIn′ non   (l ⟨ op ⟩ r) = ∥ʳ (∥ˡ (<$> expr l ⊛ inner op ⊛∞ expr r))
      exprIn′ right e            = ∥ʳ (∥ʳ (∥ˡ (preRight⁺ e)))
      exprIn′ left  e            = ∥ʳ (∥ʳ (∥ʳ (∥ˡ (postLeft⁺ e))))

    inner : ∀ {fix s ops} (i : Inner {fix} ops) →
            i ⊕ s ∈⟦ Grammar.inner ops ⟧· Show.inner i s
    inner {fix} {s} (_∙_ {arity} {op} op∈ops args) =
      helper op∈ops args
      where
      helper : {ops : List (∃ (Operator fix))}
               (op∈ : (arity , op) ∈ ops)
               (args : Vec (Expr anyPrecedence) arity) →
               let i = op∈ ∙ args in
               i ⊕ s ∈⟦ Grammar.inner ops ⟧· Show.inner i s
      helper (here refl) args = ∣ˡ (<$> inner′ (nameParts op) args)
      helper (there {x = _ , _} op∈) args =
        ∣ʳ (<$> helper op∈ args)

    inner′ : ∀ {arity s} (ns : Vec NamePart (1 + arity)) args →
             args ⊕ s ∈⟦ Grammar.expr between ns ⟧· Show.inner′ ns args s
    inner′ (n ∷ [])      []           = between-[]
    inner′ (n ∷ n′ ∷ ns) (arg ∷ args) =
      between-∷ (expr arg) (inner′ (n′ ∷ ns) args)

-- All generated strings are syntactically correct (but possibly
-- ambiguous). Note that this result implies that all
-- precedence-correct expressions are generated by the grammar.

correct : ∀ e → e ∈ Grammar.expression · show e
correct e = ContSem.sound (Lib.Semantics-⊕.sound (Correctness.expr e))
