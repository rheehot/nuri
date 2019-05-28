module Nuri.Eval.Expr where

import           Prelude                 hiding ( lookup )

import           Control.Monad.State.Lazy
import           Control.Monad.Except
import           Data.Map.Strict

import           Nuri.Expr
import           Nuri.Eval.Val
import           Nuri.Eval.SymbolTable

evalExpr :: Expr -> State SymbolTable Val
evalExpr (Lit _ (LitInteger v)) = return $ IntegerVal v
evalExpr (Var _ ident         ) = do
  table <- get
  case lookup ident table of
    Just val -> return val
    Nothing  -> error "식별자 찾을 수 없음"


