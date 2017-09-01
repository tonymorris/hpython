{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TemplateHaskell #-}
module Language.Python.Parser.IR.Checker where

import Control.Monad.Writer
import Data.Functor.Compose
import Data.Functor.Sum
import Data.Validation
import Papa

import qualified Data.DList as D

import Language.Python.Parser.SrcInfo

import qualified Language.Python.AST as Safe
import qualified Language.Python.Parser.IR as IR

data SyntaxError a
  = forall f. CannotAssignTo (f a) a
  | AwaitNotInAsyncFunction a

data SyntaxConfig atomType ctxt
  = SyntaxConfig
  { _atomType :: Safe.SAtomType atomType
  , _exprContext :: Safe.SExprContext ctxt
  }
makeLenses ''SyntaxConfig

newtype SyntaxChecker ann a
  = SyntaxChecker
  { runSyntaxChecker :: AccValidation (D.DList (SyntaxError ann)) a
  } deriving
  ( Functor
  , Applicative
  )

syntaxError :: SyntaxError ann -> SyntaxChecker ann a
syntaxError = SyntaxChecker . AccFailure . D.singleton

traverseCompose
  :: Traversable f
  => Traversal (Compose f g a) (Compose f g' a') (g a) (g' a')
traverseCompose = _Wrapping Compose . traverse

checkTest
  :: SyntaxConfig atomType ctxt
  -> IR.Test ann
  -> SyntaxChecker ann (Safe.Test atomType ctxt ann)
checkTest cfg e =
  case cfg ^. atomType of
    Safe.SAssignable ->
      case e of
        IR.TestCondNoIf v ann ->
          Safe.TestCondNoIf <$>
          checkOrTest cfg v <*>
          pure ann
        IR.TestCondIf _ _ ann -> syntaxError $ CannotAssignTo e ann
    Safe.SNotAssignable ->
      case e of
        IR.TestCondNoIf v ann ->
          Safe.TestCondNoIf <$>
          checkOrTest cfg v <*>
          pure ann
        IR.TestCondIf h t ann ->
          Safe.TestCondIf <$>
          checkOrTest cfg h <*>
          traverseOf traverseCompose (checkIfThenElse cfg) t <*>
          pure ann

checkIfThenElse
  :: SyntaxConfig atomType ctxt
  -> IR.IfThenElse ann
  -> SyntaxChecker ann (Safe.IfThenElse 'Safe.NotAssignable ctxt ann)
checkIfThenElse cfg (IR.IfThenElse i e) =
  Safe.IfThenElse <$>
  traverseOf
    traverseCompose
    (checkOrTest $ set atomType Safe.SNotAssignable cfg) i <*>
  traverseOf
    traverseCompose
    (checkTest $ set atomType Safe.SNotAssignable cfg) e

checkOrTest
  :: SyntaxConfig atomType ctxt
  -> IR.OrTest ann
  -> SyntaxChecker ann (Safe.OrTest atomType ctxt ann)
checkOrTest cfg e =
  case cfg ^. atomType of
    Safe.SAssignable ->
      case e of
        IR.OrTestOne val ann ->
          Safe.OrTestOne <$>
          checkAndTest cfg val <*>
          pure ann
        IR.OrTestMany l r ann ->
          syntaxError $ CannotAssignTo e ann
    Safe.SNotAssignable ->
      case e of
        IR.OrTestOne val ann ->
          Safe.OrTestOne <$>
          checkAndTest cfg val <*>
          pure ann
        IR.OrTestMany l r ann ->
          Safe.OrTestMany <$>
          checkAndTest cfg l <*>
          traverseOf
            (traverseCompose.traverseCompose)
            (checkAndTest cfg) r <*>
          pure ann

checkAndTest
  :: SyntaxConfig atomType ctxt
  -> IR.AndTest ann
  -> SyntaxChecker ann (Safe.AndTest atomType ctxt ann)
checkAndTest cfg e =
  case cfg ^. atomType of
    Safe.SAssignable ->
      case e of
        IR.AndTestOne val ann ->
          Safe.AndTestOne <$>
          checkNotTest cfg val <*>
          pure ann
        IR.AndTestMany l r ann ->
          syntaxError $ CannotAssignTo e ann
    Safe.SNotAssignable ->
      case e of
        IR.AndTestOne val ann ->
          Safe.AndTestOne <$>
          checkNotTest cfg val <*>
          pure ann
        IR.AndTestMany l r ann ->
          Safe.AndTestMany <$>
          checkNotTest cfg l <*>
          traverseOf
            (traverseCompose.traverseCompose)
            (checkAndTest cfg) r <*>
          pure ann

checkNotTest
  :: SyntaxConfig atomType ctxt
  -> IR.NotTest ann
  -> SyntaxChecker ann (Safe.NotTest atomType ctxt ann)
checkNotTest cfg e =
  case cfg ^. atomType of
    Safe.SAssignable ->
      case e of
        IR.NotTestOne val ann ->
          Safe.NotTestOne <$>
          checkComparison cfg val <*>
          pure ann
        IR.NotTestMany val ann ->
          syntaxError $ CannotAssignTo e ann
    Safe.SNotAssignable ->
      case e of
        IR.NotTestOne val ann ->
          Safe.NotTestOne <$>
          checkComparison cfg val <*>
          pure ann
        IR.NotTestMany val ann ->
          Safe.NotTestMany <$>
          traverseOf
            traverseCompose
            (checkNotTest cfg) val <*>
          pure ann

checkComparison
  :: SyntaxConfig atomType ctxt
  -> IR.Comparison ann
  -> SyntaxChecker ann (Safe.Comparison atomType ctxt ann)
checkComparison cfg e =
  case cfg ^. atomType of
    Safe.SAssignable ->
      case e of
        IR.ComparisonOne val ann ->
          Safe.ComparisonOne <$>
          checkExpr cfg val <*>
          pure ann
        IR.ComparisonMany l r ann ->
          syntaxError $ CannotAssignTo e ann
    Safe.SNotAssignable ->
      case e of
        IR.ComparisonOne val ann ->
          Safe.ComparisonOne <$>
          checkExpr cfg val <*>
          pure ann
        IR.ComparisonMany l r ann ->
          Safe.ComparisonMany <$>
          checkExpr cfg l <*>
          traverseOf
            (traverseCompose.traverseCompose)
            (checkExpr cfg) r <*>
          pure ann

checkExpr
  :: SyntaxConfig atomType ctxt
  -> IR.Expr ann
  -> SyntaxChecker ann (Safe.Expr atomType ctxt ann)
checkExpr cfg e =
  case cfg ^. atomType of
    Safe.SAssignable ->
      case e of
        IR.ExprOne val ann ->
          Safe.ExprOne <$>
          checkXorExpr cfg val <*>
          pure ann
        IR.ExprMany l r ann ->
          syntaxError $ CannotAssignTo e ann
    Safe.SNotAssignable ->
      case e of
        IR.ExprOne val ann ->
          Safe.ExprOne <$>
          checkXorExpr cfg val <*>
          pure ann
        IR.ExprMany l r ann ->
          Safe.ExprMany <$>
          checkXorExpr cfg l <*>
          traverseOf
            (traverseCompose.traverseCompose)
            (checkXorExpr cfg) r <*>
          pure ann

checkXorExpr
  :: SyntaxConfig atomType ctxt
  -> IR.XorExpr ann
  -> SyntaxChecker ann (Safe.XorExpr atomType ctxt ann)
checkXorExpr cfg e =
  case cfg ^. atomType of
    Safe.SAssignable ->
      case e of
        IR.XorExprOne val ann ->
          Safe.XorExprOne <$>
          checkAndExpr cfg val <*>
          pure ann
        IR.XorExprMany l r ann ->
          syntaxError $ CannotAssignTo e ann
    Safe.SNotAssignable ->
      case e of
        IR.XorExprOne val ann ->
          Safe.XorExprOne <$>
          checkAndExpr cfg val <*>
          pure ann
        IR.XorExprMany l r ann ->
          Safe.XorExprMany <$>
          checkAndExpr cfg l <*>
          traverseOf
            (traverseCompose.traverseCompose)
            (checkAndExpr cfg) r <*>
          pure ann

checkAndExpr
  :: SyntaxConfig atomType ctxt
  -> IR.AndExpr ann
  -> SyntaxChecker ann (Safe.AndExpr atomType ctxt ann)
checkAndExpr cfg e =
  case cfg ^. atomType of
    Safe.SAssignable ->
      case e of
        IR.AndExprOne val ann ->
          Safe.AndExprOne <$>
          checkShiftExpr cfg val <*>
          pure ann
        IR.AndExprMany l r ann ->
          syntaxError $ CannotAssignTo e ann
    Safe.SNotAssignable ->
      case e of
        IR.AndExprOne val ann ->
          Safe.AndExprOne <$>
          checkShiftExpr cfg val <*>
          pure ann
        IR.AndExprMany l r ann ->
          Safe.AndExprMany <$>
          checkShiftExpr cfg l <*>
          traverseOf
            (traverseCompose.traverseCompose)
            (checkShiftExpr cfg) r <*>
          pure ann

checkShiftExpr
  :: SyntaxConfig atomType ctxt
  -> IR.ShiftExpr ann
  -> SyntaxChecker ann (Safe.ShiftExpr atomType ctxt ann)
checkShiftExpr cfg e =
  case cfg ^. atomType of
    Safe.SAssignable ->
      case e of
        IR.ShiftExprOne val ann ->
          Safe.ShiftExprOne <$>
          checkArithExpr cfg val <*>
          pure ann
        IR.ShiftExprMany l r ann ->
          syntaxError $ CannotAssignTo e ann
    Safe.SNotAssignable ->
      case e of
        IR.ShiftExprOne val ann ->
          Safe.ShiftExprOne <$>
          checkArithExpr cfg val <*>
          pure ann
        IR.ShiftExprMany l r ann ->
          Safe.ShiftExprMany <$>
          checkArithExpr cfg l <*>
          traverseOf
            (traverseCompose.traverseCompose)
            (checkArithExpr cfg) r <*>
          pure ann

checkArithExpr
  :: SyntaxConfig atomType ctxt
  -> IR.ArithExpr ann
  -> SyntaxChecker ann (Safe.ArithExpr atomType ctxt ann)
checkArithExpr cfg e =
  case cfg ^. atomType of
    Safe.SAssignable ->
      case e of
        IR.ArithExprOne val ann ->
          Safe.ArithExprOne <$>
          checkTerm cfg val <*>
          pure ann
        IR.ArithExprMany l r ann ->
          syntaxError $ CannotAssignTo e ann
    Safe.SNotAssignable ->
      case e of
        IR.ArithExprOne val ann ->
          Safe.ArithExprOne <$>
          checkTerm cfg val <*>
          pure ann
        IR.ArithExprMany l r ann ->
          Safe.ArithExprMany <$>
          checkTerm cfg l <*>
          traverseOf
            (traverseCompose.traverseCompose)
            (checkTerm cfg) r <*>
          pure ann

checkTerm
  :: SyntaxConfig atomType ctxt
  -> IR.Term ann
  -> SyntaxChecker ann (Safe.Term atomType ctxt ann)
checkTerm cfg e =
  case cfg ^. atomType of
    Safe.SAssignable ->
      case e of
        IR.TermOne val ann ->
          Safe.TermOne <$>
          checkFactor cfg val <*>
          pure ann
        IR.TermMany l r ann ->
          syntaxError $ CannotAssignTo e ann
    Safe.SNotAssignable ->
      case e of
        IR.TermOne val ann ->
          Safe.TermOne <$>
          checkFactor cfg val <*>
          pure ann
        IR.TermMany l r ann ->
          Safe.TermMany <$>
          checkFactor cfg l <*>
          traverseOf
            (traverseCompose.traverseCompose)
            (checkFactor cfg) r <*>
          pure ann

checkFactor
  :: SyntaxConfig atomType ctxt
  -> IR.Factor ann
  -> SyntaxChecker ann (Safe.Factor atomType ctxt ann)
checkFactor cfg e =
  case cfg ^. atomType of
    Safe.SAssignable ->
      case e of
        IR.FactorOne val ann ->
          Safe.FactorOne <$>
          checkPower cfg val <*>
          pure ann
        IR.FactorMany val ann ->
          syntaxError $ CannotAssignTo e ann
    Safe.SNotAssignable ->
      case e of
        IR.FactorOne val ann ->
          Safe.FactorOne <$>
          checkPower cfg val <*>
          pure ann
        IR.FactorMany val ann ->
          Safe.FactorMany <$>
          traverseOf
            traverseCompose
            (checkFactor cfg) val <*>
          pure ann

checkPower
  :: SyntaxConfig atomType ctxt
  -> IR.Power ann
  -> SyntaxChecker ann (Safe.Power atomType ctxt ann)
checkPower cfg e =
  case cfg ^. atomType of
    Safe.SAssignable ->
      case e of
        IR.PowerOne val ann ->
          Safe.PowerOne <$>
          checkAtomExpr cfg val <*>
          pure ann
        IR.PowerMany l r ann ->
          syntaxError $ CannotAssignTo e ann
    Safe.SNotAssignable ->
      case e of
        IR.PowerOne val ann ->
          Safe.PowerOne <$>
          checkAtomExpr cfg val <*>
          pure ann
        IR.PowerMany l r ann ->
          Safe.PowerMany <$>
          checkAtomExpr cfg l <*>
          traverseOf traverseCompose (checkFactor cfg) r <*>
          pure ann

checkAtomExpr
  :: SyntaxConfig atomType ctxt
  -> IR.AtomExpr ann
  -> SyntaxChecker ann (Safe.AtomExpr atomType ctxt ann)
checkAtomExpr cfg e =
  case e of
    IR.AtomExprNoAwait a ts ann ->
      case cfg ^. atomType of
        Safe.SAssignable ->
          Safe.AtomExprNoAwait <$>
          checkAtom cfg a <*>
          traverseOf
            (traverseCompose.traverseCompose)
            (checkTrailer $ set atomType Safe.SNotAssignable cfg)
            ts <*>
          pure ann
        Safe.SNotAssignable ->
          syntaxError $ CannotAssignTo e ann
    IR.AtomExprAwait kw a ts ann ->
      case (cfg ^. atomType, cfg ^. exprContext) of
        (Safe.SNotAssignable, Safe.SFunDef Safe.SAsync) ->
          Safe.AtomExprAwait kw <$>
          checkAtom cfg a <*>
          traverseOf
            (traverseCompose.traverseCompose)
            (checkTrailer cfg)
            ts <*>
          pure ann
        (Safe.SNotAssignable, _) ->
          syntaxError $ AwaitNotInAsyncFunction ann
        (Safe.SAssignable, Safe.SFunDef Safe.SAsync) ->
          syntaxError $ CannotAssignTo e ann
        (Safe.SAssignable, Safe.SFunDef Safe.SNormal) ->
          syntaxError (CannotAssignTo e ann) *>
          syntaxError (AwaitNotInAsyncFunction ann)
        (Safe.SAssignable, Safe.STopLevel) ->
          syntaxError (CannotAssignTo e ann) *>
          syntaxError (AwaitNotInAsyncFunction ann)

checkTrailer
  :: SyntaxConfig atomType ctxt
  -> IR.Trailer ann
  -> SyntaxChecker ann (Safe.Trailer atomType ctxt ann)
checkTrailer cfg e =
  case cfg ^. atomType of
    Safe.SAssignable ->
      syntaxError $ CannotAssignTo e (e ^. IR.trailer_ann)
    Safe.SNotAssignable ->
      case e of
        IR.TrailerCall v ann ->
          Safe.TrailerCall <$>
          traverseOf (traverseCompose.traverseCompose) (checkArgList cfg) v <*>
          pure ann
        IR.TrailerSubscript v ann ->
          Safe.TrailerSubscript <$>
          traverseOf
            (traverseCompose.traverseCompose)
            (checkSubscriptList cfg)
            v <*>
          pure ann
        IR.TrailerAccess v ann -> pure $ Safe.TrailerAccess v ann

checkArgList
  :: SyntaxConfig atomType ctxt
  -> IR.ArgList ann
  -> SyntaxChecker ann (Safe.ArgList atomType ctxt ann)
checkArgList cfg (IR.ArgList h t comma ann) =
  Safe.ArgList <$>
  checkArgument cfg h <*>
  traverseOf (traverseCompose.traverseCompose) (checkArgument cfg) t <*>
  pure comma <*>
  pure ann

checkArgument
  :: SyntaxConfig atomType ctxt
  -> IR.Argument ann
  -> SyntaxChecker ann (Safe.Argument atomType ctxt ann)
checkArgument cfg e =
  case cfg ^. atomType of
    Safe.SAssignable ->
      syntaxError $ CannotAssignTo e (e ^. IR.argument_ann)
    Safe.SNotAssignable ->
      case e of
        IR.ArgumentFor e f ann ->
          Safe.ArgumentFor <$>
          checkTest cfg e <*>
          traverseOf (traverseCompose.traverseCompose) (checkCompFor cfg) f <*>
          pure ann
        IR.ArgumentDefault l r ann ->
          Safe.ArgumentDefault <$>
          traverseOf
            traverseCompose
            (checkTest $ cfg & atomType .~ Safe.SAssignable)
            l <*>
          traverseOf
            traverseCompose
            (checkTest cfg)
            r <*>
          pure ann
        IR.ArgumentUnpack sym val ann ->
          Safe.ArgumentUnpack sym <$>
          traverseOf traverseCompose (checkTest cfg) val <*>
          pure ann

checkCompFor
  :: SyntaxConfig atomType ctxt
  -> IR.CompFor ann
  -> SyntaxChecker ann (Safe.CompFor atomType ctxt ann)
checkCompFor cfg e =
  case cfg ^. atomType of
    Safe.SAssignable ->
      syntaxError $ CannotAssignTo e (e ^. IR.compFor_ann)
    Safe.SNotAssignable ->
      case e of
        IR.CompFor ts ex i ann ->
          Safe.CompFor <$>
          traverseOf
            (traverseCompose.traverseCompose)
            (checkExprList $ cfg & atomType .~ Safe.SAssignable)
            ts <*>
          traverseOf
            traverseCompose
            (checkOrTest cfg)
            ex <*>
          traverseOf
            (traverseCompose.traverseCompose)
            (checkCompIter cfg)
            i <*>
          pure ann

checkExprList
  :: SyntaxConfig atomType ctxt
  -> IR.ExprList ann
  -> SyntaxChecker ann (Safe.ExprList atomType ctxt ann)
checkExprList cfg (IR.ExprList h t ann) =
  Safe.ExprList <$>
  checkExprOrStar h <*>
  traverseOf (traverseCompose.traverseCompose) checkExprOrStar t <*>
  pure ann
  where
    checkExprOrStar e =
      case e of
        InL a -> InL <$> checkExpr cfg a
        InR a -> InR <$> checkStarExpr cfg a

checkStarExpr
  :: SyntaxConfig atomType ctxt
  -> IR.StarExpr ann
  -> SyntaxChecker ann (Safe.StarExpr atomType ctxt ann)
checkStarExpr cfg (IR.StarExpr val ann) =
  Safe.StarExpr <$>
  traverseOf
    traverseCompose
    (checkExpr $ cfg & atomType .~ Safe.SAssignable) val <*>
  pure ann

checkCompIter
  :: SyntaxConfig atomType ctxt
  -> IR.CompIter ann
  -> SyntaxChecker ann (Safe.CompIter atomType ctxt ann)
checkCompIter cfg e@(IR.CompIter val ann) =
  case cfg ^. atomType of
    Safe.SAssignable ->
      syntaxError $ CannotAssignTo e ann
    Safe.SNotAssignable ->
      Safe.CompIter <$>
      checkCompForOrIf cfg val <*>
      pure ann
  where
    checkCompForOrIf cfg e =
      case e of
        InL a -> InL <$> checkCompFor cfg a
        InR a -> InR <$> checkCompIf cfg a

checkCompIf
  :: SyntaxConfig atomType ctxt
  -> IR.CompIf ann
  -> SyntaxChecker ann (Safe.CompIf atomType ctxt ann)
checkCompIf cfg e = _

checkSubscriptList
  :: SyntaxConfig atomType ctxt
  -> IR.SubscriptList ann
  -> SyntaxChecker ann (Safe.SubscriptList atomType ctxt ann)
checkSubscriptList cfg e = _

checkAtom
  :: SyntaxConfig atomType ctxt
  -> IR.Atom ann
  -> SyntaxChecker ann (Safe.Atom atomType ctxt ann)
checkAtom cfg e = _
