module Nuri.Codegen.Stmt where

import Haneul.Builder
import qualified Haneul.Instruction as Inst
import Nuri.ASTNode
import Nuri.Codegen.Expr
import Nuri.Expr
import Nuri.Stmt

compileStmt :: Stmt -> Builder ()
compileStmt (DeclStmt (Decl pos _ name (Just t))) = do
  compileExpr (declToExpr pos t)

  index <- addGlobalVarName name
  tellInst pos (Inst.StoreGlobal index)
compileStmt (DeclStmt (Decl _ _ name Nothing)) = do
  _ <- addGlobalVarName name
  pass
compileStmt stmt@(ExprStmt expr) = do
  compileExpr expr
  tellInst (getSourceLine stmt) (Inst.Pop)

compileStmts :: NonEmpty Stmt -> Builder ()
compileStmts s = sequence_ (compileStmt <$> s)
