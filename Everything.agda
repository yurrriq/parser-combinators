------------------------------------------------------------------------
-- A total parser combinator library
------------------------------------------------------------------------

module Everything where

-- The parser type, including its semantics.

import StructurallyRecursiveDescentParsing.Type

-- Definition of unambiguity.

import StructurallyRecursiveDescentParsing.Unambiguity

-- Parser type indices, used by the grammars.

import StructurallyRecursiveDescentParsing.Index

-- Grammars.

import StructurallyRecursiveDescentParsing.Grammars

-- A simple backend.

import StructurallyRecursiveDescentParsing.Simple

-- A library of derived parser combinators.

import StructurallyRecursiveDescentParsing.Lib

-- A module which reexports some of the modules above.

import StructurallyRecursiveDescentParsing

-- Some small examples.

import StructurallyRecursiveDescentParsing.Examples

-- An example: parsing PBM image files.

import StructurallyRecursiveDescentParsing.PBM

-- An extended example: mixfix operator parsing.

import StructurallyRecursiveDescentParsing.Mixfix.Fixity
import StructurallyRecursiveDescentParsing.Mixfix.Expr
import StructurallyRecursiveDescentParsing.Mixfix.Lib
import StructurallyRecursiveDescentParsing.Mixfix
import StructurallyRecursiveDescentParsing.Mixfix.Show
import StructurallyRecursiveDescentParsing.Mixfix.Example
