module Helper where

import Control.Lens (makeLenses)
import Control.Lens.TH ()
import Data.Binary (encode)
import qualified Data.Set.Ordered as S
import Default (defineDefaults)
import Haneul.Builder (internalToFuncObject, runBuilder)
import Haneul.BuilderInternal
  ( BuilderInternal (_internalGlobalVarNames, _internalLastFilePath),
    defaultDecls,
    defaultInternal,
  )
import Haneul.Constant (FuncObject (_funcFilePath))
import Haneul.Serial ()
import Nuri.Codegen.Stmt (compileStmts)
import Nuri.Stmt (Stmt)
import Text.Pretty.Simple (pPrint)
import Prelude hiding (writeFile)

newtype ReplState = ReplState {_prompt :: Text}

$(makeLenses ''ReplState)

newtype Repl a = Repl {unRepl :: StateT ReplState IO a}
  deriving (Monad, Functor, Applicative, MonadState ReplState, MonadIO)

compileResult :: FilePath -> Bool -> String -> (NonEmpty Stmt) -> IO ()
compileResult filePath isDebug dest stmts = do
  let program' =
        ( internalToFuncObject
            . runBuilder
              defaultInternal
                { _internalGlobalVarNames = S.fromList (snd <$> defaultDecls),
                  _internalLastFilePath = filePath
                }
        )
          $ do
            defineDefaults
            compileStmts stmts
      program = program' {_funcFilePath = filePath}

  when isDebug $ do
    (liftIO . pPrint) stmts
    putStrLn "---------------"
    pPrint program

  writeFileLBS dest (encode program)
