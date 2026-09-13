{-# LANGUAGE FlexibleInstances #-}
{- |
   Module      : Text.Pandoc.TeX
   Copyright   : Copyright (C) 2017-2024 John MacFarlane
   License     : GNU GPL, version 2 or above

   Maintainer  : John MacFarlane <jgm@berkeley.edu>
   Stability   : alpha
   Portability : portable

Types for TeX tokens and macros.
-}
module Text.Pandoc.TeX ( Tok(..)
                       , TokType(..)
                       , Macro(..)
                       , ArgSpec(..)
                       , ExpansionPoint(..)
                       , MacroScope(..)
                       , SourcePos
                       )
where
import Data.Text (Text)
import Text.Parsec (SourcePos, sourceName)
import Text.Pandoc.Sources
import Data.List (groupBy)

data TokType = CtrlSeq Text | Spaces | Newline | Symbol | Word | Comment |
               Esc1    | Esc2   | Arg Int  | DeferredArg Int
     deriving (Eq, Ord, Show)

data Tok = Tok SourcePos TokType Text
     deriving (Eq, Ord, Show)

instance ToSources [Tok] where
  toSources = Sources
    . map (\ts -> case ts of
                    Tok p _ _ : _ -> (p, mconcat $ map tokToText ts)
                    _ -> error "toSources [Tok] encountered empty group")
    . groupBy (\(Tok p1 _ _) (Tok p2 _ _) -> sourceName p1 == sourceName p2)

tokToText :: Tok -> Text
tokToText (Tok _ _ t) = t

data ExpansionPoint = ExpandWhenDefined | ExpandWhenUsed
     deriving (Eq, Ord, Show)

data MacroScope = GlobalScope | GroupScope
  deriving (Eq, Ord, Show)

data Macro = Macro MacroScope ExpansionPoint [ArgSpec] (Maybe [Tok]) [Tok]
     deriving Show

data ArgSpec = ArgNum Int
             | Pattern [Tok]
             | BoolArg Bool Tok
               -- ^ xparse @s@ and @t@ specifiers: an optional token
               -- (e.g. a star); expands to @\\BooleanTrue@ or
               -- @\\BooleanFalse@.  The Bool is False if the @!@
               -- modifier was used (no space-skipping before the
               -- token).
             | DelimArg Bool Tok Tok (Maybe [Tok])
               -- ^ xparse @o@, @O@, @d@, @D@, @r@, @R@ specifiers:
               -- argument between opening and closing delimiter
               -- tokens, with an optional default; when absent and
               -- no default is given, expands to @\\NoValue@.  The
               -- Bool is False if the @!@ modifier was used (no
               -- space-skipping before the opening delimiter).
             | VerbArg
               -- ^ xparse @v@ specifier: a verbatim argument, either
               -- braced or between two identical delimiter
               -- characters; substituted as a single Word token
               -- containing the raw text.
             | EmbellishArg [(Tok, Maybe [Tok])]
               -- ^ xparse @e@ and @E@ specifiers: a set of optional
               -- \"embellishments\" (a token followed by an
               -- argument), matched in any order, each with an
               -- optional default; a missing embellishment expands
               -- to its default, or to @\\NoValue@.
             | ProcessedArg [[Tok]] ArgSpec
               -- ^ xparse @>{processor}@ modifier: the processors
               -- are applied to the grabbed argument from right to
               -- left (i.e., the one nearest the specifier first).
             | BodyArg Bool Int
               -- ^ xparse @b@ specifier (environments only): the
               -- environment body, grabbed up to the following
               -- 'Pattern' (the @\\end{...}@).  The Bool is False if
               -- the @!@ modifier was used (no space-trimming at the
               -- ends of the body).
             | VerbBodyArg Bool Int
               -- ^ xparse @c@ specifier (environments only): the
               -- environment body, grabbed verbatim up to the
               -- following 'Pattern' (the @\\end{...}@); substituted
               -- as one raw Word token per line, with spaces
               -- replaced by U+2423 and lines separated by @\\\\@,
               -- mirroring how LaTeX typesets it.  The Bool is
               -- False if the @!@ modifier was used (no trimming of
               -- leading and trailing blank lines).
     deriving Show
