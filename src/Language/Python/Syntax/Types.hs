{-# language DataKinds #-}
{-# language DeriveFunctor, DeriveFoldable, DeriveTraversable, DeriveGeneric #-}
{-# language InstanceSigs, ScopedTypeVariables, TypeApplications #-}
{-# language KindSignatures #-}
{-# language TemplateHaskell #-}

{-|
Module      : Language.Python.Syntax.Types
Copyright   : (C) CSIRO 2017-2019
License     : BSD3
Maintainer  : Isaac Elliott <isaace71295@gmail.com>
Stability   : experimental
Portability : non-portable

Datatypes for different parts of Python syntax
-}

module Language.Python.Syntax.Types
  ( -- * Parameters
    -- ** Positional parameters
    PositionalParam(..)
    -- *** Lenses
  , ppAnn
  , ppName
  , ppType
    -- ** Starred Parameters
  , StarParam(..)
    -- *** Lenses
  , spAnn
  , spWhitespace
  , spName
  , spType
    -- ** Unnamed Starred Parameters
  , UnnamedStarParam(..)
    -- *** Lenses
  , uspAnn
  , uspWhitespace
    -- ** Keyword parameters
  , KeywordParam(..)
    -- *** Lenses
  , kpAnn
  , kpName
  , kpType
  , kpEquals
  , kpExpr
    -- * Compound statements
    -- ** Function definitions
  , Fundef(..)
    -- *** Lenses
  , fdAnn
  , fdDecorators
  , fdIndents
  , fdAsync
  , fdDefSpaces
  , fdName
  , fdLeftParenSpaces
  , fdParameters
  , fdRightParenSpaces
  , fdReturnType
  , fdBody
    -- ** Class definitions
  , ClassDef(..)
    -- *** Lenses
  , cdAnn
  , cdDecorators
  , cdIndents
  , cdClass
  , cdName
  , cdArguments
  , cdBody
    -- ** @if@ statements
  , If(..)
    -- *** Lenses
  , ifAnn
  , ifIndents
  , ifIf
  , ifCond
  , ifBody
  , ifElifs
  , ifElse
    -- ** @elif@
  , Elif(..)
    -- *** Lenses
  , elifIndents
  , elifElif
  , elifCond
  , elifBody
    -- ** @for@ statements
  , For(..)
    -- *** Lenses
  , forAnn
  , forIndents
  , forAsync
  , forFor
  , forBinder
  , forIn
  , forCollection
  , forBody
  , forElse
    -- ** @while@ statements
  , While(..)
    -- *** Lenses
  , whileAnn
  , whileIndents
  , whileWhile
  , whileCond
  , whileBody
  , whileElse
    -- ** @try ... except ... else ... finally@
  , TryExcept(..)
    -- *** Lenses
  , teAnn
  , teIndents
  , teTry
  , teBody
  , teExcepts
  , teElse
  , teFinally
    -- *** @except@
  , Except(..)
    -- **** Lenses
  , exceptIndents
  , exceptExcept
  , exceptExceptAs
  , exceptBody
    -- ** @try ... finally@
  , TryFinally(..)
    -- *** Lenses
  , tfAnn
  , tfIndents
  , tfTry
  , tfBody
  , tfFinally
    -- ** @finally@
  , Finally(..)
    -- *** Lenses
  , finallyIndents
  , finallyFinally
  , finallyBody
    -- ** @with@ statements
  , With(..)
    -- *** Lenses
  , withAnn
  , withIndents
  , withAsync
  , withWith
  , withItems
  , withBody
    -- ** @else@
  , Else(..)
    -- *** Lenses
  , elseIndents
  , elseElse
  , elseBody
  )
where

import Control.Lens.Lens (Lens')
import Control.Lens.TH (makeLenses)
import Data.Generics.Product.Typed (typed)
import Data.List.NonEmpty (NonEmpty)
import GHC.Generics (Generic)

import Data.VIdentity
import Language.Python.Syntax.Ann
import Language.Python.Syntax.CommaSep
import Language.Python.Syntax.Ident
import Language.Python.Syntax.Numbers
import Language.Python.Syntax.Operator.Binary
import Language.Python.Syntax.Operator.Unary
import Language.Python.Syntax.Punctuation
import Language.Python.Syntax.Statement
import Language.Python.Syntax.Strings
import Language.Python.Syntax.Whitespace

data Fundef v a
  = MkFundef
  { _fdAnn :: Ann a
  , _fdDecorators :: [Decorator v a]
  , _fdIndents :: Indents a
  , _fdAsync :: Maybe (NonEmpty Whitespace)
  , _fdDefSpaces :: NonEmpty Whitespace
  , _fdName :: Ident v a
  , _fdLeftParenSpaces :: [Whitespace]
  , _fdParameters :: CommaSep (Param Expr v a)
  , _fdRightParenSpaces :: [Whitespace]
  , _fdReturnType :: Maybe ([Whitespace], Expr v a)
  , _fdBody :: Suite v a
  } deriving (Eq, Show, Functor, Foldable, Traversable, Generic)
makeLenses ''Fundef

instance HasAnn (Fundef v) where
  annot :: forall a. Lens' (Fundef v a) (Ann a)
  annot = typed @(Ann a)

data Else v a
  = MkElse
  { _elseIndents :: Indents a
  , _elseElse :: [Whitespace]
  , _elseBody :: Suite v a
  } deriving (Eq, Show, Functor, Foldable, Traversable, Generic)
makeLenses ''Else

data While v a
  = MkWhile
  { _whileAnn :: Ann a
  , _whileIndents :: Indents a
  , _whileWhile :: [Whitespace]
  , _whileCond :: Expr v a
  , _whileBody :: Suite v a
  , _whileElse :: Maybe (Else v a)
  } deriving (Eq, Show, Functor, Foldable, Traversable, Generic)
makeLenses ''While

instance HasAnn (While v) where
  annot :: forall a. Lens' (While v a) (Ann a)
  annot = typed @(Ann a)

data KeywordParam expr v a
  = MkKeywordParam
  { _kpAnn :: Ann a
  , _kpName :: Ident v a
  , _kpType :: Maybe (Colon, expr v a)
  , _kpEquals :: [Whitespace]
  , _kpExpr :: expr v a
  } deriving (Eq, Show, Functor, Foldable, Traversable, Generic)
makeLenses ''KeywordParam

instance HasAnn (KeywordParam expr v) where
  annot :: forall a. Lens' (KeywordParam expr v a) (Ann a)
  annot = typed @(Ann a)

data PositionalParam expr v a
  = MkPositionalParam
  { _ppAnn :: Ann a
  , _ppName :: Ident v a
  , _ppType :: Maybe (Colon, expr v a)
  } deriving (Eq, Show, Functor, Foldable, Traversable, Generic)
makeLenses ''PositionalParam

instance HasAnn (PositionalParam expr v) where
  annot :: forall a. Lens' (PositionalParam expr v a) (Ann a)
  annot = typed @(Ann a)

data StarParam expr v a
  = MkStarParam
  { _spAnn :: Ann a
  , _spWhitespace :: [Whitespace]
  , _spName :: Ident v a
  , _spType :: Maybe (Colon, expr v a)
  } deriving (Eq, Show, Functor, Foldable, Traversable, Generic)
makeLenses ''StarParam

instance HasAnn (StarParam expr v) where
  annot :: forall a. Lens' (StarParam expr v a) (Ann a)
  annot = typed @(Ann a)

data UnnamedStarParam (v :: [*]) a
  = MkUnnamedStarParam
  { _uspAnn :: Ann a
  , _uspWhitespace :: [Whitespace]
  } deriving (Eq, Show, Functor, Foldable, Traversable, Generic)
makeLenses ''UnnamedStarParam

instance HasAnn (UnnamedStarParam v) where
  annot :: forall a. Lens' (UnnamedStarParam v a) (Ann a)
  annot = typed @(Ann a)

data Elif v a
  = MkElif
  { _elifIndents :: Indents a
  , _elifElif :: [Whitespace]
  , _elifCond :: Expr v a
  , _elifBody :: Suite v a
  } deriving (Eq, Show, Functor, Foldable, Traversable, Generic)
makeLenses ''Elif

data If v a
  = MkIf
  { _ifAnn :: Ann a
  , _ifIndents :: Indents a
  , _ifIf :: [Whitespace]
  , _ifCond :: Expr v a
  , _ifBody :: Suite v a
  , _ifElifs :: [Elif v a]
  , _ifElse :: Maybe (Else v a)
  } deriving (Eq, Show, Functor, Foldable, Traversable, Generic)
makeLenses ''If

instance HasAnn (If v) where
  annot :: forall a. Lens' (If v a) (Ann a)
  annot = typed @(Ann a)

data For v a
  = MkFor
  { _forAnn :: Ann a
  , _forIndents :: Indents a
  , _forAsync :: Maybe (NonEmpty Whitespace)
  , _forFor :: [Whitespace]
  , _forBinder :: Expr v a
  , _forIn :: [Whitespace]
  , _forCollection :: CommaSep1' (Expr v a)
  , _forBody :: Suite v a
  , _forElse :: Maybe (Else v a)
  } deriving (Eq, Show, Functor, Foldable, Traversable, Generic)
makeLenses ''For

instance HasAnn (For v) where
  annot :: forall a. Lens' (For v a) (Ann a)
  annot = typed @(Ann a)

data Finally v a
  = MkFinally
  { _finallyIndents :: Indents a
  , _finallyFinally :: [Whitespace]
  , _finallyBody :: Suite v a
  } deriving (Eq, Show, Functor, Foldable, Traversable, Generic)
makeLenses ''Finally

data Except v a
  = MkExcept
  { _exceptIndents :: Indents a
  , _exceptExcept :: [Whitespace]
  , _exceptExceptAs :: Maybe (ExceptAs v a)
  , _exceptBody :: Suite v a
  } deriving (Eq, Show, Functor, Foldable, Traversable, Generic)
makeLenses ''Except

data TryExcept v a
  = MkTryExcept
  { _teAnn :: Ann a
  , _teIndents :: Indents a
  , _teTry :: [Whitespace]
  , _teBody :: Suite v a
  , _teExcepts :: NonEmpty (Except v a)
  , _teElse :: Maybe (Else v a)
  , _teFinally :: Maybe (Finally v a)
  } deriving (Eq, Show, Functor, Foldable, Traversable, Generic)
makeLenses ''TryExcept

instance HasAnn (TryExcept v) where
  annot :: forall a. Lens' (TryExcept v a) (Ann a)
  annot = typed @(Ann a)

data TryFinally v a
  = MkTryFinally
  { _tfAnn :: Ann a
  , _tfIndents :: Indents a
  , _tfTry :: [Whitespace]
  , _tfBody :: Suite v a
  , _tfFinally :: Finally v a
  } deriving (Eq, Show, Functor, Foldable, Traversable, Generic)
makeLenses ''TryFinally

instance HasAnn (TryFinally v) where
  annot :: forall a. Lens' (TryFinally v a) (Ann a)
  annot = typed @(Ann a)

data ClassDef v a
  = MkClassDef
  { _cdAnn :: Ann a
  , _cdDecorators :: [Decorator v a]
  , _cdIndents :: Indents a
  , _cdClass :: NonEmpty Whitespace
  , _cdName :: Ident v a
  , _cdArguments :: Maybe ([Whitespace], Maybe (CommaSep1' (Arg Expr v a)), [Whitespace])
  , _cdBody :: Suite v a
  } deriving (Eq, Show, Functor, Foldable, Traversable, Generic)
makeLenses ''ClassDef

instance HasAnn (ClassDef v) where
  annot :: forall a. Lens' (ClassDef v a) (Ann a)
  annot = typed @(Ann a)

data With v a
  = MkWith
  { _withAnn :: Ann a
  , _withIndents :: Indents a
  , _withAsync :: Maybe (NonEmpty Whitespace)
  , _withWith :: [Whitespace]
  , _withItems :: CommaSep1 (WithItem v a)
  , _withBody :: Suite v a
  } deriving (Eq, Show, Functor, Foldable, Traversable, Generic)
makeLenses ''With

instance HasAnn (With v) where
  annot :: forall a. Lens' (With v a) (Ann a)
  annot = typed @(Ann a)
