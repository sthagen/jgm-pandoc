{- |
   Module      : Text.Pandoc.Readers.ODT.Generic.Fallible
   Copyright   : Copyright (C) 2015 Martin Linnemann
   License     : GNU GPL, version 2 or above

   Maintainer  : Martin Linnemann <theCodingMarlin@googlemail.com>
   Stability   : alpha
   Portability : portable

Data types and utilities representing failure. Most of it is based on the
"Either" type in its usual configuration (left represents failure).
-}

module Text.Pandoc.Readers.ODT.Generic.Fallible
  ( Failure
  , Fallible
  , chooseMax
  , chooseMaxWith
  ) where

-- | Default for now. Will probably become a class at some point.
type Failure = ()

type Fallible a = Either Failure a

-- | If either of the values represents a  non-error, the result is a
-- (possibly combined) non-error. If both values represent an error, an error
-- is returned.
chooseMax :: (Monoid a, Monoid b) => Either a b -> Either a b -> Either a b
chooseMax = chooseMaxWith mappend

-- | If either of the values represents a non-error, the result is a
-- (possibly combined) non-error. If both values represent an error, an error
-- is returned.
chooseMaxWith :: (Monoid a) => (b -> b -> b)
                            -> Either a b
                            -> Either a b
                            -> Either a b
chooseMaxWith (><) (Right a) (Right b) = Right $ a >< b
chooseMaxWith  _   (Left  a) (Left  b) = Left  $ a `mappend` b
chooseMaxWith  _   (Right a)     _     = Right a
chooseMaxWith  _       _     (Right b) = Right b
