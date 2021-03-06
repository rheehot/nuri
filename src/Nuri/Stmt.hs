module Nuri.Stmt where

import Nuri.ASTNode (ASTNode (..))
import Nuri.Expr (Decl, Expr)

data Stmt
  = DeclStmt Decl
  | ExprStmt Expr
  deriving (Eq, Show)

instance ASTNode Stmt where
  getSourcePos (DeclStmt decl) = getSourcePos decl
  getSourcePos (ExprStmt expr) = getSourcePos expr
