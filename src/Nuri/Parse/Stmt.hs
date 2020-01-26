module Nuri.Parse.Stmt where

import qualified Text.Megaparsec               as P
import           Text.Megaparsec                          ( (<?>) )
import           Text.Megaparsec.Char                     ( eol )
import qualified Text.Megaparsec.Char.Lexer    as L

import           Nuri.Parse
import           Nuri.Parse.Expr
import           Nuri.Stmt

indent :: Parser (L.IndentOpt Parser a b) -> Parser a
indent = L.indentBlock scn

parseStmts :: Parser Stmts
parseStmts = fromList <$> P.some (parseStmt <* scn)

parseStmt :: Parser Stmt
parseStmt =
  parseIfStmt
    <|> parseWhileStmt
    <|> P.try parseReturnStmt
    <|> parseFuncDecl
    <|> parseExprStmt

parseExprStmt :: Parser Stmt
parseExprStmt = ExprStmt <$> (parseExpr <* ((void eol <|> P.eof) <?> "줄의 끝"))

parseReturnStmt :: Parser Stmt
parseReturnStmt = Return <$> (parseExpr <* reserved "반환하다")

parseIfStmt :: Parser Stmt
parseIfStmt = do
  ifPart   <- indent (ifLine "만약")
  elifPart <- P.many $ indent (ifLine "아니고")
  elsePart <- optional $ indent (elseLine "아니면")
  return $ ifPart (foldr ($) elsePart (fmap (Just . one) <$> elifPart))
 where
  ifLine s = do
    pos <- getSourceLine
    _   <- reserved s
    e   <- parseArithmetic
    _   <- reserved "이라면"
    _   <- symbol ":"
    return (L.IndentSome Nothing (return . If pos e) parseStmt)
  elseLine s = do
    _ <- reserved s
    _ <- symbol ":"
    return (L.IndentSome Nothing return parseStmt)

parseWhileStmt :: Parser Stmt
parseWhileStmt = indent $ do
  pos <- getSourceLine
  _   <- reserved "반복"
  e   <- parseArithmetic
  _   <- reserved "인 동안"
  _   <- symbol ":"
  return (L.IndentSome Nothing (return . While pos e . fromList) parseStmt)

parseFuncDecl :: Parser Stmt
parseFuncDecl = indent argsLine
 where
  argsLine = do
    pos <- getSourceLine
    P.try $ reserved "함수"
    args     <- P.many parseIdentifier
    funcName <- parseFuncIdentifier
    _        <- symbol ":"
    return
      (L.IndentSome Nothing (return . FuncDecl pos funcName args) parseStmt)
