{-# OPTIONS_GHC -Wno-missing-signatures #-}
module Nuri.Spec.Util where

import           Text.Megaparsec.Pos

import           Nuri.Expr
import           Nuri.Stmt
import           Nuri.Literal

initPos :: SourcePos
initPos = initialPos "(test)"

litInteger v = Lit initPos (LitInteger v)
litReal v = Lit initPos (LitReal v)
litBool v = Lit initPos (LitBool v)
binaryOp = BinaryOp initPos
unaryOp = UnaryOp initPos
var = Var initPos
app = App initPos

assign = Assign initPos
ifStmt = If initPos
funcDecl = FuncDecl initPos
