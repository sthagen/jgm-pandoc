{-# LANGUAGE ViewPatterns  #-}
{- |
   Module      : Text.Pandoc.Reader.ODT.Generic.Utils
   Copyright   : Copyright (C) 2015 Martin Linnemann
   License     : GNU GPL, version 2 or above

   Maintainer  : Martin Linnemann <theCodingMarlin@googlemail.com>
   Stability   : alpha
   Portability : portable

General utility functions for the odt reader.
-}

module Text.Pandoc.Readers.ODT.Generic.Utils
( tryToRead
, Lookupable(..)
, readLookupable
, readPercent
, findBy
) where

import Data.Char (isSpace)
import Data.Maybe
import Data.Text (Text)
import qualified Data.Text as T

-- | Alternative to 'read'/'reads'. The former of these throws errors
-- (nobody wants that) while the latter returns "to much" for simple purposes.
-- This function instead applies 'reads' and returns the first match (if any)
-- in a 'Maybe'.
tryToRead :: (Read r) => Text -> Maybe r
tryToRead = fmap fst . listToMaybe . reads . T.unpack

-- | A version of 'reads' that requires a '%' sign after the number
readPercent :: ReadS Int
readPercent s = [ (i,s') | (i   , r ) <- reads s
                         , ("%" , s') <- lex   r
              ]

-- | Data that can be looked up.
-- This is mostly a utility to read data with kind *.
class Lookupable a where
  lookupTable :: [(Text, a)]

-- | Very similar to a simple 'lookup' in the 'lookupTable', but with a lexer.
readLookupable :: (Lookupable a) => Text -> Maybe a
readLookupable s =
  lookup (T.takeWhile (not . isSpace) $ T.dropWhile isSpace s) lookupTable

-- | A version of "Data.List.find" that uses a converter to a Maybe instance.
-- The returned value is the first which the converter returns in a 'Just'
-- wrapper.
findBy :: (a -> Maybe b) -> [a] -> Maybe b
findBy _               []   = Nothing
findBy f ((f -> Just x):_ ) = Just x
findBy f (            _:xs) = findBy f xs
