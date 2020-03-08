module Nuri.Codegen.Expr where

import           Control.Lens                             ( view
                                                          , use
                                                          , uses
                                                          , assign
                                                          , modifying
                                                          )
import           Control.Monad.RWS                        ( execRWS )
import qualified Data.List                     as L
import qualified Data.Set.Ordered              as S

import           Nuri.Expr
import           Nuri.Literal
import           Nuri.ASTNode

import           Haneul.Builder
import           Haneul.Constant
import           Haneul.BuilderInternal
import qualified Haneul.Instruction            as Inst
import           Haneul.Instruction                       ( Mark(Mark)
                                                          , estimateStackSize
                                                          )

litToConst :: Literal -> Constant
litToConst LitNone        = ConstNone
litToConst (LitInteger v) = ConstInteger v
litToConst (LitReal    v) = ConstReal v
litToConst (LitChar    v) = ConstChar v
litToConst (LitBool    v) = ConstBool v

compileExpr :: Expr -> Builder ()
compileExpr (Lit pos lit) = do
  let value = litToConst lit
  index <- addConstant value
  tellInst pos (Inst.Push $ fromIntegral index)

compileExpr (Var pos ident) = do
  varNames <- use internalVarNames
  let identIndices = L.elemIndices ident (snd <$> toList varNames)
  case viaNonEmpty last identIndices of
    Just index -> tellInst pos (Inst.LoadLocal $ fromIntegral index)
    Nothing    -> do
      outerVars <- ask
      let result = viaNonEmpty
            head
            [ (i, j)
            | (i, scope) <- zip [0 ..] outerVars
            , (j, x    ) <- zip [0 ..] $ toList scope
            , x == ident
            ]
      case result of
        Just loc -> do
          index <- addFreeVar loc
          tellInst pos (Inst.LoadDeref index)
        Nothing -> do
          index <- addGlobalVarName ident
          tellInst pos (Inst.LoadGlobal index)

compileExpr (FuncCall pos func args) = do
  sequence_ (compileExpr . fst <$> args)
  compileExpr func
  tellInst pos (Inst.Call $ snd <$> reverse args)

compileExpr (If pos condExpr thenExpr elseExpr) = do
  compileExpr condExpr
  whenFalseMark <- createMark
  tellInst pos (Inst.PopJmpIfFalse $ Mark whenFalseMark)

  compileExpr thenExpr
  thenJumpMark <- createMark
  tellInst pos (Inst.Jmp $ Mark thenJumpMark)

  setMark whenFalseMark
  compileExpr elseExpr
  setMark thenJumpMark

compileExpr (BinaryOp pos op lhs rhs) = do
  compileExpr lhs
  compileExpr rhs
  case op of
    Add              -> tellInst pos (Inst.Add)
    Subtract         -> tellInst pos (Inst.Subtract)
    Multiply         -> tellInst pos (Inst.Multiply)
    Divide           -> tellInst pos (Inst.Divide)
    Mod              -> tellInst pos (Inst.Mod)
    Equal            -> tellInst pos (Inst.Equal)
    Inequal          -> tellCode [(pos, Inst.Equal), (pos, Inst.Negate)]
    LessThan         -> tellInst pos (Inst.LessThan)
    GreaterThan      -> tellInst pos (Inst.GreaterThan)
    LessThanEqual    -> tellCode [(pos, Inst.GreaterThan), (pos, Inst.Negate)]
    GreaterThanEqual -> tellCode [(pos, Inst.LessThan), (pos, Inst.Negate)]

compileExpr (UnaryOp pos op value) = do
  compileExpr value
  case op of
    Positive -> pass
    Negative -> tellInst pos Inst.Negate

compileExpr (Seq xs) = do
  tempVarNames <- use internalVarNames

  modifying internalDepth (+ 1)
  depth <- use internalDepth

  let process []       = pass
      process (y : ys) = do
        case y of
          Left decl -> do
            let (pos, name, expr) = declToExpr decl
            index <- addVarName depth name
            compileExpr expr
            tellInst pos (Inst.StoreLocal index)
            when (null ys) (tellInst pos (Inst.LoadLocal index))
          Right expr -> do
            compileExpr expr
            when (not $ null ys) (tellInst (getSourceLine expr) Inst.Pop)
        process ys
  seqSize       <- process $ toList xs

  maxLocalCount <- use internalMaxLocalCount
  localCount    <- uses internalVarNames genericLength
  when (localCount > maxLocalCount) (assign internalMaxLocalCount localCount)

  -- 여기에 PopLocal 추가
  assign internalVarNames tempVarNames

  modifying internalDepth (`subtract` 1)
  return seqSize

compileExpr (Lambda pos args body) = do
  (internal, funcObject) <- lambdaToFuncObject args body
  assign internalGlobalVarNames (view internalGlobalVarNames internal)

  index <- addConstant (ConstFunc funcObject)
  tellInst pos (Inst.Push index)

  let freeVarList = toList $ view internalFreeVars internal
  let processFreeVar []                         = return []
      processFreeVar ((depth, localIndex) : xs) = do
        val <- if depth == 0
          then return (False, localIndex) -- 자유 변수가 현재 로컬에 있을 경우
          else do -- 자유 변수가 상위 스코프에 있을 경우
            freeIndex <- addFreeVar (depth - 1, localIndex)
            return (True, fromIntegral freeIndex)
        fmap (val :) (processFreeVar xs)

  processed <- processFreeVar freeVarList
  when ((not . null) processed) $ tellInst pos (Inst.FreeVar processed)


lambdaToFuncObject
  :: [(Text, Text)] -> Expr -> Builder (BuilderInternal, FuncObject)
lambdaToFuncObject args body = do
  globalVarNames <- use internalGlobalVarNames
  varNames       <- use internalVarNames
  oldLocalStack  <- ask
  let newLocalStack     = (S.fromList . fmap snd . toList) varNames
      (internal, code') = execRWS
        (do
          sequence_ (addVarName 0 . fst <$> args)
          compileExpr body
        )
        (newLocalStack : oldLocalStack)
        defaultInternal { _internalGlobalVarNames = globalVarNames }
      constTable    = view internalConstTable internal
      maxLocalCount = view internalMaxLocalCount internal
      code          = clearMarks internal code'
  return
    ( internal
    , FuncObject { _funcJosa          = (snd <$> args)
                 , _funcBody          = code
                 , _funcConstTable    = constTable
                 , _funcMaxLocalCount = maxLocalCount
                 , _funcMaxStackSize  = estimateStackSize code
                 }
    )
