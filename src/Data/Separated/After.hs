{-# language DeriveFunctor, DeriveFoldable, DeriveTraversable, TemplateHaskell #-}
module Data.Separated.After where

import Papa

import Data.Deriving

data After s a = After s a
  deriving (Eq, Ord, Foldable, Functor, Traversable, Show)

deriveEq1 ''After
deriveShow1 ''After
deriveOrd1 ''After
deriveRead1 ''After

instance Bifunctor After where
  bimap f g (After s a) = After (f s) (g a)

after :: Lens (After s a) (After t b) (s, a) (t, b)
after = lens (\(After s a) -> (s, a)) (\After{} (t, b) -> After t b)
